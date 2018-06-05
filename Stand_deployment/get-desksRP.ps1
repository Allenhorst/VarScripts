$serv = Connect-VIServer vcenter-msk-prm -User paragon\autotester -Password asdF5hh
$datacenters = "Personal,Shared"
$DCs = $datacenters.Split(",")
    foreach ($DC in $DCs) {
      echo "==========================================="
      echo $DC
      $DC_V = Get-Datacenter -Name $DC
      #$winVM= Get-VM  -Server $serv -Name $ta
       
      $resPools = Get-ResourcePool -Server $serv -Location $DC_V
      foreach( $resPool in $resPools) {
          if (($resPool.Name -match '(Desk-)..') ) {
              echo $resPool.Name
            }
          #echo $resPool.Name
      }
      
    }  
Disconnect-VIServer -Confirm:$false -Force:$true