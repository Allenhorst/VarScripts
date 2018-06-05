cls
$srv = Connect-VIServer srv1151 -User "autotester" -Password "asdF5hh"
$VM = Get-VM "w630sstd64en-a6"
$hdds = $VM.Get_harddisks()
foreach($hdd in $hdds){
    $hdd_id = $hdd.Id.Substring(($hdd.Id.IndexOf("/") + 1),($hdd.Id.Length - ($hdd.Id.IndexOf("/") + 1)))
    $vm.Name + "   " + $hdd_id
}
Disconnect-VIServer $srv -Confirm:$false