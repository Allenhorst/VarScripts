#test modifing service properties
# script for installing last updates on each machine
param
(
[String] 
#Edit before run
#specify desk, on which you want to install lastest updates
$deskIdentifier = "83" ,

[String]
#Edit before run
# Specify the DNS name of the vCenter server on which you want to configure test desk.
$vCenter = "vcenter-obn-prm.paragon-software.com",

[String]
#Edit before run
 # Specify the DNS name of the ESX host on which you want to configure test desk.
$esxHost = "sb497.paragon-software.com",

[String]
# Specify a username for authenticating with the vCenter server.
$viUserName = "paragon\prm_autotest_user",

[String]
# Specify a password for authenticating with the vCenter server.
$viPassword = "Ghbdtn123",


[String]
# Specify a username for authenticating with the ESX-host.
$esxUserName = "autotester",

[String]
# Specify a password for authenticating with the ESX-host.
$esxPassword = "asdF5hh",

[String] 
#Edit before run
# Get snap name to revert on it and create child snap
$baseSnapshotName = "Base1",

[String]
#Edit before run
# machines list
#$machines = "w513wpro86en,w522sstd64en,w602wbus86en,w602sstd64en,w611went86en,w610sstd64en,w620went86en,w620went86en, w620sstd64en,w630wpro86en, w630sstd64en, w100went64en, w100sstd64en"
$machines = "w630sstd64en_test" 

)
#log path 
$logPath = "C:\updater"
# creds for GuestOS operations by local user (Windows)
$winuser = "Administrator"
$winpass = "Qwerty123"
$guestLogPath = "C:\updater"

#variable for guestOS script
$scriptFileName = "Get-WindowsUpdates.ps1"

#flag for checking, if winUpdate service startmode changed during updating
$startupChanged = $true 

# load modules of the script
function Get-ScriptDirectory (){
Split-Path ((Get-Variable MyInvocation -Scope 1).Value).MyCommand.Path
} 



function testServices($vm)
{
$path = Split-Path -parent $MyInvocation.MyCommand.Definition
	$script =".\Get-WindowsUpdates.ps1"
	$scriptname ="Get-WindowsUpdates.ps1"
    $setname = "wuauservmod.ps1"
	$encode="UTF8"
	$policy = 'Set-ExecutionPolicy Unrestricted -Force'
	$setserv = ".\wuauservmod.ps1 -change $True -revert $True -startupChanged $True"
	#VMware.InvokeVMScript -vmName $vm -scriptText $policy -guser $winuser  -gpass $winpass  -scriptType "PowerShell" 
	VMware.CustomInvokeVMScript -vmName $vm -scriptText $setserv  -workDirectory $guestLogPath  -scriptFileName $setname  -redirectOut $true   -encoding $encode -guser $winuser  -gpass $winpass  -isPSScript $true 


}
Add-PSSnapin VMware.VimAutomation.Core
Disconnect-VIServer * -Confirm:$false
Start-Sleep 2
Connect-VIServer -Server $esxHost -User $esxUserName -Password $esxPassword 
Start-Sleep 2
$CurrentDir = Get-ScriptDirectory
. "$CurrentDir\VMWareModule.ps1" 

testServices("w630sstd64en-83")