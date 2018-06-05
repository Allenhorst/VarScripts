cls
Add-PSSnapin VMware.VimAutomation.Core
$srv = Connect-VIServer srv1114 -User "autotester" -Password "asdF5hh"
#$VM = Get-VM "w100went64en-05"
#$VM = Get-VM "prm-ct-13-05"
#$VM = Get-VM "w513wpro86en-05"
#$VM = Get-VM "w630sstd64en-05"
$VM = Get-VM "w100went64en-05"
$hdds = $VM.Get_harddisks()
foreach($hdd in $hdds){
    $hdd_id = $hdd.Id.Substring(($hdd.Id.IndexOf("/") + 1),($hdd.Id.Length - ($hdd.Id.IndexOf("/") + 1)))
    $vm.Name + "   " + $hdd_id
}
Disconnect-VIServer $srv -Confirm:$false