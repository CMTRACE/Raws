<#
.SYNOPSIS
    Automated Windows 11 24H2 Enterprise deployment and servicing script.
.DESCRIPTION
    This script performs a zero-touch deployment, applies a cumulative update,
    repairs the image, and restarts the system. Includes logging and error handling.
#>

# Set strict mode for safer scripting
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Define log file
$LogFile = "C:\OSDCloud_Deploy.log"
Function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "$timestamp`t$Message"
}

# Start logging
Write-Log "===== OSDCloud Deployment Started ====="

Try {
    Write-Log "Starting OSDCloud deployment..."
    Start-OSDCloud -Firmware -ZTI -OSName 'Windows 11 24H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSActivation Volume
    Write-Log "OSDCloud deployment completed."

    $UpdatePath = 'D:\CU\windows11.0-kb5058411-x64_2025-05.msu'
    Write-Log "Adding Windows package: $UpdatePath"
    Add-WindowsPackage -PackagePath $UpdatePath -Path 'C:\'
    Write-Log "Windows package added."

    Write-Log "Updating boot files with bcdboot..."
    Start-Process -FilePath "C:\Windows\System32\bcdboot.exe" -ArgumentList "C:\Windows", "/v", "/c" -Wait -NoNewWindow -PassThru
    Write-Log "Boot files updated."

    Write-Log "Running DISM cleanup..."
    Start-Process -FilePath "C:\Windows\System32\DISM.exe" -ArgumentList "/Image:C:\", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase", "/ScratchDir:C:\Windows\Temp" -Wait -NoNewWindow -PassThru
    Write-Log "DISM cleanup completed."

    Write-Log "Restarting computer..."
    Restart-Computer
}
Catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Throw
}
Finally {
    Write-Log "===== OSDCloud Deployment Finished ====="
}
