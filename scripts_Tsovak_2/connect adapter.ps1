param(
    [String]
    # Specify an identifier for new desk. Select a first unused numeric value in
    # http://prm-wiki.paragon-software.com/display/QA/Test+Infrastructure
    $deskIdentifier = "25",


    [String] $UserName = "paragon\autotester",
	
    [String] $Password = "asdF5hh",
	
    [String]
    # Specify a username for authenticating with the vCenter server.
    $viUserName = "paragon\autotester",
	
    [String]
    # Specify a password for authenticating with the vCenter server.
    $viPassword = "asdF5hh",

    [String]  $vCenter = "vcenter-spb-prm.paragon-software.com",
    
    [String]
    # Specify the IP address or the DNS name of the ESX host on which you 
    # want to configure new desk.
    $esxHost = "srv1002.paragon-software.com",

    [String]
    # Specify a username for authenticating with the ESX-host.
    $esxUserName = "autotester",
	
    [String]
    # Specify a password for authenticating with the ESX-host.
    $esxPassword = "asdF5hh"
)
Disconnect-VIServer * -Confirm:$false
Start-Sleep 2
Connect-VIServer -Server $esxHost -User $esxUserName -Password $esxPassword 
 Start-Sleep 2
 Add-PSSnapin VMware.VimAutomation.Core
$suffix = "-$deskIdentifier"



function checkDNS ($computer)
{
	$script = '(((wmic nicconfig get DNSDOMAIN) -replace " {1,}" -split " ",9 -join "") -split "DNSDomain")[1]'
		
		Write-Host "Start Invoke on Domain-Controller for $vm"
		$res = Invoke-VMScript  -ScriptText $script -VM $computer -GuestUser administrator -GuestPassword Qwerty123
		Start-sleep 5
		if ( [string] ($res -split "s")[0] -eq "prm.te") 
			{	return $true	}
			else {	return $false	}

} 

function ConnectNetworkAdapter{
	Param
	(
		[string] $vm_name,
		[string] $virtualnetwork_name,
        [string] $vcenter
		
	)
	$time = 0
	#adding new network adamter
	$network_adapter = (Get-NetworkAdapter -vm $vm_name -Server $vcenter | where {$_.NetworkName -like $virtualnetwork_name})
	$mac_addr = [string]$network_adapter.MacAddress
    
    Set-NetworkAdapter -NetworkAdapter $network_adapter -StartConnected $true -Confirm:$false
    if((Get-VM $vm_name).powerstate -eq "poweredon"){
        Set-NetworkAdapter -NetworkAdapter $network_adapter -Connected $true -Confirm:$false
    }

	#returning mac of current adapter
	Clear-Host
	Return $mac_addr
}

function RevertSnapshot ($vm, $snapname){
	Set-VM -vm $vm -Snapshot $snapname -Confirm:$false
    Start-Sleep -Seconds 5
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
function Write-Log{
    Param( $message )
	$type = "{0,12}" -f $type
	($message|Out-String).Split("`n")|?{$_ -ne ""}|%{
		$logLine = "[$(Get-Date -Format "yyyyMMdd_HHmmss")]`t$type`t$($_<#.Trim()#>)"
		Write-Host $message
		Out-File -FilePath "C:\Domain_Log43.txt" -InputObject ($logLine + $message)  -Append
	}
}

function RenameSnapshot ($vm, $snapname, $snapNewName){
    $snap = Get-Snapshot -VM (Get-VM -Name $vm) -Name $snapname
    Set-Snapshot -Snapshot $snap -Name $snapNewName
    Start-Sleep 10
}

function CreateSnapshot ($vm, $snapname){
	#$timoutTime = (Get-Date).AddSeconds($timeOutSeconds)
	#do{
	#	Start-Sleep -Seconds 5
		New-Snapshot -Name $snapname -VM $vm 
	#}while((!(Get-Snapshot -Name $snapname -VM $vm)) -or ((Get-Date) -lt $timoutTime))
}


function netdom
(
$computers
)
	{	
	
	
	foreach ($comp in $computers)
	{
		$wait_shutdown = $true
        $vm=""
		$vm = $comp + $suffix
		
		
		Write-Host "Revert to Domain Snapshot $vm"
		RevertSnapshot $vm "Domain"
		Write-Host "Done Revert to Domain Snapshot $vm"
		
		
		$t=false   

		$virtualnetwork_name = "Network adapter 1"
		Write-Host "Connect Network Adapter for $vm"
		$res = Get-VM $vm | Get-NetworkAdapter | Set-NetworkAdapter -StartConnected:$true -Confirm:$false
		Write-Host "$res"
        Start-sleep 10
		
		RenameSnapshot $vm "Domain" "Domain_adapter"
        Start-sleep 3
		CreateSnapshot $vm "Domain"
}
}
# Revert Domain-Controler to Domain snapshot


#List of machines that want to test
#$my_machines = "w513wpro86en,w522sstd64en,w522sweb86en,w602sstd64en,w602sstd86en,w602wbus86en,w610sstd64en,w611went64en,w620sstd64en,w620went64en,w630sstd64en,w630wpro64en,w630wpro86en,prm-ct-01,prm-ct-02,prm-ct-03,prm-ct-04,prm-ct-05,prm-ct-06,prm-ct-08,prm-ct-12,prm-ct-13,prm-ct-14,prm-ct-15,prm-ct-16,prm-ct-17,prm-ct-18"
$my_machines = "w513wpro86en,w522sstd64en,w522sweb86en,w602sstd64en,w602sstd86en,w602wbus86en,w610sstd64en,w611went64en,w620sstd64en,w620went64en,w630sstd64en,w630wpro64en,w630wpro86en,prm-ct-01,prm-ct-02,prm-ct-03,prm-ct-04,prm-ct-05,prm-ct-06,prm-ct-08,prm-ct-12,prm-ct-13,prm-ct-14,prm-ct-15,prm-ct-16,prm-ct-17"


[string[]] $vmList = ($my_machines.Split(","))
$t = false


# Run the functuion Netdom 
netdom $vmList


#List of machines that are not in the domain stored in the log file
# Open log file C:\Domain-Log.txt 
C:\Domain_Log43.txt 
