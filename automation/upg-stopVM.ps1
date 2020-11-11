$TagName1 = "os"
$TagValue1 = "linux"
$TagName2 = "owner"
$TagValue2 = "student08"

$VM = Get-AzResource -Tag @{$TagName1 = $TagValue1 ; $TagName2 = $TagValue2} -ResourceType Microsoft.Compute/virtualMachines

Foreach ($vmId IN $VM.Id)
{
    Stop-AzVM -Id $vmId -Force
}
