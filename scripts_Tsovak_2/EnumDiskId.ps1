$suffix="-xx"
$vms = @()
#$vms += "w513wpro86en"
$vms += "w100went64en"
$vms += "w100went86en"
<#$vms += "w602sstd64en"
$vms += "w602sstd86en"
$vms += "w602wbus86en"
$vms += "w610sstd64en"
$vms += "w611went64en"
$vms += "w620went64en"
#>
cls
$srv = Connect-VIServer srv042 -User "autotester" -Password "asdF5hh"
$vms|%{
	$VM = Get-VM ($_+$suffix)
	$hdds = $VM.Get_harddisks()
	foreach($hdd in $hdds){
		$hdd_id = $hdd.Id.Substring(($hdd.Id.IndexOf("/") + 1),($hdd.Id.Length - ($hdd.Id.IndexOf("/") + 1)))
		$vm.Name + "   " + $hdd_id
	}
}
Disconnect-VIServer $srv -Confirm:$false