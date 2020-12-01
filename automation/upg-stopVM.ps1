$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}


$TagName1 = "os"
$TagValue1 = "linux"
$TagName2 = "owner"
$TagValue2 = "student08"


$AllVM = Get-AzureRmResource -Tag @{$TagName1 = $TagValue1 ; $TagName2 = $TagValue2} -ResourceType Microsoft.Compute/virtualMachines

Write-Output $VM
Foreach ($vm IN $AllVM)
{
    Stop-AzureRmVM -Name $vm.Name -ResourceGroup $vm.ResourceGroupname -Force
}
