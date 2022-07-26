try{
    Connect-AzAccount
}catch{
    "Failed to connect to AZ Environment"
    return
}

Import-Module -Name Az.Resources -Global
$rgs = Get-AzResourceGroup * | Select-Object -ExpandProperty ResourceGroupName
$rgs
$total = $rgs.Count - 1

$selectedRG = Read-Host "Select a Resource Group (0 - $total)" 
$selectedRG = $rgs[$selectedRG]

"You have selected $selectedRG - fetching VMS"

$vms = Get-AzVM -ResourceGroupName $selectedRG

if($vms -eq $null){ Write-Host "No VMs found in $selectedRG"; return;}

$total = $vms.Count

"Found $total VMs"
$total = $vms.Count - 1

$selectedVM = Read-Host "Select a VM (0 - $total)"
$selectedVM = $vms[$total]
$selectedVM = Get-AzVM -ResourceGroupName $selectedRG -Name $selectedVM.Name

$disk = Get-AzDisk -ResourceGroupName $selectedRG -DiskName $selectedVM.StorageProfile.OsDisk.Name

[int]$diskSize = Read-Host "Enter a new disk size (I.E 512)"

try{
    Write-Warning "Stopping VM"
    Stop-AzVM -ResourceGroupName $selectedRG -Name $selectedVM.Name
    "Changing disk size to $diskSize GB"
    $disk.DiskSizeGB = $diskSize
    Update-AzDisk -ResourceGroupName $selectedRG -Disk $disk -DiskName $disk.Name
    Write-Warning "Starting VM"
    Start-AzVM -ResourceGroupName $selectedRG -Name $selectedVM.Name
}catch{
    Write-Warning "Failed to update disk size"
}


    
