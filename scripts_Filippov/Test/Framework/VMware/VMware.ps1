# Initiate Vmware VimAutomation (using WindowsBase.ProgramFiles)
function VMware.Init(){
	if (((Get-PSSnapin -Name "VMware.VimAutomation.Core" -ErrorAction SilentlyContinue) -eq $null ) -and ((Get-PSSnapin -registered -Name "VMware.VimAutomation.Core") -ne $null)){
		Write-Host "Adding VMware vSphere PowerCLI" -ForegroundColor Green
		Add-PSSnapin -name VMware.VimAutomation.Core
		$ProgramFilesx86 = WindowsBase.ProgramFiles
		."$ProgramFilesx86\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-VIToolkitEnvironment.ps1"
		if ($error.count -eq 1){
			if($error[0] -match "No Windows PowerShell snap-ins matching the pattern"){
				$error.clear()
			}
		}
	}
}


#new vmware framework
."$frameworkDir\VMware\VSObj.ps1"

function VMware.get_false(){return, $false}
function VMware.get_true(){return, $true}

function Invoke-QaVmScript{
	Param (
			[String] $vmName,
			[String] $script,
			[String] $scriptType = "Powershell",
			
			[String] $vmLogin = "Administrator",
			[String] $vmPassword = "Qwerty123",
			
			[String] $vcenter,
			[String] $vcenterLogin ="paragon\prm_autotest_user",
			[String] $vcenterPassword = "Ghbdtn123",
			
			[String] $esxLogin = "autotester",
			[String] $esxPassword = "asdF5hh"
	)
	
	WindowsBase.Log ""
	WindowsBase.Log "DefaultViServers list before Invoke-QaVmScript:"
	WindowsBase.Log $global:DefaultViServers
	WindowsBase.Log ""
	
	#get VCenter Connection State
	$isVCenterConnected = $false
	if (($global:DefaultViServer).Name -eq $vcenter){
		$vcenterServer = $global:DefaultViServer
		$isVCenterConnected = $true
	}
	WindowsBase.Log "is $vcenter connected = $isVCenterConnected"
	
	#connect to vcenter
	if (-not $isVCenterConnected){
		WindowsBase.Log "Connect to $vcenter"
		$vcenterServer = Connect-ViServer $vcenter -user $vcenterLogin -password $vcenterPassword
		
		WindowsBase.Log ""
		WindowsBase.Log "DefaultViServers list:"
		WindowsBase.Log $global:DefaultViServers
		WindowsBase.Log ""
	}
	
	#get vm
	$vm = Get-VM -name $vmName
	
	#run script
	if($vm.vmHost.Version -ge 5){
		WindowsBase.Log "Invoke-VMScript for $vmName. login = $vmLogin password = $vmPassword"
		$check = (Invoke-VMScript -VM (Get-VM -name $vmName) -ScriptText $script -ScriptType $scriptType -GuestUser $vmLogin -GuestPassword $vmPassword)
		if (-not $isVCenterConnected){
			WindowsBase.Log "Disconnect $vcenter"
			Disconnect-ViServer $vcenterServer -force -confirm:$false
			WindowsBase.Log ""
			WindowsBase.Log "DefaultViServers list:"
			WindowsBase.Log $global:DefaultViServers
			WindowsBase.Log ""
		}
	}
	else{
		#disconnect vcenter
		WindowsBase.Log "Disconnect $vcenter"
		Disconnect-ViServer $vcenterServer -force -confirm:$false
		WindowsBase.Log ""
		WindowsBase.Log "DefaultViServers list:"
		WindowsBase.Log $global:DefaultViServers
		WindowsBase.Log ""
		#connect esx
		WindowsBase.Log ("Connect " + $vm.vmHost.Name)
		$esxServer = Connect-ViServer $vm.vmHost.Name -user $esxLogin -password $esxPassword
		WindowsBase.Log ""
		WindowsBase.Log "DefaultViServers list:"
		WindowsBase.Log $global:DefaultViServers
		WindowsBase.Log ""
		#run script
		WindowsBase.Log "Invoke-VMScript for $vmName"
		$check = (Invoke-VMScript -VM $vmName -ScriptText $script -ScriptType $scriptType -GuestUser $vmLogin -GuestPassword $vmPassword)
		#disconnect esx
		WindowsBase.Log ("Disconnect " + $vm.vmHost.Name)
		Disconnect-ViServer $esxServer -force -confirm:$false
		WindowsBase.Log ""
		WindowsBase.Log "DefaultViServers list:"
		WindowsBase.Log $global:DefaultViServers
		WindowsBase.Log ""
		#connect vcenter
		if($isVCenterConnected){
			WindowsBase.Log "Connect to $vcenter"
			$vcenterServer = Connect-ViServer $vcenter -user $vcenterLogin -password $vcenterPassword
			WindowsBase.Log ""
			WindowsBase.Log "DefaultViServers list:"
			WindowsBase.Log $global:DefaultViServers
			WindowsBase.Log ""
		}
	}
	WindowsBase.Log ""
	WindowsBase.Log "DefaultViServers list after Invoke-QaVmScript:"
	WindowsBase.Log $global:DefaultViServers
	WindowsBase.Log ""
	
	WindowsBase.Log $check
	return $check
}

