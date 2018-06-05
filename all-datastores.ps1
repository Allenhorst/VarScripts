$vcenter = "vcenter-obn-prm"
$userpass = "asdF5hh"
$user  = "paragon\autotester"


$conn = Connect-VIServer -Protocol https -Server $vcenter -User $user -Password $userpass 
$hosts =  Get-VMHost -Server $conn

foreach ($chost in $hosts) {
	Write-Output $chost.Name

	 
}

Disconnect-VIServer -Confirm:$false -Force:$true