
function Create-VServer{
	Param
	(
		[string] $vsURL,
		[string] $vsUser = "autotester",
		[string] $vsPassword = "asdF5hh",
		[string] $vcUser = "paragon\prm_autotest_user",
		[string] $vcPassword = "Ghbdtn123",
		[string] $guestUser = "Administrator",
		[string] $guestPassword = "Qwerty123"
		
	)
	# Add object properties
	$VServer = New-Object PSObject -Property (
	@{
		'URL'=$null;
		'Name'=$null;
		'User'=$null;
		'Password'=$null;
		'vCenterUser'=$null;
		'vCenterPassword'=$null;
		'Connection'=$null;
		'DomainName'=$null;
		'MgmtVCenterIP'=$null;		
		'MgmtVCenterName'=$null;
		'GuestUser'=$null;
		'GuestPassword'=$null
	})
	
	# Add methods
	$VServer | Add-Member -MemberType ScriptMethod -Name Init -Value {	
		try{
			$this.Connection = Connect-VIServer -Server $this.URL -User $this.User -Password $this.Password -WarningAction:SilentlyContinue
			if(-not $this.Connection){throw}
            $this.DomainName = (Get-VMHostNetwork).DomainName
			$this.MgmtVCenterIP = (Get-View -ViewType HostSystem -Property Summary.ManagementServerIp | Select @{n="MgmtVCenterIP"; e={$_.Summary.ManagementServerIP}}).MgmtVCenterIP
			$this.MgmtVCenterName = ([System.Net.Dns]::GetHostByAddress($this.MgmtVCenterIP)).HostName
			$this.Disconnect()
			$this.Name = ($this.URL.split(".")[0] + "." +$this.DomainName)
		}
		catch{ $this.Log("Failed to init from ESX:  " + $this.URL) }
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name Log -Value {
		Param
		(
			[string] $logString
		)
		$time = (Get-Date -f o)
		$logString = "[" + $time + " VirtualLog:" + $this.URL.split(".")[0] + "] - " + $logString
		Write-host $logString
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name Connect -Value {
		if($global:DefaultVIServers.Count -gt 0){ $this.DisconnectAllServers() }
		$this.Connection = Connect-VIServer -Server $this.Name -User $this.User -Password $this.Password -WarningAction:SilentlyContinue		
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name ConnectVC -Value {
		if($global:DefaultVIServers.Count -gt 0){ $this.DisconnectAllServers() }
		$this.Connection = Connect-VIServer -Server $this.MgmtVCenterName -User $this.vCenterUser -Password $this.vCenterPassword -WarningAction:SilentlyContinue
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name Disconnect -Value {
		If($this.Connection){
			Disconnect-VIServer -Server $this.Connection -Confirm:$false -Force:$true
			$this.Connection = $null
		}
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name DisconnectAllServers -Value {
		Disconnect-VIServer -Confirm:$false -Force:$true -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue 
		$this.Connection = $null
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name GetDatastorePath -Value {
		param (
			$datastore_name
		)
		$this.ConnectVC()
		$ds = (get-datastore | where {$_.Name -eq "$datastore_name"})
		$datastore_path = $this.GetFullPath($ds)
		$this.Disconnect()
		return $datastore_path
	}

	$VServer | Add-Member -MemberType ScriptMethod -Name GetVMHostPath -Value {
		param (
				$vmhost_name
		)
		$this.ConnectVC()
		$vh = Get-VMHost -Name $this.Name
		$vmhost_path = $this.GetFullPath($vh)
		$this.Disconnect()
		return $vmhost_path
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name GetHostDCPath -Value {
		param (
				$vmhost_name
		)
		$this.ConnectVC()
		$vh = Get-Datacenter -VMHost (Get-VMHost -Name $this.Name)
		$vmhost_path = $this.GetFullPath($vh)
		$this.Disconnect()
		return $vmhost_path
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name GetFullPath -Value {
		param (
				$esx_item
		)
			
		$parent = $esx_item.parent
		if(-not $parent){
			$parent = $esx_item.parentfolder
		}
		
		$path = $esx_item.Name
		
		while ($parent){
			$path = $parent.Name + "/" + $path
			$parentfolder = $parent.parentfolder
			$parent = $parent.parent
			if(-not $parent){
			    $parent = $parentfolder
			}
		}
		$path = $path.replace("Datacenters/","").replace("Datencenter/","")
		return $path
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name GetVCPoolByAdress -Value {
		Param
		(
			$ResourcePoolAdress
		)
		$ResourcePoolAdress = $ResourcePoolAdress.Replace("/","\")
		$rps = $ResourcePoolAdress.Split("\")
		$pool_coll = Get-ResourcePool -Name ($rps[$rps.Count-1]) -Location (Get-VMHost -Name $this.Name) -ErrorAction SilentlyContinue
		$ResourcePoolServer = $this.Name
		if (!($pool_coll.Count -and ($pool_coll))){
			if (($this.GetFullPoolAdress($pool_coll)) -eq $ResourcePoolAdress){
					return $pool_coll
			}
			return $null
		}
		elseif($pool_coll.Count -gt 1){
			foreach($pool in $pool_coll)
			{
				if (($this.GetFullPoolAdress($pool)) -eq $ResourcePoolAdress){
					return $pool
				}
			}
			$this.Log("$ResourcePoolAdress on $ResourcePoolServer not founded")
			return $null
		}
		else{
			$this.Log("$ResourcePoolAdress on $ResourcePoolServer not founded")
			return $null
		}
	}
		
	$VServer | Add-Member -MemberType ScriptMethod -Name GetFullPoolAdress -Value {
		Param
		(
			$ResourcePool
		)
		$pool_parent = $ResourcePool
		$ResourcePoolAdress = $ResourcePool.Name
		while($pool_parent.Parent.Parent.GetType().Name -ne "VMHostWrapper")
		{
			$pool_parent = $pool_parent.Parent
			$ResourcePoolAdress = $pool_parent.Name + "\" + $ResourcePoolAdress
		} 
		return $ResourcePoolAdress
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name ClearVCPoolByAdress -Value {
		param 
		(
			[string] $ResourcePoolAdress
		)
		$this.ConnectVC()
		$pool = $this.GetVCPoolByAdress($ResourcePoolAdress)
		iF($pool){
			$VMs = (Get-VM -Location ($pool))
			If($VMs){
				$VMs | % {
					try { if ($_.PowerState -ne "PoweredOff") { Stop-VM -VM $_ -ErrorAction:SilentlyContinue -Confirm:$false | Out-Null } }
					catch{}# $this.Log("Errors occurred:`n" + $Error) }
				}
				Start-Sleep 2
				$VMs | % {
					try { if ($_){ Remove-VM -VM $_ -DeletePermanently:$true -Confirm:$false -ErrorAction:SilentlyContinue | Out-Null } }
					catch{}# $this.Log("Errors occurred:`n" + $Error) }
				}
			}else{ $this.Log("No VMs for cleaning is found") }
		}else{ $this.Log("Pool for cleaning with adress [$ResourcePoolAdress] not found") }
		$this.Disconnect()
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name InvokeVMScript -Value {
		param 
		(
			[String] $vmName,
			[String] $script,
			[String] $scriptType = "Bat",
			[int] $vmwareToolsTimeout = 300
		)
		$this.Connect()
        $this.Log("InvokeVMScript vmname $vmName scripttype $scriptType")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		$result = $null
		If($_vm){
			try{
				$result = Invoke-VMScript -VM $_vm -ScriptText $script -GuestUser $this.GuestUser -GuestPassword $this.GuestPassword `
					-ScriptType $scriptType -ToolsWaitSecs $vmwareToolsTimeout -WarningAction:SilentlyContinue
                $this.Log("InvokeVMScript vmname $vmName scripttype $scriptType was invoked")
				$this.Log("Exit code: " + $result.ExitCode)
				$this.Log("Script output: " + $result.ScriptOutput)
			}
			catch{ $this.Log("Errors occurred:`n" + $Error) }
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
		return $result
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name CopyFileToDatastore -Value {
		Param
		(
			[String]  $sourcePath,
			[String]  $datastoreName,
			[String]  $targetFolder,
			[Boolean] $recurse = $true
		)
		
		$Error.Clear()
		$isCopyToDatastoreFine = $false
		$this.Log("Try to copy [$sourcePath] to [$datastoreName $targetFolder]")
		if($datastoreName){
            if($targetFolder){
				$this.Connect()
				try{
					$datastore = Get-DataStore $datastoreName
					if($datastore.Name -eq $datastoreName){
						$isCopyToDatastoreFine = $true
						$psDrive = New-PSDrive -Location $datastore -Name ds -PSProvider VimDatastore -Root "\"
						if(-not (test-path "ds:\$targetFolder")){
							mkdir "ds:\$targetFolder" | Out-Null
						}
						if($recurse){
							Copy-DatastoreItem -Item $sourcePath -Destination "ds:\$targetFolder\" -Recurse -Force -Confirm:$false | Out-Null
						}
						else{
							Copy-DatastoreItem -Item $sourcePath -Destination "ds:\$targetFolder\" -Force -Confirm:$false  | Out-Null
						}
						Remove-PSDrive $psDrive -Confirm:$false -Force:$true | Out-Null
					}
				}
				catch{ $this.Log("Errors occurred:`n" + $Error) }
				$this.Disconnect()
			}
		}
		if($Error){	$isCopyToDatastoreFine = $false }
		$this.Log("isCopyToDatastoreFine = $isCopyToDatastoreFine")
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name DeleteDatastoreFolder -Value {
		Param
		(
			[string] $datastore_name,				
			[string] $folder_path = "Storages"
		)	
		$this.Log("Try to delete [$datastore_name] $folder_path")
		if($datastore_name -ne $null){
			if($folder_path -ne $null){
				$this.ConnectVC()
				try{
					$servInst = Get-View -Id ServiceInstance
					$fileMgr = Get-View -Id $servInst.Content.FileManager
					$dc = Get-View -VIObject (Get-Datastore -Name $datastore_name).Datacenter
					$this.Log("Delete folder $folder_path from datastore $datastore_name")
					# start the task
					$taskMoRef = $fileMgr.DeleteDatastoreFile_Task("[$datastore_name] $folder_path", $dc.MoRef)
					$task = Get-View -Id $taskMoRef
					# wait task
					while (@("running", "queued") -contains $task.Info.State) {
					    start-sleep 1
					    $task = Get-View -Id $taskMoRef
					}
					# check task on error
					$task = Get-View -Id $taskMoRef
					If (($task.Info.State) -eq "Error"){
						$this.Log("Error: " +$task.Info.Error.Fault)
					} else { $this.Log("Delete [$datastore_name] $folder_path complete successfully") }
				}
				catch{ $this.Log("Errors occurred:`n" + $Error) }
				$this.Disconnect()
			}
		}
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name GetVM -Value {
		Param
		(
			[string] $vmName
		)
		$this.Connect()
		$this.Log("Get VM $vmName")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			$this.Disconnect()
			return $_vm
		}
		$this.Log("VM $vmName not found")
		$this.Disconnect()
		return $null
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name DeleteVM -Value {
		Param
		(
			[string] $vmName
		)
		$this.Connect()
		$this.Log("Delete VM $vmName")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			try{
				Remove-VM -VM $_vm -DeletePermanently:$true -Confirm:$false | Out-Null
				$this.Log("VM $vmName deleted successful")
			}
			catch{ $this.Log("Errors occurred:`n" + $Error) }
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name StartVM -Value {
		Param
		(
			[string] $vmName
		)
		$this.Connect()
		$this.Log("Start VM $vmName")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			try{
				Start-VM -VM $_vm -Confirm:$false | Out-Null
				$this.Log("VM $vmName started successful")
			}
			catch{ $this.Log("Errors occurred:`n" + $Error) }
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name StopVM -Value {
		Param
		(
			[string] $vmName
		)
		$this.Connect()
		$this.Log("Stop VM $vmName")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			try{
				Stop-VM -VM $_vm -Confirm:$false | Out-Null
				$this.Log("VM $vmName stoped successful")
			}
			catch{ $this.Log("Errors occurred:`n" + $Error) }
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name SetVmMemorySizeMb -Value {
		Param
		(
			[string] $vmName,
			[int] $memoryMB
		)
		$this.Connect()
		$this.Log("Stop VM $vmName")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			try{
				$_vm = Set-VM -VM $_vm -MemoryMB $memoryMB -Confirm:$false
				$this.Log("VM $vmName stoped successful")
			}
			catch{ $this.Log("Errors occurred:`n" + $Error) }
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
		return $_vm
	}
		
	$VServer | Add-Member -MemberType ScriptMethod -Name ConnectCDtoVMFromDatastore -Value {
		Param
		(
			[string] $vmName,
			[string] $isoPath
		)
		$this.Connect()
		$this.Log("Connect CD to VM $vmName")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			try{
				$cd = Get-CDDrive -VM (Get-VM -Name $vmName)
				$cd = Set-CDDrive -CD $cd -ISOPath $isoPath -StartConnected:$true -Confirm:$false
				$this.Log("CD to VM $vmName connected successful")
			}
			catch{ $this.Log("Errors occurred:`n" + $Error) }
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
		return $cd
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name DisconnectCDfromVM -Value {
		Param
		(
			$cd
		)
		$this.Connect()
		$this.Log("Disconnect CD from VM $vmName")		
		try{
			$cd = Set-CDDrive -CD $cd -Connected:$false -StartConnected:$false -Confirm:$false
			$this.Log("Disconnect CD from VM $vmName successful")
		}
		catch{ $this.Log("Errors occurred:`n" + $Error) }
		$this.Disconnect()
		return $cd
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name ReplaceVMDisks -Value {
		Param
		(
			[string] $vmName,
            [int] $sizeFactor = 2
            
		)
		$this.Connect()
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			try{
                $_newHdds = @()
                #get disks
                $this.Log("Get disks for VM $vmName")
                $_hdds = [array](Get-HardDisk -VM $_vm)
                
                #create disks
                foreach($_hdd in $_hdds)
                {
                    $_controller = Get-ScsiController -HardDisk $_hdd
                    
                    $this.Log("create new disk")
                    if($_controller)
                    {
                        $_newHdd = (New-HardDisk -VM $_vm -CapacityKB ($sizeFactor*$_hdd.CapacityKB) -StorageFormat $_hdd.StorageFormat -Controller $_controller)
                    }
                    else
                    {
                        $this.Log("Warning! IDE disk will be replaced as SCSI disk")
                        $_newHdd = (New-HardDisk -VM $_vm -CapacityKB ($sizeFactor*$_hdd.CapacityKB) -StorageFormat $_hdd.StorageFormat)
                    }
                    $this.Log("new disk added. disk name is: " + $_newHdd.FileName)
                    $_newHdds += $_newHdd
                }
                #remove disks
                foreach($_hdd in $_hdds)
                {
                    $this.Log("Remove original disk: " + $_hdd.Filename)
                    if($_hdd){ Remove-HardDisk $_hdd -DeletePermanently:$true -Confirm:$false }
                    $this.Log("Remove disks successful")    
                }
                $this.Log("Replace disks for VM $vmName successful")
                $this.Disconnect()
				return $true
			}
			catch{ $this.Log("Errors occurred:`n" + $Error) }
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
		return $false
	}
    
    $VServer | Add-Member -MemberType ScriptMethod -Name CreateVMDisk -Value {
		Param
		(
			[string] $vmName,
			[int] $capacity,
            [string] $storageFormat = "Thin"
		)
		$this.Connect()
		$this.Log("Create disk for VM $vmName")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			try{
				$_hdd = New-HardDisk -VM $_vm -StorageFormat  $storageFormat -CapacityKB $capacity
                $this.Log("Create disk for VM $vmName successful, path: " + $_hdd.Filename)
			}
			catch{ $this.Log("Errors occurred:`n" + $Error) }
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
		return $_hdd
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name GetVMDisks -Value {
		Param
		(
			[string] $vmName
		)
		$this.Connect()
		$this.Log("Get disks for VM $vmName")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			try{
				$_hdds = [array](Get-HardDisk -VM $_vm)
				$this.Log("Get disks for VM $vmName successful")
			}
			catch{ $this.Log("Errors occurred:`n" + $Error) }
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
		return $_hdds
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name RemoveVMDisks -Value {
		Param
		(
			[string] $vmName
		)
		$this.Connect()
		$this.Log("Remove disks from VM $vmName")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			try{
				$_hdds = [array](Get-HardDisk -VM $_vm)
				$this.Log("Disk count: " + $_hdd.count)
				foreach($_hdd in $_hdds){
					$this.Log("Remove Disk: " + $_hdd.Filename)
                    if($_hdd){ Remove-HardDisk $_hdd -DeletePermanently:$true -Confirm:$false }
                }
				$this.Log("Remove disks from VM $vmName successful")
			}
			catch{ 
				$this.Log("Errors occurred:`n" + $Error)
				return $false
			}
		}
		else{ 
			$this.Log("VM $vmName not found")
			return $false
		}
		$this.Disconnect()
		return $true
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name RemoveDisks -Value {
		Param
		(
			$_hdds
		)
		$this.Connect()
		$this.Log("Remove disks")
		try{
			$this.Log("Disk count: " + $_hdd.count)
			foreach($_hdd in $_hdds){
				$this.Log("Remove Disk: " + $_hdd.Filename)
                if($_hdd){ Remove-HardDisk $_hdd -DeletePermanently:$true -Confirm:$false }
            }
			$this.Log("Remove disks successful")
		}
		catch{ 
			$this.Log("Errors occurred:`n" + $Error)
			return $false
		}
		return $true
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name ShutdownVM -Value {
		Param
		(
			[string] $vmName,
			[int] $timeout = 300,
			[bool] $stopIfTimeout = $true
		)
		$this.Connect()
		$this.Log("Shutdown VM $vmName")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			try{
				Shutdown-VMGuest -VM $_vm -Confirm:$false | Out-Null
				$wait_shutdown = $true				
				$timerStart = [System.Diagnostics.StopWatch]::StartNew()
				$waitLimit = [TimeSpan]::FromSeconds($timeout)
			    while(($wait_shutdown) -and ($timerStart.Elapsed -le $waitLimit)){
			        start-sleep 3
			        if((Get-VM -Name $vmName).powerstate -eq "poweredoff"){
			            $wait_shutdown = $false
			        }
			    }
				If(($stopIfTimeout) -and ((get-vm $vmName).powerstate -ne "poweredoff")){
					Stop-VM -VM $_vm -Confirm:$false | Out-Null
					$this.Log("Stop VM $vmName on timeout")
				}				
				$this.Log("VM $vmName turned off successful")
			}
			catch{ $this.Log("Errors occurred:`n" + $Error) }
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name WaitTools -Value {
		Param
		(
			[string] $vmName,
			[int] $timeout = 300,
			[int] $dealay = 3
		)
		$this.Connect()
		$timerStart = [System.Diagnostics.StopWatch]::StartNew()
		$waitLimit = [TimeSpan]::FromSeconds($timeout)
		$status = $false
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			while((!$status) -and ($timerStart.Elapsed -le $waitLimit))
			{
				$toolsStatus = ($_vm | Get-View | Select-Object @{N="Name";E={$_.Name}},@{Name="ToolsStatus";E={$_.Guest.ToolsStatus}}).ToolsStatus
				$status = (($toolsStatus -ne "toolsNotRunning") -and ($toolsStatus -ne "toolsNotInstalled"))
				Start-Sleep $dealay
			}
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
		return $status
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name RevertVM -Value {
		Param
		(
			[string] $vmName,
			[string] $snapshotName
		)
		$this.Connect()
		$this.Log("Revert VM $vmName to $snapName snapshot")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			try{
				$snapshot = Get-Snapshot -Name $snapshotName -VM $_vm
				$_vm = Set-VM -VM $_vm -snapshot $snapshot -Confirm:$false
				$this.Log("VM $vmName reverted successful")
				$this.Disconnect()
				return $true
			}
			catch{ $this.Log("Errors occurred:`n" + $Error) }
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
		return $false
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name CopyToGuest -Value {
		Param
		(
			[string] $vmName,
			[string] $source,
			[string] $destination
		)
		$this.Connect()
		$this.Log("Copy file [$source] to VM $vmName to folder [$destination]")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			if(Test-Path $source){
				try{
					Copy-VMGuestFile -Source $source -Destination $destination -VM $_vm -LocalToGuest `
						-GuestUser $this.GuestUser -GuestPassword $this.GuestPassword -Confirm:$false -Force:$true  | Out-Null
                    $this.Log("Copy file [$source] to VM $vmName to folder [$destination] is ok")
				}
				catch{ $this.Log("Errors occurred:`n" + $Error) }
			}
			else{ $this.Log("File [$source] for copying to VM $vmName not found") }
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name CopyFromGuest -Value {
		Param
		(
			[string] $vmName,
			[string] $source,
			[string] $destination
		)
		$this.Connect()
		$this.Log("Copy file [$source] from VM $vmName to folder [$destination]")
		$_vm = $null
		if(($vmName  -ne $null) -and ($vmName  -ne "") -and ($vmName  -ne " ")){ $_vm = (Get-VM -Name $vmName -ErrorAction:SilentlyContinue) }
		if($_vm){
			if(Test-Path $destination){
				try{
					Copy-VMGuestFile -Source $source -Destination $destination -VM $_vm -GuestToLocal `
						-GuestUser $this.GuestUser -GuestPassword $this.GuestPassword -Confirm:$false -Force:$true | Out-Null
				}
				catch{ $this.Log("Errors occurred:`n" + $Error) }
			}
			else{ $this.Log("Folder [$destination] for copying from VM $vmName not found") }
		}
		else{ $this.Log("VM $vmName not found") }
		$this.Disconnect()
	}
	
    $VServer | Add-Member -MemberType ScriptMethod -Name GetVMScreen -Value {
		Param
		(
			[String]  $vmName,
			[String]  $screenFolder
		)
		$this.ConnectVC()
        try
        {
            $vm = (Get-VM $vmName)
            $vmView = Get-View $vm
            $datastoreScreenPath = $vmView.CreateScreenshot()
            $datastoreName = ($datastoreScreenPath -split "]")[0]
            $datastoreName = $datastoreName.SubString(1)
            $datastore = Get-DataStore $datastoreName
            $psDrive = New-PSDrive -Location $datastore -Name ds -PSProvider VimDatastore -Root "\"
            $psDriveScreenPath = "ds:\" + ($datastoreScreenPath -split "] ")[1]
            $psDriveScreenPath = $psDriveScreenPath -replace "/","\"
            Copy-DatastoreItem -Item "$psDriveScreenPath" -Destination "$screenFolder" -Force -Confirm:$false | Out-Null
            if ("$psDriveScreenPath" -match '.png')
            {
                del $psDriveScreenPath
            }
            Remove-PSDrive $psDrive -Confirm:$false -Force:$true | Out-Null
        }
        catch{$this.Log("Errors occurred:`n" + $Error)}
        $this.Disconnect()
	}
    
	# Custom methods
	$VServer | Add-Member -MemberType ScriptMethod -Name AddSimpleIncrement -Value {
		Param
		(
			[string] $vmName,
			[int] $incrementNumber,
			[string[]] $discs = "c"
		)
        $this.Log("AddSimpleIncrement vmName $vmName, incrementNumber $incrementNumber")
		if($discs.count -gt 0){
			if(($discs.count -eq 1) -and ($discs[0] -eq "c")){
				$tryCount = 1
				$result = $false
				while(!($result) -and ($tryCount -le 3)){
					$_exitCode = ($this.InvokeVMScript($vmName,"IF NOT EXIST  %systemdrive%\backup\  md %systemdrive%\backup\")).ExitCode
					$result = $_exitCode -eq 0
				}
				$result = $false
				$tryCount = 1
				while(!($result) -and ($tryCount -le 3)){
					$_exitCode = ($this.InvokeVMScript($vmName, "echo increment$incrementNumber > %systemdrive%\backup\increment$incrementNumber.txt")).ExitCode
					$result = ($_exitCode -eq 0)
				}
			}
			else{
				foreach($disc in $discs){
					$result = $false
					$tryCount = 1
					while(!($result) -and ($tryCount -le 3)){
						$_exitCode = ($this.InvokeVMScript($vmName,"IF NOT EXIST  " + $disc + ":\backup\  md " + $disc + ":\backup\")).ExitCode
						$result = ($_exitCode -eq 0)
					}
					$result = $false
					$tryCount = 1
					while(!($result) -and ($tryCount -le 3)){
						$_exitCode = ($this.InvokeVMScript($vmName, "echo increment$incrementNumber > " + $disc + ":\backup\increment$incrementNumber.txt")).ExitCode
						$result = ($_exitCode -eq 0)
					}
				}
			}
			
		}
		else{ $this.Log("There is no discs for increment, disc array: " + [system.String]::Join(", ", $discs)) }		
		return $result
	}
	
	$VServer | Add-Member -MemberType ScriptMethod -Name TestSimpleIncrement -Value {
		Param
		(
			[string] $vmName,
			[int] $incrementNumber,
			[string[]] $discs = "c"
		)
		$this.Log("TestSimpleIncrement vmName $vmName, incrementNumber $incrementNumber")
        $result = $false
		if($discs.count -gt 0){
			if(($discs.count -eq 1) -and ($discs[0] -eq "c")){
                $script = 'type %systemdrive%\backup\increment' + "$incrementNumber" + '.txt'
				$tryCount = 1
				while(($_invokeResult.ExitCode -ne 0) -and ($tryCount -le 3)){
					$this.Log("TestSimpleIncrement vmName $vmName disk c attempt $tryCount")
					$_invokeResult = ($this.InvokeVMScript($vmName, $script))
					$tryCount++
				}
				$_output = $_invokeResult.ScriptOutput
				$_output = $_output -replace "`t|`n|`r",""
				$_output = $_output -replace " ",""
				$result = $_output -eq "increment$incrementNumber"
			}
			else{
				$result = $true
				foreach($disc in $discs){
					$script = "type " + $disc + ":\backup\increment$incrementNumber.txt"
					$tryCount = 1
					while(($_invokeResult.ExitCode -ne 0) -and ($tryCount -le 3)){
						$this.Log("TestSimpleIncrement vmName $vmName disk $disc attempt $tryCount")
						$_invokeResult = ($this.InvokeVMScript($vmName, $script))
						$tryCount++
					}
					$_output = $_invokeResult.ScriptOutput
					$_output = $_output -replace "`t|`n|`r",""
					$_output = $_output -replace " ",""
					$result = $result -and ($_output -eq "increment$incrementNumber")
				}
			}
		}
		else{ $this.Log("There is no discs for increment, disc array: " + [system.String]::Join(", ", $discs)) }		
		return $result
	}
		
	#============= Object constructor =============	
	$VServer.URL = $vsURL
	$VServer.User = $vsUser
	$VServer.Password = $vsPassword
	$VServer.vCenterUser = $vcUser
	$VServer.vCenterPassword = $vcPassword	
	$VServer.GuestUser = $guestUser
	$VServer.GuestPassword = $guestPassword
	$VServer.Init()	
	#============= Object constructor =============
	return $VServer
}