function Copy-QaFileToDatastore{
	<#
		.SYNOPSIS
			Copy file to datastore
		.Description
			Copy file to datastore
		.Parameter sourcePath
			Path to source file
		.Parameter datastoreName	
			Datastore name
		.Parameter targetFolder
			Target folder on the datastore
		.Parameter recurse
			Recurse = $true by default
		.Parameter vcenter
			VCenter name = vcenter-msk-prm by default
		.Parameter vcenterLogin
			VCenter login = login for vcenter-msk-prm by default
		.Parameter vcenterPassword
			VCenter password = password for vcenter-msk-prm by default
		.Parameter isConnectToVcenter
			isConnectToVcenter = $true by default
		.Example
			Copy-QaFileToDatastore -sourcePath "c:\tmp\1.txt" -datastoreName "sb401:hdd1" -targetFolder "temp"
	#>
	Param (
			[String]  $sourcePath,
			
			[String]  $datastoreName,
			[String]  $targetFolder,
			[Boolean] $recurse = $true,
			
			[String]  $vcenter = "vcenter-msk-prm",
			[String]  $vcenterLogin ="paragon\prm_autotest_user",
			[String]  $vcenterPassword = "Ghbdtn123",
			[Boolean] $isConnectToVcenter = $true
	)
	
	if($Error){
		$Error.Clear()
	}
	
	$isCopyToDatastoreFine = $false
	
	if($datastoreName){
		if($targetFolder){
			if($isConnectToVcenter){
				$server = Connect-ViServer $vcenter -user $vcenterLogin -password $vcenterPassword
			}
			$datastore = Get-DataStore $datastoreName
			if($datastore.Name -eq $datastoreName){
				$isCopyToDatastoreFine = $true

				$psDrive = New-PSDrive -Location $datastore -Name ds -PSProvider VimDatastore -Root "\"
				if(-not (test-path "ds:\$targetFolder")){
					mkdir "ds:\$targetFolder"
				}
				if($recurse){
					Copy-DatastoreItem -Item $sourcePath -Destination "ds:\$targetFolder\" -Recurse -Force -Confirm:$false
				}
				else{
					Copy-DatastoreItem -Item $sourcePath -Destination "ds:\$targetFolder\" -Force -Confirm:$false
				}
				Remove-PSDrive $psDrive
				if($Error){
					$isCopyToDatastoreFine = $false
				}
			}
			if($isConnectToVcenter -eq $true){
				Disconnect-ViServer $server -Force -Confirm:$false
			}
		}
	}
	Write-Host "isCopyToDatastoreFine = $isCopyToDatastoreFine"
}

function VMware.DeleteVM($vm_Name, $esx, $user, $password ){
	VMware.RunCommand "Remove-VM  -DeleteFromDisk -VM $vm_Name -confirm:(VMware.get_false)" $esx $user $password
}

