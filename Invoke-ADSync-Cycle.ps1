$computer = ""
try{
    Invoke-Command -ComputerName $computer -ScriptBlock {Start-ADSyncSyncCycle}
}catch{
    Write-Host "Error Starting AD Sync Cycle"
}
#Set-MsolDirSyncFeature -Feature EnforceCloudPasswordPolicyForPasswordSyncedUsers -Enable $true
