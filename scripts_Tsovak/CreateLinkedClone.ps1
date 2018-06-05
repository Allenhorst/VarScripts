$deskIdentifier = "76"
$viUserName = "paragon\autotester"
$viPassword = "asdF5hh"
$vCenter = "vcenter-dlg-hdm.paragon-software.com"

Add-PSSnapin VMWare.VimAutomation.Core

$viCredential = (New-Object Management.Automation.PSCredential `
	$viUserName, `
	(ConvertTo-SecureString $viPassword -AsPlainText -Force))

function Create-LinkedClone{
	Param
	(
		[string] $sourceVMName,
		[string] $sourceSnapshotName = "Base",
		[int] $cntVMs = 1
	)
	
	if ($cntVMs -ge 10)
	{
		Write-Error "Maximum number of clones eq 9"
	}
	
	$server = Connect-VIServer -Server $vc -Credential $viCredential -WarningAction SilentlyContinue
	$sourceVM = Get-VM -Name "$sourceVMName$suffix"
	$sourceSnapshot = Get-Snapshot -VM $sourceVM -Name $sourceSnapshotName
	$vmResourcePool = Get-ResourcePool -VM $sourceVM
	$vmDatastore = Get-Datastore -VM $sourceVM
  
	for($id=1; $id -le $cntVMs; $id++)
	{
		$cloneVMName = $sourceVMName.Substring(0, $sourceVMName.Length - 2) + "c" +  $id.ToString() + $suffix
		New-VM -Name $cloneVMName -VM $sourceVM -LinkedClone -ReferenceSnapshot $sourceSnapshot -ResourcePool $vmResourcePool -Datastore $vmDatastore
		New-Snapshot -Name $sourceSnapshot -VM $cloneVMName 
	}

	Disconnect-VIServer -Server $server -Confirm:$false
}

$vc = $vCenter
$suffix = "-$deskIdentifier"

Create-LinkedClone "w630sstd64en" -cntVMs 2