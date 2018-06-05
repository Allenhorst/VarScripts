## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ## ##
##
## Remove VM Snapshot Script
## v0.1.2
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
    ## EDIT THIS PARAMETER: snapshot to remove.
    $snapshotToRemove = "Clear_NoUpdate",

    [String]
    ## EDIT THIS PARAMATER: list of VMs to remove the snapshot on.
    $my_machines = "PRM-AT-01,PRM-AT-02,PRM-BT-01,PRM-BT-03,PRM-BT-04,PRM-BT-05,PRM-BT-06,PRM-BT-10,PRM-BT-12,PRM-BT-13,PRM-BT-14,PRM-BT-15"
)

Add-PSSnapin VMware.VimAutomation.Core
Disconnect-VIServer * -Confirm:$false
Start-Sleep 2
Connect-VIServer -Server $esxHost -User $esxUserName -Password $esxPassword 
Start-Sleep 2
 
$suffix = "-$deskIdentifier"

function RemoveSnapshot ($vm, $snapname){
    $snap = Get-Snapshot -VM (Get-VM -Name $vm) -Name $snapname
    Remove-Snapshot -Snapshot $snap -confirm:$false
}

function RemoveSnapshotOnVMs($computers)
{
    foreach ($comp in $computers)
    {
        $vm = $comp + $suffix
        Write-Host "Start RemoveSnapshot on $vm"
        RemoveSnapshot $vm $snapshotToRemove
        Start-Sleep 2
    }
}

[string[]] $vmList = ($my_machines.Split(","))
RemoveSnapshotOnVMs $vmList
