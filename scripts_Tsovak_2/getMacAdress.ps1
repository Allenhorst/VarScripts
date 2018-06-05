 param(
    [String]
    # Specify an identifier for new desk. Select a first unused numeric value in
    # http://prm-wiki.paragon-software.com/display/QA/Test+Infrastructure
    $deskIdentifier = "43",


    [String] $UserName = "paragon\autotester",
	
    [String] $Password = "asdF5hh",
	
    [String]
    # Specify a username for authenticating with the vCenter server.
    $viUserName = "paragon\autotester",
	
    [String]
    # Specify a password for authenticating with the vCenter server.
    $viPassword = "asdF5hh",

    [String]  $vCenter = "vcenter-dlg-hdm.paragon-software.com",
    
    [String]
    # Specify the IP address or the DNS name of the ESX host on which you 
    # want to configure new desk.
    $esxHost = "srv048.paragon-software.com",

    [String]
    # Specify a username for authenticating with the ESX-host.
    $esxUserName = "autotester",
	
    [String]
    # Specify a password for authenticating with the ESX-host.
    $esxPassword = "asdF5hh"
)
Disconnect-VIServer * -Confirm:$false
Start-Sleep 2
Connect-VIServer -Server $vCenter -User $viUserName -Password $viPassword 
 Start-Sleep 2
 Add-PSSnapin VMware.VimAutomation.Core
$suffix = "-$deskIdentifier"
$logLine = Get-Date -Format "yyyyMMdd_HHmmss"

function Write-Log{
    Param( $message )
	($message|Out-String).Split("`n")|?{$_ -ne ""}|%{
		Write-Host $message
		Out-File -FilePath "C:\get-mac-v2-'$logLine'.txt" -InputObject ($message)  -Append
	}
}


function getmac($vm)
{

	$res = ((Get-VM $vm).NetworkAdapters[0]).MacAddress
	Write-Log "$vm : $res"
	Write-Log ""
 }
 
 
 $tmp = (Get-VM -Name *) -split " "
 
 foreach ($comp in $tmp)
	{
	getmac($comp)
	}
	