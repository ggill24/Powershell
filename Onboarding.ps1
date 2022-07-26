$LicenseSku = @{
    SPB = ""
}
$UsageLocation = @{
    Canada = "CA"
}

$global:log = ""
$global:domain = "@domain"
$global:OU = ""
$global:Groups = @()
$global:O365Groups = @()
$global:O365SharedMailbox = @()
$global:Sam = ""
$global:Name = ""
$global:UPN = ""
$global:UserExists
$global:cred
function Update-TeamMessage{
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Message
    )
    $ContentType = 'Application/Json'
    $Body = @{ text = $Message } 
    $Uri = ''

    Invoke-RestMethod -Method post -ContentType $ContentType -Body ($Body | ConvertTo-Json) -Uri $Uri
}
function OnBoardUserAD {
    
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$FirstName,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$LastName,
        [Parameter(Mandatory=$true, Position=3)]
        [string]$JobTitle,
        [Parameter(Mandatory=$true, Position=4)]
        [string]$Office,
        [Parameter(Mandatory=$true, Position=6)]
        [string]$Department,
        [Parameter(Mandatory=$true, Position=7)]
        [string]$City,
        [Parameter(Mandatory=$true, Position=8)]
        [string]$PostalCode,
        [Parameter(Mandatory=$true, Position=9)]
        [string]$Province,
        [Parameter(Mandatory=$false, Position=10)]
        [string]$Mobile
)

        $global:Sam = $FirstName.Substring(0,1) + $Lastname
        $global:Name = $FirstName + " " + $LastName
        $global:Sam = $Sam + $domain
        
        
        try{
            $UserExists = Get-ADUser $global:Sam
        }catch{
            $UserExists = $null
        }
        if($UserExists -ne $null){
            $global:log += "$global:Sam already exists in Active Directory!<br/>"
            return $false
        }

       
        
        $global:log += "$global:Sam will be placed in the OU $OU<br/>"
        $Password = Read-Host -AsSecureString "Enter a password"
        $proxyAddresses = "SMTP:" + $UPN
        $UserCreated = $false
        
        try{

        New-ADUser -GivenName $FirstName -Name $Name -Surname $LastName -SamAccountName $Sam -UserPrincipalName $UPN -AccountPassword $Password -Enabled $false -DisplayName $Name -Description $JobTitle -EmailAddress $UPN -MobilePhone $Mobile -PostalCode $PostalCode -StreetAddress $Office -City $City -Country "CA" -Office $Office -State "$Province" -Title $JobTitle -Path $OU -OtherAttributes @{       
            'proxyAddresses'= $proxyAddresses} -Credential $cred
            return $true
           
        }catch{
            $global:log += "$global:Sam was not created! <br/>"
            Write-Warning "$global:Sam was not created!"
        }
       
        return $false
    }
Function Update-ADUserGroupMembership{
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Username,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$Department

    )
    $global:log += "Assigning group membership to $Username<br/>"
    foreach($g in $global:Groups){
           try{
             add-ADGroupMember -Identity $g -Members $Username -Credential $cred
             $global:log += "Added $Username to $g<br/>"
           }catch{
               $global:log += "Failed to add $username to $g<br/>"
               continue
           }
        }
    }
           

