# this script is used to download, service and provision a fully compliant Blacklotus mitigated Windows 11 24H2 image.
# the script uses a community Powershell module called OSDCLoud and launched from within a specially prepared windows boot image.
# Note: This script requires administrative privileges to execute successfully.
# the script will download the latest image from the Microsoft Update Catalog, and verifies the sha1 hash.
# once out of the osdcloud portion of the script
# the script will check for an existing root folder in C:\Windows\Temp\BuildRoot* an delete it if it exists
# the script will create a new Root folder in C:\Windows\Temp\BuildRoot-(DATE)
# the script then creates the following folders, CumulativeUpdates, SafeOSUpdates, SetupUpdates, Mount
# the script will search for the updates filenames (the last segment of the URL) across all drives and folders
# if we dont find any matched locally, The script then downloads the declared Windows 11 24h2 cumulative updates, SafeOS updates
# , and Setup Updates from the URLS and places them in the C:\Windows\Temp\BuildRoot-(DATE) folder.
# once found on disk or downloaded, the script verifies the SHA1 hash of each update file by calculating the hash
# and checking if the hash is like the URL string
# we are now ready to start servicing the images. 
# first we will mount the WinRE image located in the Recovery Parition on disk to C:\Windows\Temp\BuildRoot-(DATE)\Mount
# we then use add-windowspacage to apply the cumulative updates first, feeding in just the path so add-windowspage can work out what needs to appy
# , then add the safe os update
# we then check any *.efi files in the mounted os are signed by a CA with 2023 in the name and log the results
# we then perform a dism /cleanup-image /startcomponentcleanup /defer
# We then unmount the image and commit the changes
# we then use add-windowspackage to apply Cumulative updates to the main windows 11 image located in C:\ by feeding the cu path in
# we then apply the .net cumulative updates to the main image
# we then perform a dism /cleanup-image /startcomponentcleanup /resetbase
# we then check for Windows UEFI CA 2023 in Secure Boot Database and log the results
# We then check for Microsoft Windows Production PCA 2011 in banned certificates database and log the results

Function New-RootFolder {
    $date = Get-Date -Format "yyyy-MM-dd"
    $rootPath = "C:\Windows\Temp\BuildRoot-$date"
    
    if (Test-Path -Path $rootPath) {
        try {
            Remove-Item -Path $rootPath -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Error "Failed to delete $rootPath. It might be in use by another process. Error: $_"
            return $null
        }
    }
    
    New-Item -Path $rootPath -ItemType Directory | Out-Null
    return $rootPath
}
Function Create-SubFolders {
    param (
        [string]$rootPath
    )
    $subFolders = @("CumulativeUpdates", "SafeOSUpdates", "SetupUpdates", "Mount", "DotNetUpdates")
    
    foreach ($folder in $subFolders) {
        $subFolderPath = Join-Path -Path $rootPath -ChildPath $folder
        New-Item -Path $subFolderPath -ItemType Directory | Out-Null
    }
}

