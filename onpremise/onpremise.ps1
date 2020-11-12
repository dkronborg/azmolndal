$rg = "student08-OnPremise-cli"
$vnetName = "virtnet-onpremise-cli"
$location = "westeurope"
$nicWebserverName = "webserverNic"
$nicDatabaseName = "databaseNic"
$nicClientName = "clientNic"
#$VMLocalAdminUser = "LocalAdminUser"
#$VMLocalAdminSecurePassword = ConvertTo-SecureString "Password" -AsPlainText -Force
#$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

$rdpRuleName = "rdprule"
$sshRuleName = "sshrule"
$denyallRuleName = "denyallrule"
$httpsRuleName = "httpsrule"
$sqlRuleName = "sqlrule"

$nsgDatabaseName = "NSG-Database"
$nsgWebserverName = "NSG-Webserver"
$nsgClientName = "NSG-Cient"

$vmDatabaseName = "Database-VM"
$vmWebserverName = "Webserver-VM"
$vmClientName = "Client-VM"

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
else
{
    # ResourceGroup exist
    Write-Host 'Resrouce group exists'
}

##NSG rules
Write-Host "Creating NSG rules..."

#Clients can access port 3389
$rdpRule = New-AzNetworkSecurityRuleConfig -Name $rdpRuleName -Description "Allow RDP" `
   -Access Allow -Protocol * -Direction Inbound -Priority 100 `
   -SourceAddressPrefix 10.3.8.0/24 -SourcePortRange * `
   -DestinationAddressPrefix * -DestinationPortRange 3389 
    
#Clients can access port 22
$sshRule = New-AzNetworkSecurityRuleConfig -Name $sshRuleName -Description "Allow SSH" `
   -Access Allow -Protocol * -Direction Inbound -Priority 101 `
   -SourceAddressPrefix 10.3.8.0/24 -SourcePortRange * `
   -DestinationAddressPrefix * -DestinationPortRange 22 

#Deny all traffic
$denyRule = New-AzNetworkSecurityRuleConfig -Name $denyallRuleName -Description "Deny all" `
   -Access Deny -Protocol * -Direction Inbound -Priority 200 `
   -SourceAddressPrefix * -SourcePortRange * `
   -DestinationAddressPrefix * -DestinationPortRange *
   
#Everyone can access port 443
$httpsRule = New-AzNetworkSecurityRuleConfig -Name $httpsRuleName -Description "Allow HTTPS" `
   -Access Allow -Protocol * -Direction Inbound -Priority 102 `
   -SourceAddressPrefix * -SourcePortRange * `
   -DestinationAddressPrefix * -DestinationPortRange 443
    