function LicenseUser{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$sku,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$upn
    )
    Write-Host "Checking if $upn already has $sku assigned"
    $hasLicense = Get-MgUserLicenseDetail -UserId $upn | Where-Object -Property "SkuPartNumber" -eq "SPB" | Select-Object -ExpandProperty SkuId
    if(!([string]::IsNullOrEmpty($hasLicense))){Write-Warning "$upn already has the license $sku assigned!"; $hasLicense; return $true}
    Write-Host "Assigning $sku license to $upn"
    try{
        Update-MgUser -UserId $upn -UsageLocation $UsageLocation.Get_Item("Canada")
        Set-MgUserLicense -UserId $upn -AddLicenses @{SkuId = $sku} -RemoveLicenses @()
        Write-Host "Assigned $sku to $upn!" -ForegroundColor Green
        #Update-MgGroup -GroupId -ErrorAction SilentlyContinue
        return $true
    }catch{
        Write-Warning "Failed to assign $sku to $upn!"
        return $false
    }
}
function Set-365Groups{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$upn
    )
    Write-Host "Assigning Groups to $upn"
    foreach($g in $O365Groups){
        Add-DistributionGroupMember -Identity $g -Member $upn
    }
    Write-Host "Assigning Shared Mailboxes to $upn"
    foreach($s in $O365SharedMailbox){
        Add-MailboxPermission $s -User $upn -AccessRights FullAccess -InheritanceType all 
    }    
}
function SyncADO365 {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [array]$upn
    )
    #return $false
    Write-Host "Syncing"
    Write-Host $upn
    $SyncServer = ""
    $result = Invoke-Command -ComputerName $SyncServer -ScriptBlock {start-adsyncsynccycle} -AsJob
    Wait-Job -Job $result
    $SuccessValue = 15000
    $FailValue = 30000
    $TimeToWait = ($result).HasMoreData ? $SuccessValue : $FailValue
    $TimeToWaitSeconds = [timespan]::FromMilliseconds($TimeToWait).Seconds

    if($TimeToWait){
        $global:log += "Force Sync Success...will check for user in O365 every $TimeToWaitSeconds seconds</br>"
    }else {
        $global:log += "Force Sync Failed...will check for user in O365 every $TimeToWaitSeconds seconds</br>"
    }
    $count = 0

    do{
        $count++
        $userSynced = Get-Mailbox $upn | Select-Object -ExpandProperty Name -ErrorAction SilentlyContinue
        if($userSynced -ne $null){return $true}
        Start-Sleep -Seconds $TimeToWaitSeconds
       
    }while($userMailbox -eq $null -and $count -lt 1)
    return $false
    #Over complicating just get failed value from an attempted sync invoke
    <#$result = (Resolve-DnsName -Name "").IPAddress -eq ("") ? $false : $true
    if(!($result)){return $false}
    $result = (Test-NetConnection -ComputerName "" -Port 1 ).PingSucceeded ? $true : $false#>
    

    #return ($result).result ? $true : $false
}
    
Function Connect-ExchangeOnlineCert{
    #Connect-ExchangeOnline -CertificateFilePath "" -CertificatePassword (ConvertTo-SecureString -String "" -AsPlainText -Force) -AppID "" -Organization ""
    $paramConnectExchangeOnline = @{
        CertificateThumbprint = ""
        AppId                 = ""
        Organization          = ""
    }
    
    Connect-ExchangeOnline @paramConnectExchangeOnline
}
Function Connect-GraphAPI{
Write-Host "Connecting To MS Graph" -ForegroundColor Green

$clientId = ""
$tenantName = ""
$resource = "https://graph.microsoft.com/"

try{
    
    Connect-MgGraph -ClientID $clientId -TenantId $tenantName -CertificateThumbprint "" ## Or -CertificateThumbprint instead of -CertificateName
    return $true
}catch{
    return $false
}
}


#START
try{
    Import-Module Microsoft.Graph.Users -Global
    Import-Module Microsoft.Graph.Users.Actions -Global
    Import-Module Microsoft.Graph.Groups -Global
    Import-Module ActiveDirectory 
    Import-Module ImportExcel
}catch{
    Write-Warning "Fail To Import Modules"
    return
}


$OnBoardPath = "Onboarding.xlsx"
$OnBoardUsersAD = [System.Collections.ArrayList]::new()
$OnBoardUsersAD365 = [System.Collections.ArrayList]::new()
$OnBoardUsersOU = [System.Collections.ArrayList]::new()
$onBoardUsersSecurityGroup = [System.Collections.ArrayList]::new()

Class NewUser{
    [string]$FirstName
    [string]$LastName
    [string]$JobTitle
    [string]$Address
    [string]$City
    [string]$Province
    [string]$PostalCode
    [string]$Department
    [array]$DistributonGroups
    [array]$SharedMailboxes
    [array]$SecurityGroups
    [string]$OrganizationalUnit
    [string]$Mobile
    [string]$Email
}


