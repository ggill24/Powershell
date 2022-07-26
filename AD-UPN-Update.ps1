$upns = Get-ADUser -Filter * -SearchBase '' -Properties userPrincipalName | Select-object -ExpandProperty UserPrincipalName
$suffix = "@domain"
foreach($u in $upns)
{
    if($u.Contains("domain"))
    {
       if($u -match '^.*(?=(\@domain))')
       {
           $user = $u.Substring(0, $u.IndexOf('@'))
           $newUPN = $user + $suffix
           Write-Host $newUPN
           Write-Host $user
           Set-ADUser -UserPrincipalName $newUPN -Identity $user
           
       }
    }
}
