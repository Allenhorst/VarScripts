# this file contains function , which is used to change behaviour of WinUpdate Service
function StartWinUpdateService
{
param
(
$change = $true,
$revert = $true,
$startupChanged = $true
)
	if($change) 
	{
		$serviceInf = Get-WmiObject -Class Win32_Service  -Filter "Name='wuauserv'" -Property StartMode
		$curState =  $serviceInf.StartMode
		if($curState -like "Disabled" )
			{
			
			Set-Service -Name wuauserv -StartupType Manual
			$startupChanged = $true 
			Start-Service -Name wuauserv
			}
		else 
			{
			$startupChanged = $false
			}	
	}
	if($revert)
	{
		if $startupChanged == $false 
			{
			
			}
		else
			{
			
			Stop-Service -Name wuauserv 
			Set-Service -Name wuauserv -StartupType Disabled
			}
	}	
}