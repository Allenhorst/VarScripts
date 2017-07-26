# write log messages to log_file
function Write-Log
{
    Param
    (
        $message
    )

    $logL = Get-Date -Format "[yyyy.MM.dd HH:mm:ss]"
    $string = $logL + "  " +  $message
    Write-Host $string
    Out-File -FilePath "$logPath\logfile.txt" -InputObject ($string)  -Append
}

function Write-ErrorLog
{
    Param
    (
        $message
    )

    $msg = "[FAILED] " + $message
    Write-Log $msg
}


function VMWare.WaitTask
{
    Param
    ( 
        $vm=$null, 
        $task=$null, 
        $timeout = 300, 
        $exceptionMessage 
    )
    
    
    if($task)
    {
        while($task.State -eq "Running")
        {
            Start-Sleep 5
            $task = (Get-Task)|?{$_.Id -eq $task.Id}
        }
    }
    $timeWatch = [System.Diagnostics.Stopwatch]::StartNew()
    if($vm)
    {
        while((Get-Task -Status Running)|?{$_.ObjectId -eq $vm.Id})
        {
            Start-Sleep 1
            if($timeWatch.Elapsed.TotalSeconds -gt $timeout)
            {
                Write-ErrorLog "$exceptionMessage"
                throw $exceptionMessage
            }
        }
    }
}



function VMware.VMStart
{
    Param
    (
        $vmName,
        $server = $server,
        $timeout = 600 
    )


    if(!$server)
    { 
        $server = $global:DefaultVIServer 
    }

    Clear-Variable vm  -ErrorAction:SilentlyContinue
    $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop

    # check that powered off
    $vmIsPoweredOffWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while( (($vm.ExtensionData.Guest.ToolsRunningStatus  -ne "guestToolsNotRunning") -or ($vm.ExtensionData.Guest.GuestState -ne "notRunning")) -and ($vmIsPoweredOffWatch.Elapsed.TotalSeconds -lt 180) )
    {
        Start-Sleep 1
        $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop    
    }

    Clear-Variable res  -ErrorAction:SilentlyContinue
    Start-VM $vm -Server $server -ErrorAction:Stop 
    $res = Wait-Tools $vm -TimeoutSeconds $timeout -Server $server
    Start-Sleep -Seconds 10

    if ($res)
    {
        VMWare.WaitTask -vm $vm -exceptionMessage "Unable to Start VM $vmName by timeout reason..."
        

        $vmIsPoweredOnWatch = [System.Diagnostics.Stopwatch]::StartNew()
        $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop    
        $vmGuest = Get-VMGuest $vm -ErrorAction:Stop        
        while( (($vmGuest.State -ne "Running") -or ($vm.ExtensionData.Guest.GuestState -ne "Running") -or ($vm.ExtensionData.Guest.ToolsRunningStatus -ne "guestToolsRunning")) -and ($vmIsPoweredOnWatch.Elapsed.TotalSeconds -lt 180)  )
        {
            $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop    
            $vmGuest = Get-VMGuest $vm -ErrorAction:Stop
            Start-Sleep 1
        }

        Start-Sleep 2        
        # check tools
        $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop    
        $vmGuest = Get-VMGuest $vm -ErrorAction:Stop                
        if (($vmGuest.State -ne "Running") -or ($vm.ExtensionData.Guest.GuestState -ne "Running") -or ($vm.ExtensionData.Guest.ToolsRunningStatus -ne "guestToolsRunning"))
        {
            Write-ErrorLog "Could not start VM $vmName - timeout"
            return $false
        }
        return $true
    }
    Write-ErrorLog "Could not run Start VM task for $vmName - timeout"
    return $false
}



function VMware.VMShutDown
{
    Param
    (
        $vmName, 
        $server = $server, 
        $timeout = 600 
    )


    if(!$server)
    { 
        $server = $global:DefaultVIServer 
    }
    Clear-Variable vm  -ErrorAction:SilentlyContinue
    $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop

    # check that powered on
    $vmIsPoweredONWatch = [System.Diagnostics.Stopwatch]::StartNew()
    while( ($vm.ExtensionData.Guest.ToolsRunningStatus  -ne "guestToolsRunning") -and ($vmIsPoweredONWatch.Elapsed.TotalSeconds -lt $timeout) )
    {
        Start-Sleep 1
        $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop
    }
    
    Clear-Variable res  -ErrorAction:SilentlyContinue
    if ($host.version.Major -le 2)
    {
        $res = Shutdown-VMGuest -VM $vm -Server $server -Confirm:$false -ErrorAction:Stop
    }
    else
    {
        $res = Stop-VMGuest -VM $vm -Server $server -Confirm:$false -ErrorAction:Stop
    }
    
    if ($res)
    {
        VMWare.WaitTask -vm $vm -exceptionMessage "Unable to ShutDown VM $vmName by timeout reason..."
        
        $vmIsPoweredOffWatch = [System.Diagnostics.Stopwatch]::StartNew()
        $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop
        while( (($vm.PowerState -ne "PoweredOff") -or ($vm.ExtensionData.Guest.GuestState -ne "notRunning")) -and ($vmIsPoweredOffWatch.Elapsed.TotalSeconds -lt $timeout) )
        {
            Start-Sleep 1
            $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop
        }
        
        Start-Sleep 2
        $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop
        if(($vm.PowerState -ne "PoweredOff") -or ($vm.ExtensionData.Guest.GuestState -ne "notRunning"))
        {
            Write-ErrorLog "Could not ShutDown VM $vmName - timeout"
            return $false
        }
        return $true
    }
    Write-ErrorLog "Could not run ShutDown VM task for $vmName - timeout"
    return $false
}



