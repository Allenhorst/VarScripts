Connect-VIServer -Server vcenter-dlg-prm -User paragon\autotester -Password asdF5hh
            
            $h = Get-VMHost -Name "srv1159.paragon-software.com"      
            $ds=$h|Get-Datastore 
            #$s=$h|Get-Datastore *srv1002:hdd1* #если хотите только с одного диска добавлять в инвентарь         
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

Disconnect-VIServer -Confirm:$false -Force:$true