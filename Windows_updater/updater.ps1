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
$machines = "w630sstd64en" 

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

# write log messages to log_file
function Write-Log
{
    Param
    (
        $message
    )

    $logL = Get-Date -Format "[yyyy.MM.dd HH:mm:ss]"
    $string = $logL + "  " +  $message
    Write-Host $string
    Out-File -FilePath "$logPath\logfile.txt" -InputObject ($string)  -Append
}

function Write-ErrorLog
{
    Param
    (
        $message
    )

    $msg = "[FAILED] " + $message
    Write-Log $msg
}


#Create snapshot on target machine with predefined name format
function CreateSnapshot ($vm){
		$Date = Get-Date -UFormat "%Y-%m -%d"
		$snapname = "Updates until  " + $Date
		New-Snapshot -Name $snapname -VM $vm 

}

#start target VM
function StartVm ($vm){
	$status = $false
	 Start-Sleep 5
    Start-VM -VM $vm
	while(!$status)
	{
        Start-Sleep 15
		$toolsStatus = (Get-VM -Name $vm | Get-View | Select-Object @{N="Name";E={$_.Name}},@{Name="ToolsStatus";E={$_.Guest.ToolsStatus}}).ToolsStatus
		$status = (($toolsStatus -ne "toolsNotRunning") -and ($toolsStatus -ne "toolsNotInstalled"))
		
	}
}

#install winUpdates on target VM, see get-windowsUpdates.ps1 for more information
function InstallUpdate ($vm){
	$path = Split-Path -parent $MyInvocation.MyCommand.Definition
	$script =".\Get-WindowsUpdates.ps1"
	$scriptname ="Get-WindowsUpdates.ps1"
	$encode="UTF8"
	$policy = 'Set-ExecutionPolicy Unrestricted -Force'
	$setserv = ".\wuauservmod.ps1 -change $True -revert $True -startupChanged $True"
	$setservname = "wuauservmod.ps1"
	VMware.InvokeVMScript -vmName $vm -scriptText $policy -guser $winuser  -gpass $winpass  -scriptType "PowerShell" 
	#VMware.CustomInvokeVMScript -vmName $vm -scriptText $setserv  -workDirectory $guestLogPath  -scriptFileName $setservname  -redirectOut $true   -encoding $encode -guser $winuser  -gpass $winpass  -isPSScript $true 
	VMware.CustomInvokeVMScript -vmName $vm -scriptText $script  -workDirectory $guestLogPath  -scriptFileName $scriptname  -redirectOut $true   -encoding $encode -guser $winuser  -gpass $winpass  -isPSScript $true 
		
}	


function RevertSnapshot 
{
	Param 
	(
	$vm,
	$snap
	)

	$snapshot = Get-Snapshot -VM $vm -Name $snap
	Set-VM -VM $vm -Snapshot $snapshot
}

function ShutdownVm($vm)
{
	Stop-VM -VM $vm -Confirm:$false 
    $vm_stopped = Get-VM -Server $esxHost -Name $vm
	$status = $false
	while(!$status)
	{
		if($vm_stopped.PowerState -eq "PoweredOff") 
		{
			$status = $true 
		}
		start-sleep 15
	}
}

function Update ($vmList)
{
	foreach ($vm1 in $vmList)
		{
			$vmName = $vm1 + "-$deskIdentifier"
			
			Write-Host "Reverting to Snapshot $baseSnapshotName on vm $vmName"
			RevertSnapshot $vmName $baseSnapshotName
			
			
			Write-Host "Starm VM $vmName"
			StartVm($vmName)
			
			
			Write-Host "Start InstallUpdate on $vmName"
			InstallUpdate($vmName)
		
			start-sleep 1
			
			Write-Host "Start ShutdownVm on $vmName"
			ShutdownVm($vmName)
		
			Write-Host "Start CreateSnapshot on $vmName"
			CreateSnapshot($vmName)
		}
	

}



Add-PSSnapin VMware.VimAutomation.Core
Disconnect-VIServer * -Confirm:$false
Start-Sleep 2
Connect-VIServer -Server $esxHost -User $esxUserName -Password $esxPassword 
Start-Sleep 2
$CurrentDir = Get-ScriptDirectory
. "$CurrentDir\VMWareModule.ps1" 


[String[]] $vmList = ($machines.Split(",")) 
Update ($vmList)
               
                  
                 
                  
                 
                 
                 