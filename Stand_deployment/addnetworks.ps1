function CreateNetwork
{
    Param
    ( 
        $networkName, 
        $server = $server, 
        [int] $numports = 256 
    )


    if(!$server)
    { 
        $server = $global:DefaultVIServer 
    }

    [string]$switchName = $networkName 
    if(!(Get-VirtualPortGroup -Name $networkName -ErrorAction:SilentlyContinue))
    {
        $newSwitch = New-VirtualSwitch -name $switchName -NumPorts:$numports
        $switch = Get-VirtualSwitch -name $switchName
        #add new network (virtualportgroup - vm network)
        Clear-Variable newNetwork -ErrorAction:SilentlyContinue
        [string]$netName = $networkName
        $newNetwork = new-virtualportgroup -name $netName -VirtualSwitch $switch -Confirm:$false
        if (!$newNetwork)
        {
            echo "Could not create network: $networkName"
            return $false
        }
        return $true
    }
    else
    {
        echo "$virtualnetwork_name already exists"
        return $true
    }

}

$server = Connect-VIServer sb023 -User root -Password lpc3TAWvbW
$listn = "ba-023-win-01,ba-023-win-03,ba-023-win-05"
$listnetworks = $listn.Split(",")

foreach ($networkName in $listnetworks){
    echo $networkName
    #echo "Try to create network: $networkName"
    CreateNetwork ($networkName)
}