function VMware.DeleteDatastoreFolder{
	param (
			$datastore_name,
			
			$folder_path = "Storages",			
			$vcenter = "vcenter-msk-prm",
			$vcenter_user ="paragon\prm_autotest_user",
			$vcenter_pass = "Ghbdtn123"
	)	
	Write-Host "Try to delete [$datastore_name] $folder_path complete successfully"
	if($datastore_name -ne $null){
		if($folder_path -ne $null){			
			<#
			try{
				$_c_h = get-vmhost -ErrorAction SilentlyContinue
				Disconnect-VIServer -Server * -Force
			}
			catch{}			
			#>			
			$server = connect-viserver $vcenter -user $vcenter_user -password $vcenter_pass
			$servInst = Get-View -Id ServiceInstance
			$fileMgr = Get-View -Id $servInst.Content.FileManager
			$dc = Get-View -VIObject (Get-Datastore -Name $datastore_name).Datacenter
			Write-Host "Delete folder $folder_path from datastore $datastore_name"
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
				Write-Host ("Error: " +$task.Info.Error.Fault)
			}else{Write-Host "Delete [$datastore_name] $folder_path complete successfully"}
			disconnect-viserver $server -force -confirm:$false
		}
	}
}

function VMware.VMStart ($vm, $esx, $user, $password, $wait){
	VMware.RunCommand "start-vm -vm $vm" $esx $user $password
	if ($wait){ VMWaitTools $vm $esx $user $password}
}

function VMware.VMStop ($vm, $esx, $user, $password){
	VMware.RunCommand "stop-vm -vm $vm -confirm:(VMware.get_false)" $esx $user $password
}

function VMware.VMWaitTools($vm, $esx, $user, $password, $timeout = 300){
	$server = connect-viserver $esx -user $user -password $password
	$timerStart = [System.Diagnostics.StopWatch]::StartNew()
	$waitLimit = [TimeSpan]::FromSeconds($timeout)
	while((!$status) -and ($timerStart.Elapsed -le $waitLimit))
	{
		$toolsStatus = (Get-VM -Name $vm | Get-View | Select-Object @{N="Name";E={$_.Name}},@{Name="ToolsStatus";E={$_.Guest.ToolsStatus}}).ToolsStatus
		$status = (($toolsStatus -ne "toolsNotRunning") -and ($toolsStatus -ne "toolsNotInstalled"))
		Start-Sleep 1
	}	
	disconnect-viserver $server -force -confirm:$false
	return $status
}

function VMware.VMSuspend ($vm, $esx, $user, $password){
	VMware.RunCommand "suspend-vm -vm $vm -confirm:(VMware.get_false)" $esx $user $password
}

function VMware.VMShutDown ($vm, $esx, $user, $password){
    $server = connect-viserver $esx -user $user -password $password
    shutdown-vmguest -vm $vm -confirm:$false
    
    $wait_shutdown = $true
    while($wait_shutdown){
        start-sleep 5
        $vm_powerstate = (get-vm $vm).powerstate
        if($vm_powerstate -eq "poweredoff"){
            $wait_shutdown = $false
        }
    }
    disconnect-viserver $server -force -confirm:$false
}

#RevertSnapshot "ESXAgent" "base" "172.30.21.125" "administrator" "Qwerty123"
function VMware.RevertSnapshot ($vm, $snapname, $esx, $user, $password){
	VMware.RunCommand "set-vm -vm $vm -snapshot $snapname -confirm:(VMware.get_false)" $esx $user $password
}

function VMware.CreateSnapshot ($vm, $snapname, $esx, $user, $password){
	VMware.RunCommand "new-snapshot -name $snapname -vm $vm" $esx $user $password
}

function VMware.RemoveSnapshot ($vm, $snapname, $esx, $user, $password){
	VMware.RunCommand "remove-snapshot -snapshot $snapname -confirm:(VMware.get_false)" $esx $user $password
}

#Creates a new virtual machine named VM2 by cloning the VM1 virtual machine on the specified datastore and host.
function VMware.CloneVM($sourcevm_Name, $vm_Name, $vm_datastore, $vm_host, $vm_ResourcePool, $esx, $user, $password ){
	VMware.RunCommand "New-VM -Name $vm_Name -VM $sourcevm_Name -Datastore $vm_datastore -VMHost $vm_host -ResourcePool $vm_ResourcePool" $esx $user $password
}