$cred = Get-Credential
function Create-ADUser{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$FirstName,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$LastName,
        [Parameter(Mandatory=$true, Position=3)]
        [string]$JobTitle,
        [Parameter(Mandatory=$true, Position=4)]
        [string]$Office,
        [Parameter(Mandatory=$true, Position=6)]
        [string]$Department,
        [Parameter(Mandatory=$true, Position=7)]
        [string]$City,
        [Parameter(Mandatory=$true, Position=8)]
        [string]$PostalCode,
        [Parameter(Mandatory=$true, Position=9)]
        [string]$Province,
        [Parameter(Mandatory=$false, Position=10)]
        [string]$Mobile
        
    )
    $domain = "@domain"
    $name = $FirstName + " " + $LastName
    $sam = $FirstName.Substring(0,1) + $LastName
    $upn = $sam + $domain
    
    try{
        $userExists = Get-ADUser $sam
    }catch{
        $userExists = $null
    }
    if($UserExists -ne $null){
        $global:log += "$global:sam already exists in Active Directory!<br/>"
    }

    $global:log += "$sam will be placed in the OU: $ou <br/>"
    $password =  ConvertTo-SecureString "" -AsPlainText -Force
    $proxyAddresses = "SMTP:" + $upn
    $job
    try{
    
        New-ADUser -GivenName $FirstName -Name $name -Surname $LastName -SamAccountName $sam -UserPrincipalName $upn -AccountPassword $password -Enabled $false -DisplayName $name -Description $JobTitle -EmailAddress $upn -MobilePhone $Mobile -PostalCode $PostalCode -StreetAddress $Office -City $City -Country "" -Office $Office -State $Province -Title $JobTitle -Path "" -OtherAttributes @{       
            'proxyAddresses'= $proxyAddresses} -Credential $cred  
            return $true
    }catch{
        $global:log += "$sam was not created! <br/>"
       
    }
    return $false

}
function Set-ADOU{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$FirstName,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$LastName,
        [Parameter(Mandatory=$true, Position=2)]
        [string]$Org
    )
    $sam = $FirstName.Substring(0,1) + $LastName
    try{
        Get-ADUser -Identity $sam | Move-ADObject -TargetPath $Org -Credential $cred
        $global:log += "Moved $sam to OU: $Org"
        return $true
    }catch{
        $global:log += "Failed to move $sam to OU: $Org"
        return $false
    }
}
function Set-ADSG{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$FirstName,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$LastName,
        [Parameter(Mandatory=$true, Position=2)]
        [array]$Groups
    )
    $sam = $FirstName.Substring(0,1) + $LastName
    try{
        foreach($g in $Groups){
            Write-Host $g "to $sam"
            $global:log += "Assigning security group $g"
            Add-ADGroupMember -Identity $g -Members $sam -Credential $cred
            $global:onBoardUsersSecurityGroup = @($global:onBoardUsersSecurityGroup | Where-Object {$_ -ne $g})
        }
    }catch{
        $global:log += "Failed to assign $g"
        return $false
    }
    return $true
}