function VMWare.CreateSnapshot
{
    Param
    ( 
        $vmName, 
        $snapshotName, 
        $description="",
        $server = $server, 
        $timeout = 300 
    )


    if(!$server)
    { 
        $server = $global:DefaultVIServer 
    }

    Clear-Variable vm  -ErrorAction:SilentlyContinue
    $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop

    Clear-Variable task  -ErrorAction:SilentlyContinue
    $task = New-Snapshot -VM $vm -Name $snapshotName -Description $description -Server $server -ErrorAction:Stop
    if($task)
    {
        VMWare.WaitTask -vm $vm -exceptionMessage "Unable to create snapshot $snapshotName for $vmName by timeout reason..."
        return $true
    }
    Write-ErrorLog "Could not create snapshot for VM $vmName - timeout"
    return $false
}


function VMWare.RevertSnapshot
{
    Param
    ( 
        $vmName, 
        $snapshotName, 
        $server = $server, 
        $timeout = 300 
    )


    if(!$server)
    { 
        $server = $global:DefaultVIServer 
    }

    Clear-Variable vm -ErrorAction:SilentlyContinue
    $vm = Get-VM -Name $vmName -Server $server -ErrorAction:Stop

    Clear-Variable snapshot -ErrorAction:SilentlyContinue
    $snapshot = Get-Snapshot -VM $vm -Name $snapshotName -Server $server -ErrorAction:Stop

    Clear-Variable task -ErrorAction:SilentlyContinue
    $task = Set-VM -VM $vm -Snapshot $snapshot -Server $server -Confirm:$false 
    if($task)
    {
        VMWare.WaitTask -vm $vm -exceptionMessage "Unable to revert $vmName to $snapshotName by timeout or task failure reason..."
        return $true
    }
    
    [String] $msg = 'Could not Revert VM '+ $vmName + ' to snapshot "' + $snapshotName + ' - timeout"'
    Write-ErrorLog $msg
    return $false
}



function VMware.GetDatastore
{
    Param
    ( 
        $viServer, 
        $vmHost, 
        $dsShortName 
    )

    Clear-Variable vmDatastore -ErrorAction:SilentlyContinue
    $vmDatastore = Get-Datastore -Server $viServer -VMHost $vmHost -Name "*$dsShortName" -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
    if (!$vmDatastore)
    {
        Write-ErrorLog "Could not find datastore $dsShortName on $($vmHost.Name)"
        return $false
    }
    return $vmDatastore
}


function VMware.InvokeVMScript
{
    Param
    (
        $vmName, 
        $scriptText,
        $guser = $guser,
        $gpass = $gpass,
        $scriptType = "Bat"
    )


    Clear-Variable res -ErrorAction:SilentlyContinue
    $expectedOutput = ""
    while(!($res -and ($res.ScriptOutput -like "*$expectedOutput*")))
    {
        try{
            Clear-Variable vm -ErrorAction:SilentlyContinue
            $vm = Get-VM $vmName -Server $server -ErrorAction:Stop
            $res = Invoke-VMScript -VM $vm -GuestUser $guser -GuestPassword $gpass -ScriptType $scriptType -ScriptText "$scriptText" -ToolsWaitSecs 600 -WarningAction:SilentlyContinue
            $res
            Start-Sleep -Seconds 15
        }catch{
               Write-ErrorLog "Some problems with Invoke-VMScript $vmName"
            $_
        }
    }
    return $res.ScriptOutput
}



