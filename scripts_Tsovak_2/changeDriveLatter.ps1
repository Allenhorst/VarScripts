param (
    [String]
    # Specify an identifier for new desk. Select a first unused numeric value in
    # http://prm-wiki.paragon-software.com/display/QA/Test+Infrastructure
    $deskIdentifier = "50",


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
    $esxHost = "srv1107.paragon-software.com",

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
 Add-PSSnapin VMware.VimAutomation.Core
$suffix = "-$deskIdentifier"



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
		Start-Sleep 20
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


function dns
(
$computers
)
	{	
	foreach ($comp in $computers)
	{
		$wait_shutdown = $true
        $vm=""
		$vm = $comp + $suffix
				
		Write-Host "Start Revert Snapshot $vm"
		RevertSnapshot $vm "50-700"
		Write-Host "Done Revert Snapshot $vm"
		
		Write-Host "Start VM $vm"
		VMStart $vm
		$t=false
		$script = "wmic nicconfig call SetDNSSuffixSearchOrder (prmgui.local,paragon-software.com)"       
		#$script = "sc config wuauserv start= disabled"     
		
		Write-Host "Start Invoke on VM $vm"
		Invoke-VMScript -ScriptType bat -ScriptText $script -VM $vm -GuestUser administrator -GuestPassword Qwerty123
		Start-Sleep 5
		Write-Host "Shut Down VM $vm"
		VMShutDown $vm
		
		Start-Sleep 25
		CreateSnapshot  $vm "Domain"
		
		
		}
}
	


#$my_machines = "w513wpro86en,w522sstd64en,w522sweb86en,w602sstd64en,w602sstd86en,w602wbus86en,w610sstd64en,w611went64en,w620sstd64en,w620went64en,w630sstd64en,w630wpro64en,w630wpro86en,prm-ct-01,prm-ct-02,prm-ct-03,prm-ct-04,prm-ct-05,prm-ct-06,prm-ct-08,prm-ct-12,prm-ct-13,prm-ct-14,prm-ct-15,prm-ct-16,prm-ct-17,prm-ct-18"
$my_machines = "w630sstd64en"





[string[]] $vmList = ($my_machines.Split(","))

 $t = false

 dns $vmList



	


