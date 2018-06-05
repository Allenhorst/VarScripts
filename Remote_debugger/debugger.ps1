import .\UserRights.ps1

function Add-DebuggerUser  {
	net user Debugger Qwerty123 /add /EXPIRES:NEVER /y
	net user Debugger /passwordchg:no /y
	WMIC USERACCOUNT WHERE "Name='Debugger'" SET PasswordExpires=FALSE
	net localgroup Administrators Debugger /add /y
}

function Stop-Debugger2010  {
	Set-Service -Name "xxx" -Status stopped
	Set-Service -Name "xxx" - StartUpType Disabled

}

function Configure-Firewall  {
	$arch = $ENV:PROCESSOR_ARCHITECTURE
	if ($arch -match "AMD64")
	{
		New-NetFirewallRule -DisplayName = "MSVSMON_PRG_x86" -Program = "C:\Program Files\Microsoft Visual Studio 14.0\Common7\IDE\Remote Debugger\x86\msvsmon.exe" -Action Allow -Profile Any -Direction Outbound -Enabled True
		New-NetFirewallRule -DisplayName = "MSVSMON_PRG_x64" -Program = "C:\Program Files\Microsoft Visual Studio 14.0\Common7\IDE\Remote Debugger\x64\msvsmon.exe" -Action Allow -Profile Any -Direction Outbound -Enabled True
		New-NetFirewallRule -DisplayName = "MSVSMON_PRG_x86" -Program = "C:\Program Files\Microsoft Visual Studio 14.0\Common7\IDE\Remote Debugger\x86\msvsmon.exe" -Action Allow -Profile Any -Direction Inbound -Enabled True
		New-NetFirewallRule -DisplayName = "MSVSMON_PRG_x64" -Program = "C:\Program Files\Microsoft Visual Studio 14.0\Common7\IDE\Remote Debugger\x64\msvsmon.exe" -Action Allow -Profile Any -Direction Inbound -Enabled True
	}                                                                                                                                                                                                             
	else                                                                                                                                                                                                           
	{                                                                                                                                                                                                              
		New-NetFirewallRule -DisplayName = "MSVSMON_PRG_x86" -Program = "C:\Program Files\Microsoft Visual Studio 14.0\Common7\IDE\Remote Debugger\x86\msvsmon.exe" -Action Allow -Profile Any -Direction Outbound -Enabled True
		New-NetFirewallRule -DisplayName = "MSVSMON_PRG_x86" -Program = "C:\Program Files\Microsoft Visual Studio 14.0\Common7\IDE\Remote Debugger\x86\msvsmon.exe" -Action Allow -Profile Any -Direction Inbound -Enabled True
	}
	
	
	New-NetFirewallRule   -DisplayName "MSVSMON_PRG_135" -Protocol TCP  -LocalPort 135 -Profile Any -Direction Outbound  -Enabled True
	New-NetFirewallRule   -DisplayName "MSVSMON_PRG_137" -Protocol UDP  -LocalPort 137 -Profile Any -Direction Outbound  -Enabled True
	New-NetFirewallRule   -DisplayName "MSVSMON_PRG_138" -Protocol UDP  -LocalPort 138 -Profile Any -Direction Outbound  -Enabled True
	New-NetFirewallRule   -DisplayName "MSVSMON_PRG_139" -Protocol TCP  -LocalPort 139 -Profile Any -Direction Outbound  -Enabled True
	New-NetFirewallRule   -DisplayName "MSVSMON_PRG_445" -Protocol TCP  -LocalPort 445 -Profile Any -Direction Outbound  -Enabled True
	New-NetFirewallRule   -DisplayName "MSVSMON_PRG_500" -Protocol UDP  -LocalPort 500 -Profile Any -Direction Outbound  -Enabled True
	New-NetFirewallRule   -DisplayName "MSVSMON_PRG_4500" -Protocol UDP -LocalPort 4500 -Profile Any -Direction Outbound  -Enabled True
	New-NetFirewallRule   -DisplayName "MSVSMON_PRG_80"  -Protocol TCP  -LocalPort 80 -Profile Any -Direction Outbound  -Enabled True
	New-NetFirewallRule   -DisplayName "MSVSMON_PRG_3702" -Protocol UDP -LocalPort 3702 -Profile Any -Direction Outbound  -Enabled True
	New-NetFirewallRule   -DisplayName "MSVSMON_PRG_4020" -Protocol TCP  -LocalPort 4020 -Profile Any -Direction Outbound  -Enabled True
	New-NetFirewallRule   -DisplayName "MSVSMON_PRG_4020" -Protocol TCP -LocalPort 4020 -Profile Any -Direction Inbound  -Enabled True
	New-NetFirewallRule   -DisplayName "MSVSMON_PRG_4021" -Protocol TCP -LocalPort 4021 -Profile Any -Direction Outbound  -Enabled True
	New-NetFirewallRule   -DisplayName "MSVSMON_PRG_4021" -Protocol TCP -LocalPort 4021 -Profile Any -Direction Inbound  -Enabled True
	
}
function Configure-Service  {
$account=".\Debugger"
$password="Qwerty123"
$service="name='msvsmon140'"

$svc=gwmi win32_service -filter $service
$svc.StopService()
$svc.change($null,$null,$null,$null,$null,$null,$account,$password,$null,$null,$null)
$svc.StartService()



}

Add-DebuggerUser
Grant-UserRight "Debugger" SeServiceLogonRight
Configure-Service
Configure-Firewall