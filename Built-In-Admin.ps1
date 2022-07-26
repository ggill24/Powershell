$adminName = ""
$builtinAdmin = Get-LocalUser | Where-Object{$_.SID -like "*-500"}
$name = $builtinAdmin | Select-Object -ExpandProperty Name

if(!($name.Equals($adminName))){
    Rename-LocalUser -Name $name -NewName $adminName
}
#Built-in SID is always the same even with a name change so if the above fails we still want to enable the
#account as LAPS will still configure a password and apps can still be pushed out and name fixed
$isEnabled = Get-LocalUser | Where-Object{$_.SID -like "*-500"} | Select-Object -ExpandProperty "Enabled"
if(!($isEnabled)){
    Enable-LocalUser -Name $adminName
}
Remove-LocalUser -Name ""
Start-Process "gpupdate.exe" -ArgumentList "/force"
