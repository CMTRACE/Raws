try {
    Start-OSDCloud -Firmware -ZTI -OSName 'Windows 11 24H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSActivation Volume
    Write-Host "Start-OSDCloud completed successfully." -ForegroundColor Green
}
catch {
    Write-Host "Error in Start-OSDCloud: $_" -ForegroundColor Red
    
}

try {
    Add-WindowsPackage -PackagePath 'D:\osdcloud\windows11.0-kb5058411-x64_2025-05.msu' -Path 'c:\'
    Write-Host "Add-WindowsPackage completed successfully." -ForegroundColor Green
}
catch {
    Write-Host "Error in Add-WindowsPackage: $_" -ForegroundColor Red
    
}

try {
$process = Start-Process -FilePath "C:\Windows\System32\bcdboot.exe" -ArgumentList "C:\Windows", "/v", "/c" -Wait -NoNewWindow -PassThru
if ($process.ExitCode -eq 0) {
    Write-Host "bcdboot executed successfully." -ForegroundColor Green
} else {
    Write-Host "bcdboot failed with exit code $($process.ExitCode)." -ForegroundColor Red
}
}
catch {
    Write-Host "Error running bcdboot: $_" -ForegroundColor Red
    
}

try {
    $process = Start-Process -FilePath "C:\Windows\System32\DISM.exe" -ArgumentList "/Image:C:\", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase" -Wait -NoNewWindow -PassThru
    if ($process.ExitCode -eq 0) {
    Write-Host "Image cleanup executed successfully." -ForegroundColor Green
} else {
    Write-Host "Image cleanup process failed with $($process.ExitCode)." -ForegroundColor Red}
}
catch {
    Write-Host "Error running DISM: $_" -ForegroundColor Red
}

try {
    Restart-Computer
    Write-Host "Restart-Computer command issued." -ForegroundColor Green
}
catch {
    Write-Host "Error restarting computer: $_" -ForegroundColor Red
    
}
