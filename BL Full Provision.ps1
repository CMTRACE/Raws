# BlackLotus-mitigated Windows 11 24H2 Provisioning Script
# Requires: OSDCloud module, administrative privileges

# --- Utility Functions ---

function New-RootFolder {
    $date = Get-Date -Format "yyyy-MM-dd"
    $rootPath = "C:\Windows\Temp\BuildRoot-$date"
    if (Test-Path -Path $rootPath) {
        try {
            Remove-Item -Path $rootPath -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Error "Failed to delete $rootPath. Error: $_"
            return $null
        }
    }
    New-Item -Path $rootPath -ItemType Directory | Out-Null
    return $rootPath
}

function New-SubFolders {
    param([string]$RootPath)
    $folders = @("CumulativeUpdates", "SafeOSUpdates", "SetupUpdates", "Mount", "DotNetUpdates")
    foreach ($folder in $folders) {
        $path = Join-Path -Path $RootPath -ChildPath $folder
        if (-not (Test-Path $path)) {
            New-Item -Path $path -ItemType Directory | Out-Null
        }
    }
}

function Get-UpdateFile {
    param(
        [string]$Url,
        [string]$DestinationPath
    )
    $fileName = Split-Path -Path $Url -Leaf
    $targetPath = Join-Path -Path $DestinationPath -ChildPath $fileName

    # Search all drives for the file
    $found = $false
    foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
        $searchPath = Join-Path -Path $drive.Root -ChildPath $fileName
        if (Test-Path $searchPath) {
            Write-Host "Found $fileName at $searchPath"
            Copy-Item -Path $searchPath -Destination $targetPath -Force
            $found = $true
            break
        }
    }

    # Download if not found
    if (-not $found) {
        Write-Host "Downloading $fileName from $Url"
        $maxRetries = 3
        $retry = 0
        $success = $false
        while (-not $success -and $retry -lt $maxRetries) {
            try {
                Invoke-WebRequest -Uri $Url -OutFile $targetPath
                Write-Host "Downloaded $fileName successfully."
                $success = $true
            } catch {
                $retry++
                Write-Warning "Attempt $retry to download $fileName failed. Retrying..."
                Start-Sleep -Seconds 5
            }
        }
        if (-not $success) {
            Write-Error "Failed to download $fileName from $Url after $maxRetries attempts."
            return $null
        }
    }

    # Verify SHA1 hash
    if (Test-Path $targetPath) {
        $hash = Get-FileHash -Path $targetPath -Algorithm SHA1
        if ($Url -like "*$($hash.Hash)*") {
            Write-Host "SHA1 hash of $fileName matches the URL."
            return $targetPath
        } else {
            Write-Error "SHA1 hash of $fileName does not match the URL."
            return $null
        }
    } else {
        Write-Error "Downloaded file $fileName does not exist at $targetPath"
        return $null
    }
}

function Mount-WinREImage {
    param(
        [string]$ImagePath,
        [string]$MountPath
    )
    if (-not (Test-Path $ImagePath)) {
        Write-Error "Image path $ImagePath does not exist."
        return $false
    }
    try {
        Mount-WindowsImage -ImagePath $ImagePath -Path $MountPath -Index 1
        Write-Host "Mounted WinRE image at $MountPath"
        return $true
    } catch {
        Write-Error "Failed to mount WinRE image. Error: $_"
        return $false
    }
}

function Install-Update {
    param(
        [string]$UpdatePath,
        [string]$MountPath
    )
    if (-not (Test-Path $UpdatePath)) {
        Write-Error "Update path $UpdatePath does not exist."
        return $false
    }
    try {
        Add-WindowsPackage -Path $MountPath -PackagePath $UpdatePath
        Write-Host "Applied update from $UpdatePath to $MountPath"
        return $true
    } catch {
        Write-Error "Failed to apply update from $UpdatePath. Error: $_"
        return $false
    }
}

