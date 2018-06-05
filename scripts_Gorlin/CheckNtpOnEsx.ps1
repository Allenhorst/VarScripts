$VCenterList = "vcenter-dlg-prm", "vcenter-fre-prm", "vcenter-obn-prm", "vcenter-msk-prm", "vcenter-spb-prm", "vdlg-vc60-prm"

foreach ($vcName in $VCenterList){
	echo ">> ============================================================"
	echo ">> $vcName"
	echo ">>"
	$vc = Connect-VIServer -Server $vcName

	$hostList = Get-VMHost
	(get-view -ViewType HostSystem -Property Name, ConfigManager.DateTimeSystem ) |
		Sort-Object -Property Name |%{
 			$v = get-view $_.ConfigManager.DateTimeSystem
 			$serv = Get-VMhost -Name $_.Name | Get-VmHostService | Where-Object {$_.key -eq "ntpd"} 

 			$_.Name + ":    " + $v.DateTimeInfo.NtpConfig.Server  + "    state:    " + $serv.Running  + "    policy:    " + $serv.Policy 
		}
		
	echo ">> ============================================================"
	Disconnect-VIServer -Confirm:$false -Force:$true
}

echo "FINISH"