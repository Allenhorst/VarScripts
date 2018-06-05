Connect-VIServer -Server vcenter-obn-prm -User paragon\autotester -Password asdF5hh
            
            $h = Get-VMHost -Name "srv055.paragon-software.com"      
            $ds=$h|Get-Datastore 
            #$s=$h|Get-Datastore *srv1148:ssd4* #если хотите только с одного диска добавлять в инвентарь         
            foreach ($s in $ds)
            {
                #$s = $datasrore.Name
                $l=(ls $s.DatastoreBrowserPath)|sort
                $vmxList = $l|%{Get-Item -Path "$($_)\$($_.Name)*.vmx"}
                foreach ($vmxitem in $vmxList) {
                    echo $vmxitem
                }
                $vmxList|%{
                    New-VM -Name ($_.PSParentPath.Split("\")[-1]) -VMHost $h -VMFilePath $_.DatastoreFullPath -RunAsync
                }
            }

			
			
		#	#New-ResourcePool -Location $h -Name source-srv1114
		#	$rrss = Get-ResourcePool -Location $h -Name "source-srv1114" 
		#   # New-ResourcePool -Location $h -Name "Desk-05"
		#	$rp = Get-ResourcePool -Location $h -Name "Desk-05-Production"
		#	$rps = "nolegacy.base" , "nolegacy.sql" , "nolegacy.externalservices" , "nolegacy.docker" , "nolegacy.hyperv"
        #   # New-ResourcePool -Location $rp -Name "nolegacy.base"
        #    $rpbase = Get-ResourcePool -Location $rp -Name "nolegacy.base"
        #   # New-ResourcePool -Location $rp -Name "nolegacy.sql"
        #    $rpsql = Get-ResourcePool -Location $rp -Name "nolegacy.sql"
        #   # New-ResourcePool -Location $rp -Name "nolegacy.externalservices"
        #    $rpexternalservices = Get-ResourcePool -Location $rp -Name "nolegacy.externalservices"
        #   # New-ResourcePool -Location $rp -Name "nolegacy.docker"
        #    $rpdocker = Get-ResourcePool -Location $rp -Name "nolegacy.docker"
        #   # New-ResourcePool -Location $rp -Name "nolegacy.hyperv"
        #    $rphyperv = Get-ResourcePool -Location $rp -Name "nolegacy.hyperv"
		#	
		#	
		#	
		#	$vms=$h|Get-VM
		#	foreach ($vm in $vms) 
		#		{
		#			if ($vm.Name -Match "source-srv1108") 
		#			{
		#				Move-VM -VM $vm -Destination $rrss
		#			}
		#			elseif  ($vm.Name -Like "docker" )
		#			{
		#				Move-VM -VM $vm -Destination $rpdocker
		#			}
		#			elseif ( $vm.Name -Like "rabbit" )
		#			{
		#				Move-VM -VM $vm -Destination $rpexternalservices
		#			}
		#			elseif ( $vm.Name -Match "hv" )
		#			{
		#				Move-VM -VM $vm -Destination $rphyperv
		#			}
		#			elseif  ($vm.Name -Match "sql" )
		#			{
		#				Move-VM -VM $vm -Destination $rpsql
		#			}
		#			elseif  ($vm.Name -Like "postgres" )
		#			{
		#				Move-VM -VM $vm -Destination $rpsql
		#			}
		#			else 
		#			{
		#				Move-VM -VM $vm -Destination $rpbase
		#			}
		#			
		#		}


Disconnect-VIServer -Confirm:$false -Force:$true



