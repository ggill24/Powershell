Start-Sleep -Seconds 120
Import-Module Adaxes
#Get Machine Cert
$cert = Get-ChildItem "Cert:\LocalMachine\My\A283EF889C67A91E06671255D208177345F8FFBE"
#Get Azure APP Reg Cert (probably better to do a where clause against thumbprint)
#$cert = $cert[2]
$tenantID = ""
$clientID = ""
$privKey = ""


$GroupType = @{
    Distribution = "1"
    SharedMailbox = "2"
    AzureAssigned = "3"

}

#Connect Microsoft Graph
Connect-MgGraph -Certificate $cert -TenantId $tenantID -ClientId $clientID
Connect-ExchangeOnline -CertificateFilePath "C:\" -CertificatePassword (ConvertTo-SecureString -String $privKey -AsPlainText -Force) -AppID $clientID -Organization ""

$O365Groups = @()
$O365SharedMailbox = @()
$AzureGroups = @()

#Fetch | Department | will be used for Azure | O365 group assignment
$upn = Get-AdmUser -Identity "%sAMAccountName%" | Select-Object -ExpandProperty UserPrincipalName
$department = Get-AdmUser -Identity "%sAMAccountName%" -Properties department | Select-Object -ExpandProperty department

#Prepare O365 groups | mailboxes based on department | eventually switch to Azure dynamic assignment
switch ($department) {
    "Call Center"{
        $O365Groups += ("")
        $O365SharedMailbox += ("")
        $AzureGroups += ("")
        break
        
    }
    "Accounting"{
        $O365Groups += ("")
        $AzureGroups += ("")
        break
    }
}
function Set-Groups {
    
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [array]$Groups,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$GroupType,
        [Parameter(Mandatory=$true, Position=2)]
        [string]$user
    )
    if($O365Groups.Count -le 0) {Write-Host "No Groups Found"; return;}
    $command
    
    switch ($GroupType) {
        "1"{
            Write-Host "Is Distribution"
            $command =  'Add-DistributionGroupMember -Identity $g -Member $user'
        }
        "2"{
            Write-Host "Is Shared Mailbox"
            $command =   'Add-MailboxPermission $g -User $user -AccessRights FullAccess -InheritanceType all'
        }
        "3"{
            Write-Host "Is Azure Group"
            $params = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$user"
            }
            $command =  'New-MgGroupMemberByRef -GroupId $g -BodyParameter $params'
        
        }
    
    }
    foreach($g in $Groups){
        try{
            Invoke-Expression -Command $command
        }catch{
            continue
        }
       
    }
} 

Set-Groups -Groups $O365Groups -GroupType $GroupType.Get_Item("Distribution") -user $upn
Set-Groups -Groups $O365Groups -GroupType $GroupType.Get_Item("SharedMailbox") -user $upn
$userID = Get-MgUser -Select id,mail -All | Where-Object mail -eq $upn | Select-Object -ExpandProperty id
Set-Groups -Groups $AzureGroups -GroupType $GroupType.Get_Item("AzureAssigned") -user $userID