#Webserver can access port 1433
$sqlRule = New-AzNetworkSecurityRuleConfig -Name $sqlRuleName -Description "Allow sql" `
   -Access Allow -Protocol * -Direction Inbound -Priority 103 `
   -SourceAddressPrefix 10.3.1.0/24 -SourcePortRange * `
   -DestinationAddressPrefix * -DestinationPortRange 1433



##Create NSG
Write-Host "Creating NSG..."

#Database
$nsgDatabase = Get-AzNetworkSecurityGroup -Name $nsgDatabaseName -ResourceGroupName $rg -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent)
{
    # NSG-Database doesn't exist
    #Webserver can access sql, Client can access 22, 3389
    $nsgDatabase = New-AzNetworkSecurityGroup -ResourceGroupName $rg `
    -Location $location -Name $nsgDatabaseName -SecurityRules $denyRule, $rdpRule, $sshRule, $sqlRule
}
#Webserver
$nsgWebserver = Get-AzNetworkSecurityGroup -Name $nsgWebserverName -ResourceGroupName $rg -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent)
{
    # NSG-Database doesn't exist
    #Everybody can access 443, Client can access 22, 3389
    $nsgWebserver = New-AzNetworkSecurityGroup -ResourceGroupName $rg `
    -Location $location -Name $nsgWebserverName -SecurityRules $denyRule, $rdpRule, $sshRule, $httpsRule
}
#Clients
$nsgClient = Get-AzNetworkSecurityGroup -Name $nsgClientName -ResourceGroupName $rg -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent)
{
    # NSG-Database doesn't exist
    #Nobody can access client
    $nsgClient = New-AzNetworkSecurityGroup -ResourceGroupName $rg `
    -Location $location -Name $nsgClientName -SecurityRules $denyRule
}


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
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rg -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent)
{
    $vnet =New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rg `
    -Location $location -AddressPrefix "10.3.0.0/16" -Subnet $webserverSubnet, $databaseSubnet, $clientSubnet
}




## Webserver VM
Get-AzVM -ResourceGroupName $rg -Name $vmWebserverName -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent) { # Create Webserver VM

  ## Create VM configuration
  # Create a virtual network card and associate with public IP address and NSG
  Write-Host "Creating virtual network interface..."
  $nic = Get-AzNetworkInterface -Name $nicWebserverName -ResourceGroupName $rg -ErrorVariable notPresent -ErrorAction SilentlyContinue
  if ($notPresent)
  {
    $nic = New-AzNetworkInterface `
    -Name $nicWebserverName `
    -ResourceGroupName $rg `
    -Location $location `
    -SubnetId $vnet.Subnets[0].Id `
    -NetworkSecurityGroupId $nsgWebserver.Id
  }
  # Define a credential object
  $securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
  $cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)
  # Create a virtual machine configuration
  $vmConfig = New-AzVMConfig `
    -VMName $vmWebserverName `
    -VMSize "Standard_B1s" | `
  Set-AzVMOperatingSystem `
    -Linux `
    -ComputerName $vmWebserverName `
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
  $sshPublicKey = Get-Content C:\Users\Dan\.ssh\id_rsa.pub
  Add-AzVMSshPublicKey `
    -VM $vmconfig `
    -KeyData $sshPublicKey `
    -Path "/home/azureuser/.ssh/authorized_keys"

  Write-Host "Creating VM..."
  New-AzVM `
  -ResourceGroupName $rg `
  -Location $location -VM $vmConfig
}



## Database VM
Get-AzVM -ResourceGroupName $rg -Name $vmDatabaseName -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent) { # Create Database VM

  ## Create VM configuration
  # Create a virtual network card and associate with public IP address and NSG
  Write-Host "Creating virtual network interface..."
  $nic = Get-AzNetworkInterface -Name $nicDatabaseName -ResourceGroupName $rg -ErrorVariable notPresent -ErrorAction SilentlyContinue
  if ($notPresent)
  {
    $nic = New-AzNetworkInterface `
    -Name $nicDatabaseName `
    -ResourceGroupName $rg `
    -Location $location `
    -SubnetId $vnet.Subnets[1].Id `
    -NetworkSecurityGroupId $nsgDatabase.Id
  }
  # Define a credential object
  $securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
  $cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)
  # Create a virtual machine configuration
  $vmConfig = New-AzVMConfig `
    -VMName $vmDatabaseName `
    -VMSize "Standard_B1s" | `
  Set-AzVMOperatingSystem `
    -Linux `
    -ComputerName $vmDatabaseName `
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
  $sshPublicKey = Get-Content C:\Users\Dan\.ssh\id_rsa.pub
  Add-AzVMSshPublicKey `
    -VM $vmconfig `
    -KeyData $sshPublicKey `
    -Path "/home/azureuser/.ssh/authorized_keys"

  Write-Host "Creating VM..."
  New-AzVM `
  -ResourceGroupName $rg `
  -Location $location -VM $vmConfig
}


## Client VM
Get-AzVM -ResourceGroupName $rg -Name $vmClientName -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent) { # Create Client VM

  ## Create VM configuration
  # Create a virtual network card and associate with public IP address and NSG
  Write-Host "Creating virtual network interface..."
  $nic = Get-AzNetworkInterface -Name $vmClientName -ResourceGroupName $rg -ErrorVariable notPresent -ErrorAction SilentlyContinue
  if ($notPresent)
  {
    $nic = New-AzNetworkInterface `
    -Name $nicClientName `
    -ResourceGroupName $rg `
    -Location $location `
    -SubnetId $vnet.Subnets[2].Id `
    -NetworkSecurityGroupId $nsgClient.Id
  }
  # Define a credential object
  $securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
  $cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)
  # Create a virtual machine configuration
  $vmConfig = New-AzVMConfig `
    -VMName $vmClientName `
    -VMSize "Standard_B1s" | `
  Set-AzVMOperatingSystem `
    -Linux `
    -ComputerName $vmClientName `
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
  $sshPublicKey = Get-Content C:\Users\Dan\.ssh\id_rsa.pub
  Add-AzVMSshPublicKey `
    -VM $vmconfig `
    -KeyData $sshPublicKey `
    -Path "/home/azureuser/.ssh/authorized_keys"
  Write-Host "Creating VM..."
  New-AzVM `
    -ResourceGroupName $rg `
    -Location $location -VM $vmConfig
}

Write-Host "Done"