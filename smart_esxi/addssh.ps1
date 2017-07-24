#name or ip of target esxi hosts
$hosts = "srv1114"

Foreach ($chost in $hosts) {
	$ip_host = Connect-ViServer -Server $chost -User autotester -Password asdF5hh
	
	$get_host = Get-VMHost -Server $ip_host 
	
	#enabling esxi shell+ssh
	Get-VMHostService -VMHost $get_host | Where-Object {$_.Key -eq "TSM"} | Set-VMHostService -policy "on" -Confirm:$false
	Get-VMHostService -VMHost $get_host | Where-Object {$_.Key -eq "TSM"} | Restart-VMHostService -Confirm:$false
	Get-VMHostService -VMHost $get_host | Where-Object {$_.Key -eq "TSM-SSH"} | Set-VMHostService -policy "on" -Confirm:$false
	Get-VMHostService -VMHost $get_host | Where-Object {$_.Key -eq "TSM-SSH"} | Restart-VMHostService -Confirm:$false
	#suppress warning
	Get-VMHost $get_host| Set-VmHostAdvancedConfiguration -Name UserVars.SuppressShellWarning -Value 1
	Disconnect-VIServer $chost -Confirm:$false


}
	
	

