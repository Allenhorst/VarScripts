Clear-Host
$newDeskId = "69"
$vcenter = "vcenter-dlg-prm"
$esxHost = "srv1148"

 Add-PSSnapin VMWare.VimAutomation.Core -ErrorAction:SilentlyContinue

Write-Host "Moving stand `"*-$newDeskId`" to pool..."
$server = Connect-VIServer -Server $vcenter -User paragon\prm_autotest_user -Password Ghbdtn123
$vmHost = Get-VMHost -Server $server -Name "$esxHost*"
function MoveToResourcePool{
	Param( $server, $vmHost, $vm, $resourcePath )
	foreach($tmpPoolName in $resourcePath.Split("\")){
		if(!$parentPool){ $parentPool = $vmHost }
		$tmpPool = Get-ResourcePool -Server $server -Location $parentPool -Name $tmpPoolName
		if(!$tmpPool){
			$tmpPool = New-ResourcePool -Server $server -Location $parentPool -Name $tmpPoolName
		}
		$parentPool = $tmpPool
	}
	Move-VM -VM $vm -Destination $tmpPool -RunAsync
}
$vmList = Get-VM -Name "*-$newDeskId" -Server $server -Location $vmHost
$vmList|%{
	$vmShortName = $_.Name.Replace("-$newDeskId","")
	$vmLocationTable = @{
		"PRM-AT-??" = "Desk-$newDeskId\Targets";
		"PRM-BT-??" = "Desk-$newDeskId\Targets";
		"PRM-CT-??" = "Desk-$newDeskId\Targets";
		"prm-domain" = "Desk-$newDeskId\Servers";
		"w???wpro??en" = "Desk-$newDeskId\Arms";
		"w???went??en" = "Desk-$newDeskId\Arms";
		"w???sstd??en" = "Desk-$newDeskId\Arms";
		"w???wbus??en" = "Desk-$newDeskId\Arms";
		"w???sweb??en" = "Desk-$newDeskId\Arms";
		"l131s64-0?" = "Desk-$newDeskId\NewWave";
		"w630s64-0?" = "Desk-$newDeskId\NewWave";
		"l131s64-src" = "Desk-$newDeskId\NewWave\Source";
		"w630s64-src" = "Desk-$newDeskId\NewWave\Source";
		"ta-*" = "Desk-$newDeskId"
	}
	$locationKey = $vmLocationTable.Keys|?{$vmShortName -like $_}
	$resourcePath = $vmLocationTable[$locationKey]
	Write-Host "Moving $_ to `"$resourcePath`"..."
	MoveToResourcePool -VM $_ -server $server -vmHost $vmHost -resourcePath $resourcePath
}