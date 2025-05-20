Try {
    Write-Host "Starting OSDCloud deployment..."
    Start-OSDCloud -Firmware -ZTI -OSName 'Windows 11 24H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSActivation Volume
    Write-Host "OSDCloud deployment completed."

    $UpdatePath = 'D:\osdcloud\windows11.0-kb5058411-x64_2025-05.msu'
    $UpdateUrl = "https://catalog.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/770c53ae-5610-402f-b5e9-fe86142003cc/public/windows11.0-kb5058411-x64_fc93a482441b42bcdbb035f915d4be2047d63de5.msu"
    $TempUpdatePath = "C:\Windows\Temp\windows11.0-kb5058411-x64_2025-05.msu"

    if (-Not (Test-Path $UpdatePath)) {
        Write-Host "Update file not found at $UpdatePath. Downloading from Microsoft Update Catalog..."
        Invoke-WebRequest -Uri $UpdateUrl -OutFile $TempUpdatePath
        $UpdatePath = $TempUpdatePath
        Write-Host "Download complete: $UpdatePath"
    }

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
