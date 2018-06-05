param (
    [String]
    # Specify an identifier for new desk. Select a first unused numeric value in
    # http://prm-wiki.paragon-software.com/display/QA/Test+Infrastructure
    $deskIdentifier = "13",


    [String] $UserName = "paragon\autotester",
	
    [String] $Password = "asdF5hh",
	
    [String]
    # Specify a username for authenticating with the vCenter server.
    $viUserName = "paragon\autotester",
	
    [String]
    # Specify a password for authenticating with the vCenter server.
    $viPassword = "asdF5hh",

    [String]  $vCenter = "vcenter-dlg-prm.paragon-software.com",
    
    [String]
    # Specify the IP address or the DNS name of the ESX host on which you 
    # want to configure new desk.
    $esxHost = "srv813.paragon-software.com",

    [String]
    # Specify a username for authenticating with the ESX-host.
    $esxUserName = "autotester",
	
    [String]
    # Specify a password for authenticating with the ESX-host.
    $esxPassword = "asdF5hh"
)

Add-PSSnapin VMware.VimAutomation.Core
Disconnect-VIServer * -Confirm:$false
Start-Sleep 2
Connect-VIServer -Server $esxHost -User $esxUserName -Password $esxPassword 
 Start-Sleep 2
 
$suffix = "-$deskIdentifier"

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
    $snap = Get-Snapshot -VM (Get-VM -Name $vm) -Name $snapname
    Set-Snapshot -Snapshot $snap -Name $snapNewName
    Start-Sleep 10
}

function VMStart ($vm){
	$status = $false
	while(!$status)
	{
    	start-vm -vm $vm
		$toolsStatus = (Get-VM -Name $vm | Get-View | Select-Object @{N="Name";E={$_.Name}},@{Name="ToolsStatus";E={$_.Guest.ToolsStatus}}).ToolsStatus
		$status = (($toolsStatus -ne "toolsNotRunning") -and ($toolsStatus -ne "toolsNotInstalled"))
		Start-Sleep 15
	}
}

function waitTools($vm){
	$status = $false
	while(!$status)
	{
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
            $res = Update-Tools -VM $vm -NoReboot:$false -RunAsync -ErrorAction:SilentlyContinue
            if ($res.State -eq "Running")
            {
                VMWare.WaitTask -vm $vm    -timeout 600
                
                Start-Sleep 15

                $rebootWatch = [System.Diagnostics.Stopwatch]::StartNew()
                $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop
                while( ($vm.ExtensionData.Guest.ToolsStatus -eq "guestToolsNotRunning") -and ($rebootWatch.Elapsed.TotalSeconds -lt $timeout) )
                {
                    Start-Sleep 1
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


	
function Time
(
$computers
)
	{	
	foreach ($comp in $computers)
	{
        $vm=""
		$vm = $comp + $suffix
		
		Write-Host "Start Revert Snapshot $vm"
		RevertSnapshot $vm "Clear"
		
		
		Write-Host "Start VM $vm"
		VMStart $vm
		Start-Sleep 5
		
		
		if (!(UpdateTools $vmName)) { Write-Host "Cannot Update Tools on VM $vm"}
		
		
		
		
		Write-Host "Shut Down VM $vm"
		VMShutDown $vm
		Start-Sleep 2
				
		Write-Host "Start Rename Snapshot $vm"
		RenameSnapshot $vm "Clear" "Clear_NoUpdate"
		
		CreateSnapshot  $vm "Clear"
		
		}
}
	


#$my_machines = "w513wpro86en,w522sstd64en,w522sweb86en,w602sstd64en,w602sstd86en,w602wbus86en,w610sstd64en,w611went64en,w620sstd64en,w620went64en,w630sstd64en,w630wpro64en,w630wpro86en,prm-ct-01,prm-ct-02,prm-ct-03,prm-ct-04,prm-ct-05,prm-ct-06,prm-ct-08,prm-ct-12,prm-ct-13,prm-ct-14,prm-ct-15,prm-ct-16,prm-ct-17,prm-ct-18"
$my_machines = "prm-ct-03,prm-ct-04,prm-ct-05,prm-ct-06,prm-ct-08,prm-ct-09,prm-ct-10,prm-ct-12,prm-ct-13,prm-ct-15,prm-ct-16,prm-ct-17,prm-ct-18"





[string[]] $vmList = ($my_machines.Split(","))

 $t = false

 Time $vmList



	


