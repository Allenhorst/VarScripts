param(
    [String]
    # Specify an identifier for new desk. Select a first unused numeric value in
    # http://prm-wiki.paragon-software.com/display/QA/Test+Infrastructure
    $deskIdentifier = "04",


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
		Out-File -FilePath "C:\Domain_Log.txt" -InputObject ($logLine + $message)  -Append
	}
}

function netdom
(
$computers
)
	{	
	
	$dk = "prm-domain" + 	$suffix			
	RevertSnapshot $dk "Domain"
	Write-Host "Start VM $dk"
	VMStart $dk
	
	
	foreach ($comp in $computers)
	{
		$wait_shutdown = $true
        $vm=""
		$vm = $comp + $suffix
		
		
		Write-Host "Revert to Domain Snapshot $vm"
		RevertSnapshot $vm "Domain"
		Write-Host "Done Revert to Domain Snapshot $vm"
		
		Write-Host "Start VM $vm"
		VMStart $vm
		$t=false   
		$script = "netdom verify $VM /Domain:$domain /UserO:Administrator /PasswordO:Qwerty123"     
		
		Write-Host "Start Invoke on Domain-Controller for $vm"
		$resDomain = Invoke-VMScript -ScriptType bat -ScriptText $script -VM $dk -GuestUser administrator -GuestPassword Qwerty123
		Start-sleep 5
		
		$resDNS = checkDNS($vm)
		
		if ($resDomain.ExitCode -eq "0" -and $resDNS -eq "true")
			{
			Write-Host "$vm in Domain"
			RevertSnapshot $vm "Domain"
			}
			else 
			{
				if($resDomain.ExitCode -eq "0")
					{
					Write-Host "$vm is not in Domain"
					Write-Log "$vm is not in Domain"
					}
				if($resDNS -eq "true")
					{
					Write-Host "For $vm DNSDOMAIN is not currect"
					Write-Log "For $vm DNSDOMAIN is not currect"
					}
			}

		}
}

# Revert Domain-Controler to Domain snapshot
$dk = "prm-domain" + $suffix			
RevertSnapshot $dk "Domain"

$domain = "prmgui.test"

#List of machines that want to test
#$my_machines = "w513wpro86en,w522sstd64en,w522sweb86en,w602sstd64en,w602sstd86en,w602wbus86en,w610sstd64en,w611went64en,w620sstd64en,w620went64en,w630sstd64en,w630wpro64en,w630wpro86en,prm-ct-01,prm-ct-02,prm-ct-03,prm-ct-04,prm-ct-05,prm-ct-06,prm-ct-08,prm-ct-12,prm-ct-13,prm-ct-14,prm-ct-15,prm-ct-16,prm-ct-17,prm-ct-18"
$my_machines = "w513wpro86en,w522sstd64en,w522sweb86en,w602sstd64en,w602sstd86en,w602wbus86en,w610sstd64en,w611went64en,w620went64en,w630sstd64en,prm-ct-01,prm-ct-02,prm-ct-03,prm-ct-04,prm-ct-05,prm-ct-06,prm-ct-08,prm-ct-12,prm-ct-13,prm-ct-14,prm-ct-15,prm-ct-16,prm-ct-17"


[string[]] $vmList = ($my_machines.Split(","))
$t = false


# Run the functuion Netdom 
netdom $vmList


#List of machines that are not in the domain stored in the log file
# Open log file C:\Domain-Log.txt 
C:\Domain_Log.txt 




<#
путь к адаптеру внутренной сети
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Network\{4D36E972-E325-11CE-BFC1-08002BE10318}\{3B0540DA-BC6F-4D9F-AE40-5AAF95D7DADD}\Connection\ параметр Name = "Local Area Connection 2"
a для первой сети (внешней) {040B0DBF-49A2-4A9E-A6BA-55DF7294141B} 

 HKLM\System\CurrentControlSet\Services\Tcpip\Parameters\DNSRegisteredAdapters

 $s = wmic nicconfig get DNSDOMAIN
  $s[28]= prm.test
  
  #получаем мак второго внутренного адаптера
  $s = getmac
   (($s -split "{")[7] -split " ")[0]
   
 #установка  DNSDomain 
 wmic.exe nicconfig where "IPEnabled='true' And MacAddress='00:50:56:BF:7D:C9'" Call SetDNSDomain prm.test
   
    $s = wmic nicconfig get DNSDOMAIN
(($s -replace " {1,}" -split " ",9 -join "") -split "DNSDomain")[1] # prm.test
   
   
   
   
#>