function VMware.CustomInvokeVMScript
{
    Param
    (
        $vmName, 
        $scriptText,
        $workDirectory,
        $scriptFileName,
        $redirectOut = $false,
        $encoding = "UTF8",
        $guser = $guser,
        $gpass = $gpass,
        $isPSScript = $false
    )


    Clear-Variable tmp -ErrorAction:SilentlyContinue
    $tmp = "$logPath\$scriptFileName"
    
    #$scriptText | Out-File $tmp -Encoding $encoding
    VMware.CopyToGuest -source $tmp -VM $vmName -target "$workDirectory" -guser $guser -gpass $gpass
	#Remove-Item $tmp -Confirm:$false -Force:$true
    if(!$isPSScript)
    {
       $runSript = "cmd /c `"$workDirectory\$scriptFileName`""
    }
    else
    {
       $runSript = "powershell -File `"$workDirectory\$scriptFileName`""
    }
    if($redirectOut){$runSript = $runSript + " >>$workDirectory\"+"$scriptFileName"+".log 2>>&1"}
    Write-Log "$runSript"
    return (VMware.InvokeVMScript $vmName $runSript $guser $gpass)
}



function VMware.CopyToGuest
{
    Param
    (
        $source,
        $VM,
        $target,
        $guser = $guser,
        $gpass = $gpass
    )


    Clear-Variable fileName -ErrorAction:SilentlyContinue
    $fileName=[System.IO.Path]::GetFileName($source)
    $timeout=180
    $copiedTimeout = [System.Diagnostics.Stopwatch]::StartNew()
    $fullTarget = ($target + '\' + $fileName)
    while( ( !$fileExists ) -and ($copiedTimeout.Elapsed.TotalSeconds -lt $timeout))
    {
        Copy-VMGuestFile -Source $source -Destination $target  -vm $VM -LocalToGuest -GuestUser $guser -GuestPassword $gpass -Force:$true -WarningAction:SilentlyContinue
        $fileExists = (([string](VMware.InvokeVMScript $vm "if exist `"$fullTarget`" (echo exists)")).Trim() -like "*exists*")
    }

    $copiedTimeout2 = [System.Diagnostics.Stopwatch]::StartNew()
    $fileExists = (([string](VMware.InvokeVMScript $vm "if exist `"$fullTarget`" (echo exists)")).Trim() -like "*exists*")
    if ((!$fileExists)-and ($copiedTimeout2.Elapsed.TotalSeconds -lt $timeout))
    {
        Copy-VMGuestFile -Source $source -Destination $fullTarget  -vm $VM -LocalToGuest -GuestUser $guser -GuestPassword $gpass -Force:$true -WarningAction:SilentlyContinue
        $fileExists = (([string](VMware.InvokeVMScript $vm "if exist `"$fullTarget`" (echo exists)")).Trim() -like "*exists*")
    }

}



function VMware.CopyFromGuest
{
    Param
    (
        $source, 
        $vm, 
        $target,
        $guser = $guser, 
        $gpass = $gpass
    )

    Copy-VMGuestFile -Source $source -Destination $target -vm $vm -GuestToLocal -GuestUser $guser -GuestPassword $gpass -Force:$true -WarningAction:SilentlyContinue
}



function VMware.CopyFileToDatastore
{
    Param
    (
        [String]  $sourcePath,
        [String]  $datastoreName,
        [String]  $targetFolder,
        [Bool] $recurse = $false
    )


    Clear-Variable datastore -ErrorAction:SilentlyContinue
    $datastore = Get-DataStore $datastoreName
    if($datastore.Name -eq $datastoreName)
    {
        $isCopyToDatastoreFine = $true
        $psDrive = New-PSDrive -Location $datastore -Name ds -PSProvider VimDatastore -Root "\"
        if(-not (test-path "ds:\$targetFolder"))
        {
            mkdir "ds:\$targetFolder"
        }
        if($recurse)
        {
            Copy-DatastoreItem -Item $sourcePath -Destination "ds:\$targetFolder\" -Recurse -Force:$true -Confirm:$false
        }
        else
        {
            Copy-DatastoreItem -Item $sourcePath -Destination "ds:\$targetFolder\" -Force:$true -Confirm:$false
        }
        Remove-PSDrive $psDrive        
    }
}







function VMware.Get-Pool
{
    <#
        .SYNOPSIS
            Get resource pool by adress
        .DESCRIPTION
            Get resource pool in vCenter from selected server by adress
        .PARAMETER poolAdress
            Pool adress
        .PARAMETER server_name
            Server name
        .PARAMETER create
            Create or not if pool not exists        
        .EXAMPLE
            all parameters are set by user
            PS C:\>Get-Pool "AutoTests\Agents" $server_name $true
        .INPUTS
            System.String,System.String,System.Boolean
        .OUTPUTS
            ResourcePoolImpl (VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl)
    #>
    Param
    (
        [string] $poolAdress,
        [string] $server_name,
        [bool] $create = $false
    )
    
    
    $adress = $poolAdress.split("\")
    $parentID = (Get-ResourcePool -Name "Resources" -Location (Get-VMHost -name $server_name)).ID
    foreach ($poolName in $adress)
    {
        $pool = Get-ResourcePool -Name $poolName -Location(Get-ResourcePool -Id $parentID ) -ErrorAction:SilentlyContinue
        if( $pool)
        {
            $parentID = $pool.ID
        }
        else
        {
            if($create)
            {    
                $location = Get-ResourcePool -Id $parentID
                $pool = New-ResourcePool -Name $poolName -Location $location -Confirm:$false 
                $parentID = $pool.ID
            }
            else{return $null}
        }
    }
    
    return $pool
}



#=====================   drafts   =========================
function Get-Path
{
    Param
    (
        $pool
    )    
    
    
    $path = $pool.Name
    $parent = $pool.Parent
    while($parent)
    {
        $path = $parent.Name + "/" + $path
        if($parent.Parent)
        {
            #if($parent.Parent.Name -eq "Resources") {$parent = $null}
            $parent = Get-View $parent.Parent            
        }
        else
        {
            $parent = $null
        }
    }
    
    return $path
}

#Get-Path (Get-ResourcePool -Name "Agents" -Location (Get-VMHost "sb492.paragon-software.com"))