Import-module dns

$subnets = @
(
''
)
for($i = 0; $i -lt $subnets.length; $i++)
{
    Add-DnsServerPrimaryZone -NetworkID $subnets[$i] -ReplicationScope "Forest" -ErrorAction Continue
}
