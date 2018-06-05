$serv = Connect-VIServer srv1164 -User root -Password lpc3TAWvbW
$tas = "ta-base-1164-b1,ta-base-1164-b2,ta-base-1164-b4,ta-base-1164-b5,ta-base-1164-b6,ta-base-1164-b7"
$listta = $tas.Split(",")
    foreach ($ta in $listta) {
      echo "==========================================="
      echo $ta

      $winVM= Get-VM  -Server $serv -Name $ta
       
      $resPool = Get-ResourcePool -Server $serv -VM $winVM
      $allq9VM = Get-VM -Location $resPool | Sort-Object
      foreach ($vm in $allq9VM){
      	echo $vm.Name
      }
    }  
Disconnect-VIServer -Confirm:$false -Force:$true