function Sync-ADO365 {
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [array]$upn
    )
    Write-Host "Syncing"
    Write-Host $upn
    $SyncServer = ""
    $result = Invoke-Command -ComputerName $SyncServer -ScriptBlock {start-adsyncsynccycle} -AsJob
    Wait-Job -Job $result
    $SuccessValue = 15000
    $FailValue = 30000
    $TimeToWait = ($result).HasMoreData ? $SuccessValue : $FailValue
    $TimeToWaitSeconds = [timespan]::FromMilliseconds($TimeToWait).Seconds

    if($TimeToWait){
        $global:log += "Force Sync Success...will check for user in O365 every $TimeToWaitSeconds seconds</br>"
    }else {
        $global:log += "Force Sync Failed...will check for user in O365 every $TimeToWaitSeconds seconds</br>"
    }
    $count = 0
    $userSynced = @()
    do{
        $count++
        $userSynced = @()
        foreach($u in $upn){
            try{
            $userSynced += Get-User $u | Select-Object -ExpandProperty Name <#-ErrorAction SilentlyContinue#>
            }catch{
                continue
            }
        }
        if($userSynced.Length -eq $upn.Length){return $true}
        Start-Sleep -Seconds $TimeToWaitSeconds
       
    }while($userSynced.Length -eq $upn.Length -and $count -lt 10)
    return $false
}

    
#Connect-ExchangeOnline
while($true){
    $log += ""
    $log += "Starting<br />"
    $OnBoard = Import-Excel -Path $OnBoardPath
    #Collect all users from Onboard excel sheet
    if($OnBoard.Length -ge 1){
        $log += "Found Entries: " + $OnBoard.Length + " Validating<br />"
        foreach($on in $OnBoard){
            #Only collect users with required fields filled
            if(!([string]::IsNullOrEmpty($on.'First Name')) -and (!([string]::IsNullOrEmpty($on.'Last Name')) -and (!([string]::IsNullOrEmpty($on.'Job Title')) -and (!([string]::IsNullOrEmpty($on.'Address')) -and (!([string]::IsNullOrEmpty($on.City)) -and (!([string]::IsNullOrEmpty($on.Province)) -and (!([string]::IsNullOrEmpty($on.'Postal Code'))))))))){
              $log += "Validation Passed!<br/>"
              #Don't add users already collected from Onboard excel sheet
              $OnBoardUsersAD | foreach{
                  if($_.FirstName -eq $on.'First Name'){
                      Write-Host "Exists Skipping"
                      continue
                  }
                }
              #Create user as a NewUser class object and add to OnboardUsers 
              $newHire = New-Object NewUser
              $newHire.FirstName = $on.'First Name'
              $newHire.LastName = $on.'Last Name'
              $newHire.JobTitle = $on.'Job Title'
              $newHire.Address = $on.Address
              $newHire.City = $on.City
              $newHire.Province = $on.Province
              $newHire.PostalCode = $on.'Postal Code'
              $newHire.Department = $on.Department
              $newHire.Mobile = $on.Mobile
              $newHire.Email = $on.'First Name'.Substring(0,1) + $on.'Last Name' + "@domain"
              
              #Set Office 365 Distribution Groups/AD Security Group/AD OU based on Department
              switch ($newHire.Department) {
                "Call Center"{
                    $newHire.OrganizationalUnit = "" 
                    $newHire.SecurityGroups += ("")
                    $newHire.DistributonGroups += ("")
                    $newHire.SharedMailboxes += ("")
                    break
                    
                }
                "Accounting"{
                    $newHire.OrganizationalUnit = "" 
                    $newHire.SecurityGroups += ("")
                    $newHire.DistributonGroups += ("")
                    break
                    
                    
                }
                "Customer Relations"{
                    $newHire.OrganizationalUnit = "" 
                    $Groups += ("")
                    break
                    
                }
                "DM"{
                    $OU = "" 
                    $Groups += ("")
                    break
                    
                }
                "HR"{
                    $OU = "" 
                    $Groups += ("")
                    break
                    
                    
                }
                "Marketing"{
                    $OU = "" 
                    $Groups += ("")
                    break
                    
                }
                "VP"{
                    $OU = "" 
                    $Groups += ("")
                    break
                    
                }
                "Properties"{
                    $OU = "" 
                    $Groups += ("")
                    break
                    
                }
                "Regional Trainers"{
                    $OU = "" 
                    $Groups += ("")
                    break
                    
                }
                Default { $OU = ""; $log += "OU defaulting to $OU <br/>"}
            }
                
           
           $OnBoardUsersAD += $newHire
           $OnBoardUsersAD365 += $newHire.Email
           $OnBoardUsersOU += $newHire.OrganizationalUnit
           $onBoardUsersSecurityGroup += $newHire.SecurityGroups
        }

           #Create AD
            foreach($u in $OnBoardUsersAD){
                $jobCreateAD = Create-ADUser -FirstName $u.FirstName -Last $u.LastName -JobTitle $u.JobTitle -Office $u.Address -Department $u.Department -City $u.City -PostalCode $u.PostalCode -Province $u.Province -Mobile $u.Mobile
                if($jobCreateAD){
                    Write-Host "AD CREATE DONE"
                    $OnBoardUsersAD = @($OnBoardUsersAD | Where-Object {$_ -ne $u})
                }
            }
            #Set AD OU
            foreach($o in $OnBoardUsersOU){
                $jobSetOU = Set-ADOU -FirstName $u.FirstName -LastName $u.LastName -Org $u.OrganizationalUnit
                if($jobSetOU){
                    Write-Host "OU MOVE DONE"
                    $OnBoardUsersOU = @($OnBoardUsersOU | Where-Object {$_ -ne $o})
                }
            }
             #Set AD Security Groups TODO: SG Group removal upon success
            foreach($sg in $onBoardUsersSecurityGroup){
                 Write-Host "SG $sg"
                 $jobSetSG = Set-ADSG -FirstName $u.FirstName -LastName $u.LastName -Groups $u.SecurityGroups
               
            }
            #SyncO365 TODO remove synced emails
            $jobSyncAD365 = Sync-ADO365 -upn $OnBoardUsersAD365


           
                
                
           
        Update-TeamMessage -Message $log
    }
}

        
    

    Start-Sleep -Seconds 15
}

return



#Connect-GraphAPI
#LicenseUser -sku $LicenseSku.SPB -upn 
#$O365Groups += ("")
#$O365SharedMailbox += ("")
#Disconnect-MgGraph
#return



