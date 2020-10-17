$rg = "student08-OnPremise-arm"
$location = "westeurope"

Write-Host("Start deployment")

Get-AzResourceGroup -Name $rg -ErrorVariable notPresent -ErrorAction SilentlyContinue
#Check if resource group exists, if not then create it
if ($notPresent)
{
    # ResourceGroup doesn't exist
    Write-Host 'Resrouce group does not exist'
    New-AzResourceGroup -Name $rg -Location $location
}


New-AzResourceGroupDeployment -ResourceGroupName $rg -TemplateFile .\onpremiseNSG.json