function VMware.CopyToGuest($source, $VM , $target, $g_u, $g_p, $esx, $user, $password){
	VMware.RunCommand "Copy-VMGuestFile -Source $source -Destination $target -vm $VM -LocalToGuest -GuestUser $g_u -GuestPassword $g_p -Force:(VMware.get_true)" $esx $user $password
}

function VMware.CopyFromGuest($source, $VM , $target, $g_u, $g_p, $esx, $user, $password){
	VMware.RunCommand "Copy-VMGuestFile -Source $source -Destination $target -vm $VM -GuestToLocal -GuestUser $g_u -GuestPassword $g_p -Force:(VMware.get_true)" $esx $user $password
}

function VMware.InvokeScript($VM , $Script, $g_u, $g_p, $esx, $user, $password){
	VMware.RunCommand "Invoke-VMScript -VM $VM -ScriptText $Script -GuestUser $g_u -GuestPassword $g_p"  $esx $user $password
}

function VMware.RunCommand($command, $esx, $user, $password, $singlecommand=$true){
    if ($singlecommand){
		WindowsBase.Log "Connecting to viserver . . ."  
		$server = connect-viserver $esx -user $user -password $password
	}
	WindowsBase.Log "Running command . . ."  
	invoke-expression $command
	if ($singlecommand){
		WindowsBase.Log "Disconnecting from viserver . . ." 
		disconnect-viserver $server -force -confirm:$false
	}
}

function VMware.Get-VMXPath {  
	#Requires -Version 2.0  
	[CmdletBinding()]  
	 Param   
	   (  
		[Parameter(Mandatory=$true,  
				   Position=1,  
				   ValueFromPipeline=$true,  
				   ValueFromPipelineByPropertyName=$true)]  
		[String[]]$Name     
	   )#End Param   
	  
	Begin  
	{  
	 WindowsBase.Log "Retrieving VMX Path Info . . ."  
	}#Begin  
	Process  
	{  
		try  
			{  
				Get-VM -Name $Name | 
				Add-Member -MemberType ScriptProperty -Name 'VMXPath' -Value {$this.extensiondata.config.files.vmpathname} -Passthru -Force | 
				Select-Object Name,VMXPath 
			}  
		catch  
			{  
				WindowsBase.Log "Error: You must connect to vCenter first." 
			}  
			 
	}#Process  
	End  
	{  
	  
	}#End  
	  
}#Get-VMXPath 

#Copy not empty directory to VM recursively(using WindowsBase.RelativePath)
function  VMware.CopyDirToGuest($source, $VM, $dest, $g_u, $g_p, $esx, $user, $password){
	$server = connect-viserver $esx -user $user -password $password
	
	$files = @()
	$files = $files + (get-childitem $source -include *.* -recurse)
	
	foreach ($file in $files){
		$_src = $file.fullname
		$_dst = "$dest" + "\" + (WindowsBase.RelativePath $_src $source)
		 VMware.CopyToGuest `"$_src`" $VM $_dst $g_u $g_p $esx $user $password
	}
	
	disconnect-viserver $server -force -confirm:$false
}

#Get Full path to VMHost and to Datastore By VMHost Name, Datastore Name
function VMware.GetDatastorePath{
	param (
			$datastore_name,
			
			$vcenter = "vcenter-msk-prm",
			$vcenter_user ="paragon\prm_autotest_user",
			$vcenter_pass = "Ghbdtn123"
	)
	$server = connect-viserver $vcenter -user $vcenter_user -password $vcenter_pass
	$ds = (get-datastore | where {$_.Name -eq "$datastore_name"})
	$datastore_path = VMware.GetFullPath $ds
	disconnect-viserver $server -force -confirm:$false
	
	return $datastore_path
}

function VMware.GetVMHostPath{
	param (
			$vmhost_name,
			
			$vcenter = "vcenter-msk-prm",
			$vcenter_user ="paragon\prm_autotest_user",
			$vcenter_pass = "Ghbdtn123"
	)
	$server = connect-viserver $vcenter -user $vcenter_user -password $vcenter_pass
	$vh = (get-vmhost | where {$_.Name -eq "$vmhost_name"})
	$vmhost_path = (VMware.GetFullPath $vh)
	disconnect-viserver $server -force -confirm:$false
	
	return $vmhost_path
}

