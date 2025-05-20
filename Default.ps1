function Invoke-OSDCloudDeployment {
    try {
        Start-OSDCloud -Firmware -ZTI -OSName 'Windows 11 24H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSActivation Volume
        Write-Host "[✓] OSDCloud deployment completed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "[✗] Failed to execute Start-OSDCloud: $_" -ForegroundColor Red
    }
}

function Install-WindowsUpdatePackage {
    try {
        Add-WindowsPackage -PackagePath 'D:\CU\windows11.0-kb5058411-x64_2025-05.msu' -Path 'C:\'
        Write-Host "[✓] Windows update package installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "[✗] Failed to install Windows update package: $_" -ForegroundColor Red
    }
}

function Set-BootLoader {
    try {
        $process = Start-Process -FilePath "C:\Windows\System32\bcdboot.exe" -ArgumentList "C:\Windows", "/v", "/c" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "[✓] Boot configuration updated successfully." -ForegroundColor Green
        } else {
            Write-Host "[✗] bcdboot failed with exit code $($process.ExitCode)." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "[✗] Error running bcdboot: $_" -ForegroundColor Red
    }
}

function Optimize-WindowsImage {
    try {
        $process = Start-Process -FilePath "C:\Windows\System32\DISM.exe" -ArgumentList "/Image:C:\", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "[✓] Image cleanup completed successfully." -ForegroundColor Green
        } else {
            Write-Host "[✗] Image cleanup failed with exit code $($process.ExitCode)." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "[✗] Error running DISM cleanup: $_" -ForegroundColor Red
    }
}

function Restart-System {
    try {
        Restart-Computer
        Write-Host "[✓] System restart initiated." -ForegroundColor Green
    }
    catch {
        Write-Host "[✗] Failed to restart system: $_" -ForegroundColor Red
    }
}

# Execute the workflow
Invoke-OSDCloudDeployment
Install-WindowsUpdatePackage
Set-BootLoader
Optimize-WindowsImage
Restart-System