$OnBoardPath = "\\Onboarding.xlsx"
$result = $false
#Connect-ExchangeOnline -UserPrincipalName $UPN
#Connect-GraphAPI
#LicenseUser -sku $LicenseSku.Get_Item("SPB") -upn ""
#$O365Groups += ("")
#$O365SharedMailbox += ("")
#Connect-ExchangeOnlineCert
#Disconnect-ExchangeOnline -Confirm:$false
#Disconnect-MgGraph

$cred = Get-Credential
<#While($true){
    $log += ""
    $log += "Starting<br />"
    $OnBoard = Import-Excel -Path $OnBoardPath
   
    if($OnBoard.Length -ge 1){
        $log += "Found Entries: " + $OnBoard.Length + " Validating<br />"
        foreach($on in $OnBoard){
            #Check if required fields in excel have been filled
            if(!([string]::IsNullOrEmpty($on.'First Name')) -and (!([string]::IsNullOrEmpty($on.'Last Name')) -and (!([string]::IsNullOrEmpty($on.'Job Title')) -and (!([string]::IsNullOrEmpty($on.'Address')) -and (!([string]::IsNullOrEmpty($on.City)) -and (!([string]::IsNullOrEmpty($on.Province)) -and (!([string]::IsNullOrEmpty($on.'Postal Code'))))))))){
              $log += "Validation Passed!<br/>"
               #Create AD User (returns false on failure or if user already exists)
               if(OnBoardUserAD -FirstName $on.'First Name' -LastName $on.'Last Name' -JobTitle $on.'Job Title' -Office $on.Address -City $on.City -PostalCode $on.'Postal Code' -Province $on.Province -Mobile $on.Mobile -Department $on.Department){
                  $log += "$global:Sam has been created in Active Directory<br/>"
                  Write-Host "Syncing O365"
                  if((SyncADO365 -upn $UPN).IsSynchronized){
                    $global:log += "User Synced and Found in O365</br>"
                    Write-Host "Licensing User"
                    
                }else{
                    $global:log += "User Sync Failed Not Found in 365</br>"
                }
                  Update-TeamMessage -Message $log
                  Update-ADUserGroupMembership -Username $global:Sam -Department $on.Department
                  Update-TeamMessage -Message $log
                   #SyncADO365
                   #return
                   <#if(ConnectToGraphAPI){
                        LicenseUser -sku "SPB" -
                   }#>
               <#>}else{
                Update-TeamMessage -Message $log   
                $OU = ""
                $Groups = @()
                $O365Groups = @()
                $O365SharedMailbox = @()
                $Sam = ""
                $Name = ""
                $UPN = ""
               
                   
               }

               Update-TeamMessage -Message $log
               
            }else{
                $log += "Validation Failed! Verify all the fields in the onboarding sheet have been filled correctly!<br/>"
                Update-TeamMessage -Message $log
            }
          
        }
    }else{
        $log += "No users found at this time</br>"
        Update-TeamMessage -Message $log
    }
    Update-TeamMessage -Message $log
    Start-Sleep -Seconds 15

    
}


#$count = 0;
<#do{
    $count++
    if($count -ge 5){Write-Host "Failed to answer a simple question...im out" return}
    $task = Read-Host "1. Onboarding`n2. Offboarding`nWhat would you like to do?"
}while (-not($task -eq '1') -and -not ($task -eq '2'))

switch ($task) {
    "1"{OnBoard}
   
    "2"{OffBoard}

    Default {Write-Output "Unexpected Input Task"}
}#>

#TEST AREA - this will be called from OnBoarding once testing is completed
#Write-Output "Starting"
#Time to wait in between checks to O365 for user to appear - Time between

#$OU = "" 
#$Groups += ("")
#$O365Groups += ("")
#$O365SharedMailbox += ("")

#Import-Module -Global -ExchangeOnlineManagement
#Import-Module MSOnline -SkipEditionCheck
#Connect-MsolService
#LicenseUser -Sku "SPB" -Identity ""
#$t = [LicenseSku].GetEnumname(1).ToString()

#Connect-ExchangeOnline -UserPrincipalName ""
#$mailbox = Get-User -Identity ""
#$mailbox.mai
#Disconnect-ExchangeOnline
	
#Connect-MsolService
	
#Get-MsolAccountSku
#[Microsoft.Online.Administration.Automation.ConnectMsolService]::ClearUserSessionState()
