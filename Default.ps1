# Function to prompt user for 'y' or 'no'
function Prompt-User {
    param (
        [string]$message
    )
    do {
        $response = Read-Host "$message (y/no)"
    } while ($response -ne 'y' -and $response -ne 'no')
    return $response
}

# Step 1: Run custom PowerShell command
$response = Prompt-User "Do you want to run the custom PowerShell command: Start-OSDCloud -Firmware -ZTI -OSName 'Windows 11 24H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSActivation Volume?"
if ($response -eq 'y') {
    Start-OSDCloud -Firmware -ZTI -OSName 'Windows 11 24H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSActivation Volume
}

# Step 2: Run mountvol S: /S
$response = Prompt-User "Do you want to run: mountvol S: /S?"
if ($response -eq 'y') {
    mountvol S: /S
}

# Step 3: Copy EFI files from X: drive to S:\, overwriting all files
$response = Prompt-User "Do you want to copy EFI files from X: drive to S:\, overwriting all files?"
if ($response -eq 'y') {
    Copy-Item -Path X:\EFI\* -Destination S:\EFI\ -Recurse -Force
}

# Step 4: Run mountvol S: /d
$response = Prompt-User "Do you want to run: mountvol S: /d?"
if ($response -eq 'y') {
    mountvol S: /d
}
