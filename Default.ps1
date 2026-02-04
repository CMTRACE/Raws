$OSName = 'Windows 11 24H2 x64'
$OSEdition = 'Enterprise'
$OSActivation = 'Volume'
$OSLanguage = 'en-us'

#Set OSDCloud Vars
$Global:MyOSDCloud = [ordered]@{
    Restart = [bool]$true
    RecoveryPartition = [bool]$true
    OEMActivation = [bool]$true
    WindowsUpdate = [bool]$false
    WindowsUpdateDrivers = [bool]$false
    WindowsDefenderUpdate = [bool]$false
    SetTimeZone = [bool]$true
    ClearDiskConfirm = [bool]$false
    ShutdownSetupComplete = [bool]$false
    SyncMSUpCatDriverUSB = [bool]$false
    CheckSHA1 = [bool]$false
}

Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage
