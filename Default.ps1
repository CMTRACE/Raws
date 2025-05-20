Try {
    Write-Host "Starting OSDCloud deployment..."
    Start-OSDCloud -Firmware -ZTI -OSName 'Windows 11 24H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSActivation Volume
    Write-Host "OSDCloud deployment completed."

    $UpdatePath = 'D:\osdcloud\windows11.0-kb5058411-x64_2025-05.msu'
    Write-Host "Adding Windows package: $UpdatePath"
    Add-WindowsPackage -PackagePath $UpdatePath -Path 'C:\'
    Write-Host "Windows package added."

    Write-Host "Updating boot files with bcdboot..."
    Start-Process -FilePath "C:\Windows\System32\bcdboot.exe" -ArgumentList "C:\Windows", "/v", "/c" -Wait -NoNewWindow -PassThru
    Write-Host "Boot files updated."

    Write-Host "Running DISM cleanup..."
    Start-Process -FilePath "C:\Windows\System32\DISM.exe" -ArgumentList "/Image:C:\", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase", "/ScratchDir:C:\Windows\Temp" -Wait -NoNewWindow -PassThru
    Write-Host "DISM cleanup completed."

    Write-Host "Restarting computer..."
    Restart-Computer
}
Catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    Throw
}
Finally {
    Write-Host "===== OSDCloud Deployment Finished ====="
}
