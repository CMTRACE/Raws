Start-OSDCloud -Firmware -ZTI -OSName 'Windows 11 24H2 x64' -OSEdition Enterprise -OSLanguage en-us -OSActivation Volume
Add-WindowsPackage -PackagePath 'D:\CU\windows11.0-kb5058411-x64_2025-05.msu' -Path 'C:\'
$process = Start-Process -FilePath "C:\Windows\System32\bcdboot.exe" -ArgumentList "C:\Windows", "/v", "/c" -Wait -NoNewWindow -PassThru
$process = Start-Process -FilePath "C:\Windows\System32\DISM.exe" -ArgumentList "/Image:C:\", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase", "/ScratchDir:C:\Windows\Temp" -Wait -NoNewWindow -PassThru
Restart-Computer
