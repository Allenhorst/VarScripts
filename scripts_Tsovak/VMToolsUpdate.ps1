## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##
##
## VMware Tools Update Script
## v0.2.2
## by  Tsovak Sahakyan
## and Valentin Dymchishin <Valentin.Dymchishin@paragon-software.com>
##
## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##

## Modify all parameters that are marked as "EDIT THIS PARAMETER" before running the script.

param (
    [String]
    # Specify the desk ID
    ## EDIT THIS PARAMETER: desk ID
    $deskIdentifier = "zz",

    [String]
    $UserName = "paragon\autotester",

    [String]
    $Password = "asdF5hh",

    [String]
    # Specify a username for authenticating with the vCenter server.
    $viUserName = "paragon\autotester",

    [String]
    # Specify a password for authenticating with the vCenter server.
    $viPassword = "asdF5hh",

    [String]
    ## EDIT THIS PARAMETER: vCenter
    $vCenter = "vcenter-dlg-prm.paragon-software.com",

    [String]
    ## EDIT THIS PARAMETER: ESX host
    # Specify the IP address or the DNS name of the ESX host on which you 
    # want to configure the desk.
    $esxHost = "srv1234.paragon-software.com",

    [String]
    # Specify a username for authenticating with the ESX-host.
    $esxUserName = "autotester",

    [String]
    # Specify a password for authenticating with the ESX-host.
    $esxPassword = "asdF5hh",

    [String]
    ## EDIT THIS PARAMETER: snapshot to update VMware Tools on
    $snapshotName = "Clear",

    [String]
    ## EDIT THIS PARAMETER: snapshot with old VMware Tools
    $snapshotOldName = "Clear_NoUpdate",

    [String]
    ## EDIT THIS PARAMATER: list of VMs to update VMware Tools on
    $my_machines = "PRM-AT-01,PRM-AT-02,PRM-BT-01,PRM-BT-03,PRM-BT-04,PRM-BT-05,PRM-BT-06,PRM-BT-10,PRM-BT-12,PRM-BT-13,PRM-BT-14,PRM-BT-15"
)

Add-PSSnapin VMware.VimAutomation.Core
Disconnect-VIServer * -Confirm:$false
Start-Sleep 2
Connect-VIServer -Server $esxHost -User $esxUserName -Password $esxPassword 
Start-Sleep 2
 
$suffix = "-$deskIdentifier"


function Write-Log{
    Param( $message )
 $type = "{0,12}" -f $type
 ($message|Out-String).Split("`n")|?{$_ -ne ""}|%{
  $logLine = "[$(Get-Date -Format "yyyyMMdd_HHmmss")]`t$type`t$($_<#.Trim()#>)"
  Write-Host $message
  Out-File -FilePath "C:\logs\ping.txt" -InputObject ($logLine + $message)  -Append
 }
}


function ConfigureVM_TimeSynchronize{
    Param( $vmName, $enable = $true, $server = $esxHost )
    if(!$server){ $server = $esxHost}
    $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    #$spec.changeVersion = $vm.ExtensionData.Config.ChangeVersion
    $spec.tools = New-Object VMWare.Vim.ToolsConfigInfo
    #$spec.tools.toolsUpgradePolicy = “upgradeAtPowerCycle”
    $spec.tools.syncTimeWithHost = $true
    # Apply the changes
    $vmView = Get-View -Id $vm.Id
    $task = $vmView.ReconfigVM_Task($spec)
    VMWare.WaitTask -vm $vm -task $task
}

function CreateSnapshot ($vm, $snapname){
	#$timoutTime = (Get-Date).AddSeconds($timeOutSeconds)
	#do{
	#	Start-Sleep -Seconds 5
		New-Snapshot -Name $snapname -VM $vm 
	#}while((!(Get-Snapshot -Name $snapname -VM $vm)) -or ((Get-Date) -lt $timoutTime))
}

function RevertSnapshot ($vm, $snapname){
	Set-VM -vm $vm -Snapshot $snapname -Confirm:$false
    Start-Sleep -Seconds 5
}

function RenameSnapshot ($vm, $snapname, $snapNewName){
    Start-Sleep 10
    $snap = Get-Snapshot -VM (Get-VM -Name $vm) -Name $snapname
    Start-Sleep 10
    Set-Snapshot -Snapshot $snap -Name $snapNewName
    Start-Sleep 10
}

function VMStart ($vm){
	$status = $false
	while(!$status)
	{
        Start-Sleep 15
    	start-vm -vm $vm
        Start-Sleep 15
		$toolsStatus = (Get-VM -Name $vm | Get-View | Select-Object @{N="Name";E={$_.Name}},@{Name="ToolsStatus";E={$_.Guest.ToolsStatus}}).ToolsStatus
		$status = (($toolsStatus -ne "toolsNotRunning") -and ($toolsStatus -ne "toolsNotInstalled"))
		Start-Sleep 15
	}
}

function waitTools($vm){
	$status = $false
	while(!$status)
	{
        Start-Sleep 15
    	$toolsStatus = (Get-VM -Name $vm | Get-View | Select-Object @{N="Name";E={$_.Name}},@{Name="ToolsStatus";E={$_.Guest.ToolsStatus}}).ToolsStatus
		$status = (($toolsStatus -ne "toolsNotRunning") -and ($toolsStatus -ne "toolsNotInstalled"))
		Start-Sleep 15
	}
}

