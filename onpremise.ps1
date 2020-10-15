$rg = "student08-OnPremise-cli"
$vnet = "virtnet-onpremise-cli"
$location = "westeurope"
$VMLocalAdminUser = "LocalAdminUser"
$VMLocalAdminSecurePassword = ConvertTo-SecureString "Password" -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);


#Get resource group
Get-AzResourceGroup -Name $rg -ErrorVariable notPresent -ErrorAction SilentlyContinue

#Check if resource group exists, if not then create it
if ($notPresent)
{
    # ResourceGroup doesn't exist
    Write-Host 'Resrouce group $($rg.value) does not exist'
    New-AzResourceGroup -Name $rg -Location $location
}
else
{
    # ResourceGroup exist
    Write-Host 'Resrouce group $($rg.value) exists'
}

##NSG rules
Write-Host "Creating NSG rules..."
#Clients can access port 3389
$rdpRule = New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" `
   -Access Allow -Protocol * -Direction Inbound -Priority 100 `
   -SourceAddressPrefix 10.3.8.0/24 -SourcePortRange * `
   -DestinationAddressPrefix * -DestinationPortRange 3389 
    
#Clients can access port 22
$sshRule = New-AzNetworkSecurityRuleConfig -Name ssh-rule -Description "Allow SSH" `
   -Access Allow -Protocol * -Direction Inbound -Priority 101 `
   -SourceAddressPrefix 10.3.8.0/24 -SourcePortRange * `
   -DestinationAddressPrefix * -DestinationPortRange 22 

#Deny all traffic
$denyRule = New-AzNetworkSecurityRuleConfig -Name denyall-rule -Description "Deny all" `
   -Access Deny -Protocol * -Direction Inbound -Priority 200 `
   -SourceAddressPrefix * -SourcePortRange * `
   -DestinationAddressPrefix * -DestinationPortRange *
   
#Everyone can access port 443
$httpsRule = New-AzNetworkSecurityRuleConfig -Name https-rule -Description "Allow HTTPS" `
   -Access Allow -Protocol * -Direction Inbound -Priority 102 `
   -SourceAddressPrefix * -SourcePortRange * `
   -DestinationAddressPrefix * -DestinationPortRange 443
    
#Webserver can access port 1433
$sqlRule = New-AzNetworkSecurityRuleConfig -Name sql-rule -Description "Allow sql" `
   -Access Allow -Protocol * -Direction Inbound -Priority 103 `
   -SourceAddressPrefix 10.3.1.0/24 -SourcePortRange * `
   -DestinationAddressPrefix * -DestinationPortRange 1433



##Create NSG
Write-Host "Creating NSG..."
#Webserver can access sql, Client can access 22, 3389
$nsgDatabase = New-AzNetworkSecurityGroup -ResourceGroupName $rg `
  -Location $location -Name "NSG-Database" -SecurityRules $denyRule, $rdpRule, $sshRule, $sqlRule

#Everybody can access 443, Client can access 22, 3389
$nsgWebserver = New-AzNetworkSecurityGroup -ResourceGroupName $rg `
  -Location $location -Name "NSG-Webserver" -SecurityRules $denyRule, $rdpRule, $sshRule, $httpsRule

#Nobody can access client
$nsgClient = New-AzNetworkSecurityGroup -ResourceGroupName $rg `
  -Location $location -Name "NSG-Cient" -SecurityRules $denyRule

##Create subnet config
Write-Host "Creating subnet config..."
#Webserver subnet
$webserverSubnet = New-AzVirtualNetworkSubnetConfig -Name webserverSubnet `
    -AddressPrefix "10.3.1.0/24" -NetworkSecurityGroup $nsgWebserver

#Database subnet
$databaseSubnet = New-AzVirtualNetworkSubnetConfig -Name databaseSubnet `
    -AddressPrefix "10.3.3.0/24" -NetworkSecurityGroup $nsgDatabase

#cient subnet
$clientSubnet = New-AzVirtualNetworkSubnetConfig -Name clientSubnet `
    -AddressPrefix "10.3.8.0/24" -NetworkSecurityGroup $nsgClient

##Create virtual network
Write-Host "Creating virtual network..."
New-AzVirtualNetwork -Name $vnet -ResourceGroupName $rg `
    -Location $location -AddressPrefix "10.3.0.0/16" -Subnet $webserverSubnet, $databaseSubnet, $clientSubnet

    

$test = Get-AzVirtualNetwork -Name $vnet -ResourceGroupName $rg


# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzNetworkInterface `
  -Name "webserverNic" `
  -ResourceGroupName $rg `
  -Location $location `
  -SubnetId $test.Subnets[0].Id `
  -NetworkSecurityGroupId $nsgWebserver.Id

# Define a credential object
$securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

# Create a virtual machine configuration
$vmConfig = New-AzVMConfig `
  -VMName Webserver-VM `
  -VMSize "Standard_DS1_v2" | `
Set-AzVMOperatingSystem `
  -Linux `
  -ComputerName Webserver-VM `
  -Credential $cred `
  -DisablePasswordAuthentication | `
Set-AzVMSourceImage `
  -PublisherName "Canonical" `
  -Offer "UbuntuServer" `
  -Skus "18.04-LTS" `
  -Version "latest" | `
Add-AzVMNetworkInterface `
  -Id $nic.Id

# Configure the SSH key
$sshPublicKey = cat ~/.ssh/id_rsa.pub
Add-AzVMSshPublicKey `
  -VM $vmconfig `
  -KeyData $sshPublicKey `
  -Path "/home/dan/.ssh/authorized_keys"

New-AzVM `
  -ResourceGroupName $rg `
  -Location $location -VM $vmConfig

# ##Create VMs
# Write-Host "Creating virual machines..."
# #Webserver
# New-AzVm `
#     -ResourceGroupName "student08-OnPremise-cli2" `
#     -Name "Webserver" `
#     -Location $location `
#     -VirtualNetworkName $vnet `
#     -SubnetName  $webserverSubnet`
#     -SecurityGroupName $nsgWebserver `
#     -Credential $Credential
















Write-Host "Success!"





