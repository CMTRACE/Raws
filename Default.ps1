# Function to prompt user for 'y' or 'no'
function Read-UserInput {
	param (
		[string]$message
	)
	do {
		$response = (Read-Host "$message (y/no)").ToLower()
		if ($response -ne 'y' -and $response -ne 'no') {
			Write-Host "Invalid input. Please enter 'y' for yes or 'no' for no."
		}
	} while ($response -ne 'y' -and $response -ne 'no')
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
$response = Read-UserInput "Do you want to copy EFI files from X: drive to S:\, overwriting all files?"
if ($response -eq 'y') {
    try {
        Copy-Item -Path X:\EFI\* -Destination S:\EFI\ -Recurse -Force -ErrorAction Stop
        Write-Host "EFI files copied successfully."
    } catch {
        Write-Host "Error: Failed to copy EFI files. $_"
    }
}
# Step 4: Run mountvol S: /d
$response = Read-UserInput "Do you want to run: mountvol S: /d?"
# Step 4: Run mountvol S: /d
$response = Read-UserInput "Do you want to run: mountvol S: /d?"
if ($response -eq 'y') {
	if (Test-Path S:\) {
		mountvol S: /d
	} else {
		Write-Host "The S: drive is not currently mounted. Skipping dismount."
	}
}
