# this scrip is used to download, service and provision a fully compliant Blacklotus mitigated Windows 11 24H2 image.
# the script uses a community Powershell module called PSD cloud and launched from within a specially preapred windows boot image.
# the script will download the latest image from the Microsoft Update Catalog, and verifies the sha1 hash.
# once out of the osdcloud portion of the script
# the script will check for an existing root folder in C:\Windows\Temp\BuildRoot* an delete it if it exists
# the script will create a new Root folder in C:\Windows\Temp\BuildRoot-(DATE)
# the script then creates the follwing folders, CumulativeUpdates, SafeOSUpdates, SetupUpdates, Mount
# the script will search for the updates filenames (the alst segment of the URL) across all drives and folders
# if we dont find any matched locally, The script then downloads the declared Windows 11 24h2 cumualtive updates, SafeOS updates
# , and Setup Updates from the URLS and places them in the C:\Windows\Temp\BuildRoot-(DATE) folder.
# once found on disk or downloaded, the script verifies the SHA1 has of each update file by caluating the hash
# and checking if the has is like the URL string
# we are now ready to start servicing the images. 
# first we will mount the WinRE image located in the Recovery Parition on disk to C:\Windows\Temp\BuildRoot-(DATE)\Mount
# we then use add-windowspacage to apply the cumulative updates first, feeding in jsut the path so add-windowspage can work out what needs to appy
# , then add the safe os update
# we then check any *.efi files in the moutned os are signed by a CA with 2023 in the name and log the results
# we then perform a dism /cleanup-image /startcomponentcleanup /defer
# We then unmount the image and commit the changes
# we then use add-windowspackage to apply Cumulative updates to the main windows 11 image located in C:\ by feeding the cu path in
# we then apply the .net cumulative updates to the main image
# we then perform a dism /cleanup-image /startcomponentcleanup /resetbase
# we then check for Windows UEFI CA 2023 in Secure Boot Database and log the results
# We then check for Microsoft Windows Production PCA 2011 in banned certificates database anf log the results

Function New-RootFolder {
    $date = Get-Date -Format "yyyy-MM-dd"
    $rootPath = "C:\Windows\Temp\BuildRoot-$date"
    
    if (Test-Path -Path $rootPath) {
        Remove-Item -Path $rootPath -Recurse -Force
    }
    
    New-Item -Path $rootPath -ItemType Directory | Out-Null
    return $rootPath
}
Function Create-SubFolders {
    param (
        [string]$rootPath
    )
    
    $subFolders = @("CumulativeUpdates", "SafeOSUpdates", "SetupUpdates", "Mount")
    
    foreach ($folder in $subFolders) {
        $path = Join-Path -Path $rootPath -ChildPath $folder
        New-Item -Path $path -ItemType Directory | Out-Null
    }
}

Function Aquire-Update
 {
    # we take a URL and destination path as parameters
    param (
        [string]$url,
        [string]$destinationPath
    )# we then take the last segment of the URL and the file name
    $fileName = Split-Path -Path $url -Leaf
    # we then search all connected drives by listing all drives and for each drive we search recursivly for the file name
    $found = $false
    $drives = Get-PSDrive -PSProvider FileSystem
    foreach ($drive in $drives) {
        $searchPath = Join-Path -Path $drive.Root -ChildPath $fileName
        if (Test-Path -Path $searchPath) {
            Write-Host "Found $fileName at $searchPath"
            Copy-Item -Path $searchPath -Destination $destinationPath -Force
            $found = $true
            break
        }
    }# If we did not find the file, we download it from the URL
    if (-not $found) {
        Write-Host "Downloading $fileName from $url"
        try {
            Invoke-WebRequest -Uri $url -OutFile (Join-Path -Path $destinationPath -ChildPath $fileName)
            Write-Host "Downloaded $fileName successfully."
        } catch {
            Write-Error "Failed to download $fileName from $url. Error: $_"
        }
    }   #we then verify the SHA1 hash by first caluralting the hash of the downloaded file, then we look for this hash is contained anywhere 
        # in the URL string
    $downloadedFilePath = Join-Path -Path $destinationPath -ChildPath $fileName
    if (Test-Path -Path $downloadedFilePath) {
        $hash = Get-FileHash -Path $downloadedFilePath -Algorithm SHA1
        if ($url -like "*$($hash.Hash)*") {
            Write-Host "SHA1 hash of $fileName matches the URL."
        } else {
            Write-Error "SHA1 hash of $fileName does not match the URL."
        }
    } else {
        Write-Error "Downloaded file $fileName does not exist at expected path: $downloadedFilePath"
    }# if the hash matches we return the path to the downloaded file otherwise we log an error
    else {
        Write-Error "Failed to download or verify $fileName."
        return $null
    }       
    return $downloadedFilePath

    
}

Function Mount-WinREImage {
    param (
        [string]$imagePath,
        [string]$mountPath
    )
    
    if (-not (Test-Path -Path $imagePath)) {
        Write-Error "Image path $imagePath does not exist."
        return $false
    }
    
    try {
        Mount-WindowsImage -ImagePath $imagePath -Path $mountPath -Index 1
        Write-Host "Mounted WinRE image at $mountPath"
        return $true
    } catch {
        Write-Error "Failed to mount WinRE image. Error: $_"
        return $false
    }
}   

Function Apply-Update { 
    # this function applies updates to the mounted WinRE image
    # it takes the downloaded update path and the mounting path as parameter
    param (
        [string]$updatePath,
        [string]$mountPath
    )
    if (-not (Test-Path -Path $updatePath)) {
        Write-Error "Update path $updatePath does not exist."
        return $false
    }
    try {
        Add-WindowsPackage -Path $mountPath -PackagePath $updatePath
        Write-Host "Applied update from $updatePath to mounted image at $mountPath"
        return $true
    } catch {
        Write-Error "Failed to apply update from $updatePath. Error: $_"
        return $false
    }

}
Function invoke-DISMCommand {
    # Example invoke-dismcommand -Command "/cleanup-image /startcomponentcleanup"
    param (
        [string]$command,
        [string]$mountPath
    )
    
    try {
        $dismCommand = "dism /image:$mountPath /$command"
        Write-Host "Executing DISM command: $dismCommand"
        Invoke-Expression $dismCommand
        Write-Host "DISM command executed successfully."
        return $true
    } catch {
        Write-Error "Failed to execute DISM command. Error: $_"
        return $false
    }
}