function Invoke-DISMCommand {
    param(
        [string]$Command,
        [string]$MountPath
    )
    try {
        $dismCommand = "dism /image:`"$MountPath`" $Command"
        Write-Host "Executing DISM command: $dismCommand"
        Invoke-Expression $dismCommand
        Write-Host "DISM command executed successfully."
        return $true
    } catch {
        Write-Error "Failed to execute DISM command. Error: $_"
        return $false
    }
}

function Test-EFISignatures {
    param([string]$MountPath)
    $efiFiles = Get-ChildItem -Path $MountPath -Recurse -Filter "*.efi"
    foreach ($efiFile in $efiFiles) {
        $signature = Get-AuthenticodeSignature -FilePath $efiFile.FullName
        if ($signature.Status -eq "Valid" -and $null -ne $signature.SignerCertificate -and $signature.SignerCertificate.Subject -like "*2023*") {
            Write-Host "Valid signature found for $($efiFile.FullName) signed by a CA with 2023 in the name."
        } elseif ($null -eq $signature.SignerCertificate) {
            Write-Host "Invalid or unsigned file: $($efiFile.FullName). SignerCertificate is null."
        } else {
            Write-Host "Invalid or unsigned file: $($efiFile.FullName). Actual: $($signature.SignerCertificate.Subject)"
        }
    }
}

function Test-SecureBootDatabases {
    $db = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes)
    if ($db -match 'Windows UEFI CA 2023') {
        Write-Host "Secure Boot Database contains 'Windows UEFI CA 2023'."
    } else {
        Write-Host "'Windows UEFI CA 2023' not found in Secure Boot Database."
    }
    $dbx = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes)
    if ($dbx -match 'Microsoft Windows Production PCA 2011') {
        Write-Host "Banned Certificates Database contains 'Microsoft Windows Production PCA 2011'."
    } else {
        Write-Host "'Microsoft Windows Production PCA 2011' not found in Banned Certificates Database."
    }
}

# --- Main Script Execution ---

Start-OSDCloud -Firmware -ZTI -OSName 'Windows 11 24H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSActivation Volume

$rootPath = New-RootFolder
if ($null -eq $rootPath) { exit 1 }
New-SubFolders -RootPath $rootPath

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

# Download or locate updates and verify hashes
foreach ($updateType in $updateUrls.Keys) {
    $destPath = Join-Path -Path $rootPath -ChildPath $updateType
    foreach ($url in $updateUrls[$updateType]) {
        Get-UpdateFile -Url $url -DestinationPath $destPath | Out-Null
    }
}

# Mount WinRE image
$winREImagePath = "c:\Windows\System32\Recovery\Winre.wim"
if (-not (Test-Path $winREImagePath)) {
    Write-Error "WinRE image not found at $winREImagePath. Ensure the path is correct."
    exit 1
}           
$mountPath = Join-Path -Path $rootPath -ChildPath "Mount"
if (-not (Mount-WinREImage -ImagePath $winREImagePath -MountPath $mountPath)) { exit 1 }

# Apply Cumulative and SafeOS updates to WinRE
$cuPath = Join-Path -Path $rootPath -ChildPath "CumulativeUpdates"
Install-Update -UpdatePath $cuPath -MountPath $mountPath | Out-Null
$safeOSPath = Join-Path -Path $rootPath -ChildPath "SafeOSUpdates"
Install-Update -UpdatePath $safeOSPath -MountPath $mountPath | Out-Null

# Check EFI signatures
Test-EFISignatures -MountPath $mountPath

# DISM cleanup
Invoke-DISMCommand -Command "/cleanup-image /startcomponentcleanup /defer" -MountPath $mountPath | Out-Null

# Unmount and commit
if (Test-Path $mountPath) {
    Dismount-WindowsImage -Path $mountPath -Save
    Write-Host "Successfully dismounted the image at $mountPath."
} else {
    Write-Error "Mount path $mountPath does not exist. Cannot dismount the image."
}

# Check Secure Boot Databases
Test-SecureBootDatabases

# End of script
# Ensure script is run with admin rights and required modules are available.