function VMware.GetFullPath{
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
		$parent = $parent.parent
		if(-not $parent){
			$parent = $parent.parentfolder
		}
	}
		
	return $path
}

#===================================  remove vms from pool ===================================
# use only VMware.ClearPoolByAdress

function VMware.GetFullPoolAdress($ResourcePool){	
	$pool_parent = $ResourcePool
	$ResourcePoolAdress = $ResourcePool.Name
	while($pool_parent.Parent.Parent.GetType().Name -ne "VMHostWrapper")
	{
		$pool_parent = $pool_parent.Parent
		$ResourcePoolAdress = $pool_parent.Name + "\" + $ResourcePoolAdress
	}
	Clear-Host 
	return $ResourcePoolAdress
}

function VMware.GetPoolByAdressAndServer($ResourcePoolAdress, $ResourcePoolServer){
	$ResourcePoolAdress = $ResourcePoolAdress.Replace("/","\")
	$rps = $ResourcePoolAdress.Split("\")
	$rpools = Get-ResourcePool -Name ($rps[$rps.Count-1]) -ErrorAction SilentlyContinue
	If ($rpools){
		$pool_coll=@()
		foreach ($rp in $rpools){
			$vhost = Get-VMHost -ResourcePool $rp
			If($vhost)
			{
				if ($vhost.Name -match $ResourcePoolServer){
					$pool_coll = $pool_coll + $rp
				}	
			}
		}
	}
		
	if ($pool_coll.Count -eq 1){
		Clear-Host
		return $pool_coll[0]
	}
	elseif($pool_coll.Count -gt 1){
		foreach($pool in $pool_coll)
		{
			if ((VMware.GetFullPoolAdress $pool) -eq $ResourcePoolAdress){
				Clear-Host
				return $pool
			}
		}
		Write-Host "$ResourcePoolAdress on $ResourcePoolServer not founded"
		Clear-Host
		return $null
	}
	else{
		Write-Host "$ResourcePoolAdress on $ResourcePoolServer not founded"
		Clear-Host
		return $null
	}
}

function VMware.ClearPool($ResourcePool){	
	$vms = Get-VM -Location $ResourcePool
	if($vms){
		foreach($vm in $vms){
			Write-Host ("Delete VM " + $vm + " on host " + $vm.VMHost)
			#==============  power off vm  ==============
			try{
				If ((get-vm ($vm)).PowerState -eq "PoweredOff"){
					Write-Host ($vm + " is Powered off" )
				}else{
					Stop-VM -VM $vm -Confirm:$false 
				}
				Write-Host ("VM " + $vm + " was powered off on host " + $vm.VMHost)
			}
			catch{Write-Host ("VM " + $vm + " was not powered off on host " + $vm.VMHost)}			
			#==============  remove vm  ==============
			try{
                if ($vm.Name -ne $null){
                    Remove-VM -VM (Get-VM -Name $vm.Name) -DeletePermanently:$true -Confirm:$false
                }
				Write-Host ("VM " + $vm + " was deleted on host " + $vm.VMHost)
			}
			catch{Write-Host ("VM " + $vm + " was not deleted on host " + $vm.VMHost)}
		}
	}
}

function VMware.ClearPoolByAdress(){
param (
			$ResourcePoolAdress,
			$ResourcePoolServer,
			
			$vcenter = "vcenter-msk-prm",
			$vcenter_user ="paragon\prm_autotest_user",
			$vcenter_pass = "Ghbdtn123"
	)
	Write-Host "Find pool $ResourcePoolAdress on $ResourcePoolServer"
	$server = Connect-VIServer $vcenter -User $vcenter_user -Password $vcenter_pass
	$pool = VMware.GetPoolByAdressAndServer $ResourcePoolAdress $ResourcePoolServer
	if($pool){
		Write-Host ("Founded pool " + (VMware.GetFullPoolAdress $pool) + " on host " + (Get-VMHost -ResourcePool $pool).Name)
		VMware.ClearPool $pool
	}
	Disconnect-VIServer $server -Confirm:$false
	
}

#================================= remove vms from pool(end) =================================