Function Acquire-Update
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
        $maxRetries = 3
        $retryCount = 0
        $success = $false

        while (-not $success -and $retryCount -lt $maxRetries) {
            try {
                Invoke-WebRequest -Uri $url -OutFile (Join-Path -Path $destinationPath -ChildPath $fileName)
                Write-Host "Downloaded $fileName successfully."
                $success = $true
            } catch {
                $retryCount++
                Write-Warning "Attempt $retryCount to download $fileName failed. Retrying..."
                Start-Sleep -Seconds 5
            }
        }

        if (-not $success) {
            Write-Error "Failed to download $fileName from $url after $maxRetries attempts."
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

#main script execution starts here
Start-OSDCloud -Firmware -ZTI -OSName 'Windows 11 24H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSActivation Volume

$rootPath = New-RootFolder
Create-SubFolders -rootPath $rootPath
# Define URLs for updates
$updateUrls = @{
    CumulativeUpdates = @(
        "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/d8b7f92b-bd35-4b4c-96e5-46ce984b31e0/public/windows11.0-kb5043080-x64_953449672073f8fb99badb4cc6d5d7849b9c83e8.msu",
        "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/770c53ae-5610-402f-b5e9-fe86142003cc/public/windows11.0-kb5058411-x64_fc93a482441b42bcdbb035f915d4be2047d63de5.msu"
    )
    SafeOSUpdates = @(
        "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/88eb0a1d-e6d0-4842-8c04-e184220cd092/public/windows11.0-kb5059442-x64_d96d5a62d0a410fd8b07cb3098908e21a4c01c63.cab"
    )
    SetupUpdates = @(
        "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/9d1ab951-3e80-490b-bf90-8c2fe5c2b549/public/windows11.0-kb5059806-x64_b607edb8a152d38998211802d01b63e5acc23de3.cab"
    )
    DotNetUpdates = @(
        "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/02cd9c83-8312-424d-9a06-b042095804a8/public/windows11.0-kb5054979-x64-ndp481_8e2f730bc747de0f90aaee95d4862e4f88751c07.msu"
    )
}
# Search for or download updates then verify their SHA1 hashes
foreach ($updateType in $updateUrls.Keys) {
    $updatePath = Join-Path -Path $rootPath -ChildPath $updateType
    foreach ($url in $updateUrls[$updateType]) {
        Acquire-Update -url $url -destinationPath $updatePath
    }
}
# Mount WinRE image
$winREImagePath = "R:\WinRE.wim" # we assume the WinRE image is located on the R: drive
$mountPath = Join-Path -Path $rootPath -ChildPath "Mount"
Mount-WinREImage -imagePath $winREImagePath -mountPath $mountPath

# Apply updates to the mounted WinRE image
$updatePaths = Join-Path -Path $rootPath -ChildPath "CumulativeUpdates"
# feed path into apply-update function, we dont need for each update as we are applying all updates in the folder so we just pas the path
Apply-Update -updatePath $updatePaths -mountPath $mountPath 
# Apply SafeOS updates
$safeOSUpdatePath = Join-Path -Path $rootPath -ChildPath "SafeOSUpdates"
Apply-Update -updatePath $safeOSUpdatePath -mountPath $mountPath
# Check for signed *.efi files in the mounted OS
$efiFiles = Get-ChildItem -Path $mountPath -Recurse -Filter "*.efi"
foreach ($efiFile in $efiFiles) {
    $signature = Get-AuthenticodeSignature -FilePath $efiFile.FullName
    if ($signature.Status -eq "Valid" -and $signature.SignerCertificate -ne $null -and $signature.SignerCertificate.Subject -like "*2023*") {
        Write-Host "Valid signature found for $($efiFile.FullName) signed by a CA with 2023 in the name."
    } elseif ($signature.SignerCertificate -eq $null) {
        Write-Host "Invalid or unsigned file: $($efiFile.FullName). SignerCertificate is null."
    } else {
        Write-Host "Invalid or unsigned file: $($efiFile.FullName). Actual: $($signature.SignerCertificate.Subject)"
    }
}
# Perform DISM cleanup on the mounted image
invoke-DISMCommand -Command "/cleanup-image /startcomponentcleanup /defer" -mountPath $mountPath
# Unmount the WinRE image and commit changes
if (Test-Path -Path $mountPath) {
    Dismount-WindowsImage -Path $mountPath -Save
    Write-Host "Successfully dismounted the image at $mountPath."
} else {
    Write-Error "Mount path $mountPath does not exist. Cannot dismount the image."
}
# Apply updates to the main Windows 11 image
$mainImagePath = "C:\" # we assume the main image is located in C:\
$cuUpdatePath = Join-Path -Path $rootPath -ChildPath "CumulativeUpdates"

# using the below comands to sheck the status of the secure boot databases, we will log the results to the console  
#[System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes)
#[System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes)
$GetSecureBootUEFIdb = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes)
if ($GetSecureBootUEFIdb -match 'Windows UEFI CA 2023') {
    Write-Host "Secure Boot Database is enabled and has the 'Windows UEFI CA 2023' certificate is present."
} else {
    Write-Host "We did not find 'Windows UEFI CA 2023' in the Secure Boot Database. System may not be fully compliant."
}
$GetSecureBootUEFIdbx = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes)
if ($GetSecureBootUEFIdbx -match 'Microsoft Windows Production PCA 2011') {
    Write-Host "Banned Certificates Database contains 'Microsoft Windows Production PCA 2011'. System is fully compliant."
} else {
    Write-Host "Banned Certificates Database does not contain 'Microsoft Windows Production PCA 2011' System is not Fully compliant."
}

# End of script
# Note: Ensure that the script is run with appropriate permissions and in an environment where the required modules are available.      