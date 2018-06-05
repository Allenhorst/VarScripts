			Connect-VIServer -Server vcenter-spb-prm -User paragon\saakyan -Password nDds4fq2
			
			$h = Get-VMHost -Name "srv1002.paragon-software.com"
			
			$ds=$h|Get-Datastore
			#$s=$h|Get-Datastore *sb497:hdd1*
			
			foreach ($s in $ds)
			{
				#$s = $datasrore.Name
				$l=(ls $s.DatastoreBrowserPath)|sort
				$vmxList = $l|%{Get-Item -Path "$($_)\$($_.Name)*.vmx"}
				$vmxList|%{
					New-VM -Name ($_.PSParentPath.Split("\")[-1]) -VMHost $h -VMFilePath $_.DatastoreFullPath -RunAsync
				}
			}