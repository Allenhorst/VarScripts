Connect-VIServer srv1114 -User root -Password lpc3TAWvbW
$allVMs=Get-VM
 
foreach ($vm in $allVMs) {
 if ($vm.ExtensionData.Runtime.ConnectionState -eq "orphaned") {$vm | Remove-VM -Confirm:$false}
}

Disconnect-VIServer -Confirm:$false -Force:$true