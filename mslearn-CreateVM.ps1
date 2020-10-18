$rg = "student08-mslearn-cli"
$vnetName = "virtnet-mslearn-cli"
$location = "westeurope"


Write-Host 'Starting...'
#Get resource group
Get-AzResourceGroup -Name $rg -ErrorVariable notPresent -ErrorAction SilentlyContinue
#Check if resource group exists, if not then create it
if ($notPresent)
{
    # ResourceGroup doesn't exist
    Write-Host 'Resrouce group does not exist'
    New-AzResourceGroup -Name $rg -Location $location
}


$Subnet= New-AzVirtualNetworkSubnetConfig -Name default -AddressPrefix 10.0.0.0/24
New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rg -Location $location -AddressPrefix 10.0.0.0/16 -Subnet $Subnet


#azureuser azureuser123!
New-AzVm `
 -ResourceGroupName $rg `
 -Name "dataProcStage1" `
 -VirtualNetworkName $vnetName `
 -SubnetName "default" `
 -image "Win2016Datacenter" `
 -Size "Standard_B1s"

$PIPdataProcStage1 = Get-AzPublicIpAddress -Name dataProcStage1

#azureuser azureuser123!
New-AzVm `
 -ResourceGroupName $rg `
 -Name "dataProcStage2" `
 -VirtualNetworkName $vnetName `
 -SubnetName "default" `
 -image "Win2016Datacenter" `
 -Size "Standard_B1s"

$nic = Get-AzNetworkInterface -Name dataProcStage2 -ResourceGroup $rg
$nic.IpConfigurations.publicipaddress.id = $null
Set-AzNetworkInterface -NetworkInterface $nic 

