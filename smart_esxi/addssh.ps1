#name or ip of target esxi hosts
$hosts = "srv1164.paragon-software.com,srv054.paragon-software.com,srv044.paragon-software.com,sb023.paragon-software.com"
$hostsList = $hosts.Split(",")

Foreach ($chost in $hostsList) {
	$ip_host = Connect-ViServer -Server $chost -User root -Password Ghbdtn123
	
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
	
	

