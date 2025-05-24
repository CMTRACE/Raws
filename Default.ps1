Try {
    Write-Host "Starting OSDCloud deployment..."
    Start-OSDCloud -Firmware -ZTI -OSName 'Windows 11 24H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSActivation Volume
    Write-Host "OSDCloud deployment completed."

$UpdateFileName = 'windows11.0-kb5058411-x64_fc93a482441b42bcdbb035f915d4be2047d63de5.msu'
$UpdateUrl = "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/770c53ae-5610-402f-b5e9-fe86142003cc/public/windows11.0-kb5058411-x64_fc93a482441b42bcdbb035f915d4be2047d63de5.msu"
$TempUpdatePath = "C:\Windows\Temp\$UpdateFileName"

# Search all drives for the update file
Write-Host "Searching all drives for $UpdateFileName..."
$UpdatePath = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    Get-ChildItem -Path "$($_.Root)" -Filter $UpdateFileName -Recurse -ErrorAction SilentlyContinue -Force
} | Select-Object -First 1 -ExpandProperty FullName

if (-not $UpdatePath) {
    Write-Host "Update file not found on any drive. Downloading from Microsoft Update Catalog..."
    Invoke-WebRequest -Uri $UpdateUrl -OutFile $TempUpdatePath
    $UpdatePath = $TempUpdatePath
    Write-Host "Download complete: $UpdatePath"
} else {
    Write-Host "Found update file at: $UpdatePath"
}

# Calculate SHA1 hash of the update file
Write-Host "Calculating SHA1 hash for: $UpdatePath"
$sha1 = Get-FileHash -Path $UpdatePath -Algorithm SHA1 | Select-Object -ExpandProperty Hash

Write-Host "SHA1 hash: $sha1"

if ($UpdateUrl -like "*$sha1*") {
    Write-Host "SHA1 hash found in URL. Proceeding to add Windows package."
    Write-Host "Adding Windows package: $UpdatePath"
    Add-WindowsPackage -PackagePath $UpdatePath -Path 'C:\'
    Write-Host "Windows package added."
} else {
    Write-Host "ERROR: SHA1 hash of file does not match the URL. Aborting package installation."
    Throw "SHA1 hash mismatch."
}

# Check for Windows UEFI CA 2023 in Secure Boot Database
$uefiDbString = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes)
if ($uefiDbString -match 'Windows UEFI CA 2023') {
    Write-Host "The Windows UEFI CA 2023 has been detected in the UEFI Secure Boot Database"
} else {
    Write-Host "The Windows UEFI CA 2023 was NOT detected in the UEFI Secure Boot Database"
}

# Check for Microsoft Windows Production PCA 2011 in banned certificates database
$uefiDbxString = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes)
if ($uefiDbxString -match 'Microsoft Windows Production PCA 2011') {
    Write-Host "The Microsoft Windows Production PCA 2011 certificate has been revoked and is present in the banned certificates database"
} else {
    Write-Host "The Microsoft Windows Production PCA 2011 certificate is NOT present in the banned certificates database"
}
    Write-Host "Updating boot files with bcdboot..."
    Start-Process -FilePath "C:\Windows\System32\bcdboot.exe" -ArgumentList "C:\Windows", "/v", "/c" -Wait -NoNewWindow -PassThru
    Write-Host "Boot files updated."

    Write-Host "Running DISM cleanup..."
    Start-Process -FilePath "C:\Windows\System32\DISM.exe" -ArgumentList "/Image:C:\", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase", "/ScratchDir:C:\Windows\Temp" -Wait -NoNewWindow -PassThru
    Write-Host "DISM cleanup completed."

    Write-Host "Restarting computer..."
    #Restart-Computer
}
Catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    Throw
}
Finally {
    Write-Host "===== OSDCloud Deployment Finished ====="
}