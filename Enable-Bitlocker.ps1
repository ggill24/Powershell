$tpmenabled = wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get IsEnabled_InitialValue

if(!$tpmenabled){
    Write-Host "Enabling TPM"
    $tpmresult = Initialize-Tpm -AllowClear -AllowPhysicalPresence
    if(!$tpmresult.RestartRequired -or $tpmresult.ShutdownRequired){
        Write-Host "shutdown/restart required...setting 10 minute timer"
        Start-Process "C:\Windows\System32\shutdown.exe" -ArgumentList "/r /f /t 600"
    }
    return
}

$bitlocker = Get-BitlockerVolume
if($bitlocker.VolumeType -eq "OperatingSystem" -and $bitlocker.ProtectionStatus -eq 'on' -and $bitlocker.EncryptionPercentage -eq '100'){
    Write-host "Bitlocker is encrypted on the OS drive"
    return
}
if($bitlocker.VolumeType -eq "OperatingSystem" -and $bitlocker.ProtectionStatus -eq 'on' -and $bitlocker.EncryptionPercentage -gt '0' -and $bitlocker.EncryptionPercentage -lt '10'){
    Write-host "Bitlocker is encrypting the OS drive"
    return
}

$dc = @('')

foreach($controller in $dc)
{
    $result = (Test-NetConnection -ComputerName $controller -Port 445).TcpTestSucceeded
    if($result){
        Write-Host "One of the DCs $controller is reachable"
        break
    }
    Write-Host "No DCs are reachable"
    return
}
Enable-BitLocker -MountPoint "C:" -EncryptionMethod Aes256 -UsedSpaceOnly -TpmProtector -SkipHardwareTest