function VMShutDown ($vm){
    shutdown-vmguest -VM $vm -Confirm:$false   
	$wait_shutdown = $false
    while($wait_shutdown){
        start-sleep 5
        $vm_powerstate = (Get-VM $vm).powerstate
        if($vm_powerstate -eq "poweredoff"){
            $wait_shutdown = $false
        }
		$toolsStatus = (Get-VM -Name $vm | Get-View | Select-Object @{N="Name";E={$_.Name}},@{Name="ToolsStatus";E={$_.Guest.ToolsStatus}}).ToolsStatus
		$status = (($toolsStatus -ne "toolsNotRunning") -and ($toolsStatus -ne "toolsNotInstalled"))
		if($status){Shutdown-VMGuest -VM $vm -Confirm:$false -ErrorAction:SilentlyContinue}
    }
}

function UpdateTools
{
    Param
    ( 
        $vmName,
        $timeout = 300,
        $guestUserName = $guser,
        $guestPassword = $gpass,
        $server = $server 
    )
    
    
    if(!$server)
    {
        $server = $global:DefaultVIServer
    }

    Clear-Variable vm -ErrorAction:SilentlyContinue
    $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop
    if ($vm.ExtensionData.Guest.ToolsStatus -eq "toolsOk")
    {
        Write-Log "VMWareTools Version on $vmName is Current, no update needed"
        return $true
    }
    else
    {
        $esxHostVersion = (Get-VMHost $server).Version    
        if ($esxHostVersion -like "5.0*")    
        {
            $t = VMware.InvokeVMScript $vmName "shutdown -r -t 600"    
        }
        
        $retryCNT = 6
        $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop        
        While (($retryCNT -gt 0) -and ($vm.ExtensionData.Guest.ToolsStatus -ne "toolsOk"))
        {
            Write-Log "Try update VMWareTools $vmName, Try # $retryCNT"
            Clear-Variable res -ErrorAction:SilentlyContinue
            Start-Sleep 15    
            $res = Update-Tools -VM $vm -NoReboot:$false -RunAsync -ErrorAction:SilentlyContinue
            Start-Sleep 15
            if ($res.State -eq "Running")
            {
                VMWare.WaitTask -vm $vm    -timeout 600
                
                Start-Sleep 15

                $rebootWatch = [System.Diagnostics.Stopwatch]::StartNew()
                $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop
                while( ($vm.ExtensionData.Guest.ToolsStatus -eq "guestToolsNotRunning") -and ($rebootWatch.Elapsed.TotalSeconds -lt $timeout) )
                {
                    Start-Sleep 2
                    $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop
                }
            }
            Start-Sleep 15
            $retryCNT--
        }
    
        $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop
        if (($vm.ExtensionData.Guest.ToolsStatus -ne "toolsOk") -or ($vm.ExtensionData.Guest.ToolsVersionStatus -ne "guestToolsCurrent"))
        {
            Write-ErrorLog "$vmName could not update VMWareTools(check manually)"
            return $false
        }
        else
        {
            Write-Log "VMWareTools Version on $vmName is Current, successfully updated"
            return $true        
        }
    }
}

##########################################################

## EDIT THIS PARAMETER: snapshot to update VMware Tools on
#$snapshotName = "Base-Prepared"
## EDIT THIS PARAMETER: snapshot with old VMware Tools
#$snapshotOldName = "Base-Prepared_NoUpdate"
## EDIT THIS PARAMATER: list of VMs to update VMware Tools on
#$my_machines = "w100went64en,w100went86en,w513wpro86en,w522sstd64en,w522sweb86en,w602sstd64en,w602sstd86en,w602wbus86en,w610sstd64en,w611went64en,w620sstd64en,w620went64en,w630sstd64en,w630went64en,w630went86en,w630sstd64c1,w630sstd64c2,w630s64-src,w630s64-01,w630s64-02,w630s64-03,prm-ct-01,prm-ct-02,prm-ct-04,prm-ct-05,prm-ct-06,prm-ct-09,prm-ct-13,prm-ct-14,prm-ct-15,prm-ct-16,prm-ct-18,prm-ct-19"

##########################################################

function Time
(
$computers
)
{	
	foreach ($comp in $computers)
	{
        $vm = ""
		$vm = $comp + $suffix
		
		Write-Host "Start Revert Snapshot $vm"
        RevertSnapshot $vm $snapshotName
		
		Write-Host "Start VM $vm"
		VMStart $vm
		Start-Sleep 5

		if (!(UpdateTools $vm)) { Write-Host "Cannot Update Tools on VM $vm"}

		Write-Host "Shut Down VM $vm"
		VMShutDown $vm
		Start-Sleep 2
				
		Write-Host "Start Rename Snapshot $vm"
        RenameSnapshot $vm $snapshotName $snapshotOldName
        Start-Sleep 15
		
        CreateSnapshot  $vm $snapshotName
		
		}
}
	
[String[]] $vmList = ($my_machines.Split(","))

$t = $false

Time $vmList
