$subnets = @(
    ''
)

#Connect-AzAccount
$nsgName = ''
$rg = '' 
$NSG = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rg

<#foreach($s in $subnets){
    
    $Params = @{
        'Name'                     = ''
        'NetworkSecurityGroup'     = $NSG
        'Protocol'                 = 'UDP'
        'Direction'                = 'Inbound'
        'Priority'                 = 200
        'SourceAddressPrefix'      = $s
        'SourcePortRange'          = '*'
        'DestinationAddressPrefix' = '*'
        'DestinationPortRange'     = ''
        'Access'                   = 'Allow'
      }
      
Set-AzNetworkSecurityRuleConfig @Params | Set-AzNetworkSecurityGroup
}#>

$Params = @{
    'Name'                     = ''
    'NetworkSecurityGroup'     = $NSG
    'Protocol'                 = 'TCP'
    'Direction'                = 'Inbound'
    'Priority'                 = 230
    'SourceAddressPrefix'      = $subnets
    'SourcePortRange'          = '*'
    'DestinationAddressPrefix' = '*'
    'DestinationPortRange'     = ''
    'Access'                   = 'Allow'
  }
  Add-AzNetworkSecurityRuleConfig  @Params | Set-AzNetworkSecurityGroup
