$hosts = "sb1074.paragon-software.com","sb609.paragon-software.com","sb492.paragon-software.com","sb1043.paragon-software.com","sb1008.paragon-software.com","sb560.paragon-software.com","sb633.paragon-software.com","sb1005.paragon-software.com","srv377.paragon-software.com","srv043.paragon-software.com","sb617.paragon-software.com","sb562.paragon-software.com","srv1005.paragon-software.com","sb449.paragon-software.com","sb559.paragon-software.com","srv380.paragon-software.com","srv015.paragon-software.com","srv310.paragon-software.com","sb497.paragon-software.com","srv051.paragon-software.com","srv055.paragon-software.com","srv039.paragon-software.com"


$userpass = "asdF5hh"
$user  = "autotester"

foreach ($chost in $hosts){
    Write-Output $chost
    $conn = Connect-VIServer -Protocol https -Server $chost -User $user -Password $userpass 
    Write-Output $conn.Name
    Get-Datastore
    Get-Datastore | Get-View | Select-Object Name,@{N="VMFS version";E={$_.Info.Vmfs.Version}}
    Disconnect-VIServer -Confirm:$false -Force:$true
}