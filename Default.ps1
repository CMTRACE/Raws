# Function to prompt user for 'y' or 'no'
function Read-UserInput {
    param (
        [string]$message
    )
    do {
        $response = (Read-Host "$message (y/no)").ToLower()
        $isInvalidResponse = $response -ne 'y' -and $response -ne 'no'
        if ($isInvalidResponse) {
            Write-Host "Invalid input. Please enter 'y' for yes or 'no' for no."
        }
    } while ($isInvalidResponse)
    return $response
}

# Step 1: Run custom PowerShell command
$response = Read-UserInput "Do you want to run the custom PowerShell command: Start-OSDCloud -Firmware -ZTI -OSName 'Windows 11 24H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSActivation Volume?"
if ($response -eq 'y') {
    Start-OSDCloud -Firmware -ZTI -OSName 'Windows 11 24H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSActivation Volume
}

# Step 2: Run mountvol S: /S
$response = Read-UserInput "Do you want to run: mountvol S: /S?"
if ($response -eq 'y') {
    mountvol S: /S
}

# Step 3: Copy EFI files from X: drive to S:\, overwriting all files
if ((Test-Path X:\EFI\) -and (Test-Path S:\EFI\)) {
    try {
        Copy-Item -Path X:\EFI\* -Destination S:\EFI\ -Recurse -Force -ErrorAction Stop
        Write-Host "EFI files copied successfully."
    } catch {
        Write-Host "Error: Failed to copy EFI files. Details: $($_.Exception.Message)"
    }
} else {
    if (-not (Test-Path X:\EFI\)) {
        Write-Host "Error: Source path 'X:\EFI\' does not exist."
    }
    if (-not (Test-Path S:\EFI\)) {
        Write-Host "Error: Destination path 'S:\EFI\' does not exist."
    }
}

# Search for 'EFI' folder containing 'bootx64.efi' signed by 'Windows UEFI CA 2023'
$efiFolder = Get-ChildItem -Path . -Recurse -Directory -Filter "EFI" | Where-Object {
    Test-Path "$($_.FullName)\bootx64.efi"
} | Select-Object -First 1

if ($efiFolder) {
    $bootEfiPath = Join-Path $efiFolder.FullName "bootx64.efi"
    try {
        $signature = Get-AuthenticodeSignature -FilePath $bootEfiPath
        if ($signature.SignerCertificate.Subject -like "*Windows UEFI CA 2023*") {
            Copy-Item -Path $efiFolder.FullName -Destination S:\ -Recurse -Force
            Write-Host "EFI folder with signed bootx64.efi copied to S:\ successfully."
        } else {
            Write-Host "bootx64.efi is not signed by 'Windows UEFI CA 2023'."
        }
    } catch {
        Write-Host "Error checking signature or copying EFI folder: $($_.Exception.Message)"
    }
} else {
    Write-Host "No EFI folder with bootx64.efi found in this directory or subdirectories."
}

# Step 4: Run mountvol S: /d
$response = Read-UserInput "Do you want to run: mountvol S: /d?"
if ($response -eq 'y') {
    mountvol S: /d
}
