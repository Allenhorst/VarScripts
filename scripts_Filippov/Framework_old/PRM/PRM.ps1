
function PRM.AdminServer(){return (gi prm::computers -filter "role contains adminserver")}

function PRM.ConnectAdminServer(){
    connect-prmserver -name (PRM.AdminServer).Name
}

# replication components: "Directory, EventManager, CredentialsManager"
function PRM.Replicate($computer=$null, $Components = "CredentialsManager, Directory, EventManager, TaskManager", $timeout = 300) { 
	$comp = $null
	if($computer) {
		$comp = gi prm::computers\$computer
		if($comp){		
			if((PRM.AdminServer) -eq $comp){
				Windowsbase.Log "You cannot use replication for administration server $computer"
				return $false
			}
		}
		else{
			Windowsbase.Log "There is no requested computer $computer in infrastructure."
			return $false
		}
	}

	$results = @()
	foreach($component in $Components.Replace(' ', '').Split(','))
	{
		WindowsBase.Log "Start replication for $computer components: $component"
		$req_rep = Request-PRMReplica $comp $component -Timeout $timeout 
		foreach($c in $req_rep.Keys) {
			$c_res = $req_rep[$c]
			WindowsBase.Log ("Confirm replication for " + $c.Name +"  status: $c_res")
			$results += $c_res
		}
	}
	return ($results -notcontains $false)
}

function PRM.Wait-Policy{
    Param
	(
        $policy_name,
        $timeout = 3*60*60,
        $delay = 3,
        $submitTime = (get-date).ToUniversalTime()
	)
	WindowsBase.Log ("Entering wait-policy for $policy_name")
    #$submitTime = Get-Date
    WindowsBase.Log ("Wait tasks start from time = " + $submitTime)
    #-----------------------------------------------------------
	
	#clear error stream
	$error.clear()
	#-----------------------------------------------------------
		
	#failed task state and result status list
	$stateFailList = @( "failed",
                        "finished, failed",
                        "finished, terminated",
                        "finished, timeout",
                        "canceled",
                        "canceled, failed",
                        "canceled, timeout",
                        "expired",
                        "expired, failed",
                        "expired, timeout"
						)
    $resultStatusFailList = @("Fail", "SuccessWithInfo", "None")
    #-----------------------------------------------------------
	
	#get policy object by policy name
	$policy = get-item prm::policies\$policy_name
    #-----------------------------------------------------------
	
	#wait for task start
    $timerStart = [System.Diagnostics.StopWatch]::StartNew()
	$waitTaskStartLimit = [TimeSpan]::FromSeconds(15*60)
	$delay = 10
    
	while (!($policy.GetTasks() | where { `
                                         ($_.Component -ne "TaskManager") `
                                         -and ($_.Component -ne "TestComponent") `
                                         -and (($_.TaskTiming - $submitTime).TotalSeconds -gt -5) `
                                         }) `
           -and ($timerStart.Elapsed -le $waitTaskStartLimit))
    {
		start-sleep $delay
	}
    
    if ($timerStart.Elapsed -lt $waitTaskStartLimit)
    {
        WindowsBase.Log ("Tasks were successfully started. Waiting for tasks finish.")
        $timerFinish = [System.Diagnostics.StopWatch]::StartNew()
        $waitTaskFinishLimit = [TimeSpan]::FromSeconds($timeout)
        $delay = 10
        
        $waitFinish = $true
        while ($waitFinish -and ($timerFinish.Elapsed -le $waitTaskFinishLimit))
        {
            $waitFinish = $false
            #renew task list
            $taskList = ($policy.GetTasks() | where { `
                                         ($_.Component -ne "TaskManager") `
                                         -and ($_.Component -ne "TestComponent") `
                                         -and (($_.TaskTiming - $submitTime).TotalSeconds -gt -5) `
                                         })
            #check task state
            foreach($task in $taskList){
                if ($task.State -eq "finished"){
                    if ($resultStatusFailList -contains $task.ResultStatus)
                    {
                        write-error ("Policy $policy_name task is failed. Task result status is: " + $task.ResultStatus)
                    }
                    else
                    {
                        WindowsBase.Log ("Policy $policy_name tasks are finished successfully")
                    }
                }
                else{
                    if ($stateFailList -contains $task.State)
                    {
                        write-error ("Policy task " + $task.State)
                    }
                    else
                    {
                        $waitFinish = $true
                    }
                }
            }
            start-sleep $delay
        }
        if ($timerFinish.Elapsed -gt $waitTaskFinishLimit)
        {
            write-error "waitTaskFinishLimit timeout is expired!"
        }
    }
    else
    {
        write-error "waitTaskStartLimit timeout is expired!"
    }
    #-----------------------------------------------------------

    if ($error)
    {
        return $false
    }  
    return $true    
}

function PRM.Wait-PolicyTask
{
    Param(
        $policyTask
    )
    
    #failed task state and result status list
	$stateFailList = @( "failed",
                        "finished, failed",
                        "finished, terminated",
                        "finished, timeout",
                        "canceled",
                        "canceled, failed",
                        "canceled, timeout",
                        "expired",
                        "expired, failed",
                        "expired, timeout"
						)
    $resultStatusFailList = @("Fail", "SuccessWithInfo", "None")
    #-----------------------------------------------------------
    
    $policyName = $policyTask.Policy
    WindowsBase.Log ("Entering Prm.Wait-PolicyTask for $policyName")
    
    $waitTestLimit = [TimeSpan]::FromSeconds(3*60*60)
    $delay = 5
    
    $timerFinish = [System.Diagnostics.StopWatch]::StartNew()
    
    $isErrorOccured = $false
    $isTestContinue = $true    

    
    while (($isErrorOccured -eq $false) -and ($isTestContinue -eq $true) -and ($timerFinish.Elapsed -le $waitTestLimit)){
        $isTestContinue = $false
        #update task
        if(-not $policyTask.Update())
        {
            write-error ("$policyName Failed to renew task!")
            WindowsBase.Log ("$policyName Failed to renew task!")
            $isErrorOccured = $true
        }
        
        #check task status
        if ($policyTask.State -eq "finished")
        {
            if ($resultStatusFailList -contains $policyTask.ResultStatus)
            {
                write-error ("$policyName Task is failed. Task Result Status is: " + $policyTask.ResultStatus)
                WindowsBase.Log ("$policyName Task is failed. Task Result Status is: " + $policyTask.ResultStatus)
                $isErrorOccured = $true
            }
            
        }
        else{
            if ($stateFailList -contains $policyTask.State)
            {
                write-error ("$policyName Task is failed. Task State is: " + $policyTask.State)
                WindowsBase.Log ("$policyName Task is failed. Task State is: " + $policyTask.State)
                $isErrorOccured = $true
            }
            else{
                $isTestContinue = $true
                start-sleep $delay
            }
        }
    }
    if ($timerFinish.Elapsed -gt $waitTestLimit)
    {
        write-error "TestLimit timeout is expired!"
        WindowsBase.Log ("TestLimit timeout is expired!")
        NUnit.Assert $false ("TestLimit timeout is expired!")
        $isErrorOccured = $true
    }
    
    #return value
    if ($isErrorOccured -eq $true)
    {
        return $false
    }
    WindowsBase.Log ("Policy $policyName tasks are finished successfully")
    return $true 
}

function PRM.SubmitPolicy($policy_name, $wait=$true, $timeout = 3*60*60){
    submit-prmpolicy (gi prm::Policies\$policy_name)
	if ($wait){
		start-sleep 2
		return (PRM.Wait-Policy $policy_name $timeout)
	}
}

#Get prmpath for vm(outdated)
function PRM.Get-vmPath($ESXAgent, $ESXServer, $VMName, $Datacenter =  "ha-datacenter"){
	return, ((get-prmBackupItems -prmhost (gi prm::computers\$ESXAgent) -BackupAgent "ESXAgent" -prmpath @($ESXServer, $Datacenter, "vm")) | where {$_.name -eq $VMName})
}

# Whait while policy exist on agent host
function PRM.WaitPolicyExist([string] $host_name, $policy_name){
	Connect-PRMServer -Name $host_name
	While (!(PolicyExist $policy_name)){start-sleep 5}
	PRM.ConnectAdminServer
}
# Example WhaitPolicyExist "ig-test-0001" "Prob2"

function PRM.PolicyExist($policy_name){
	if (gi prm::policies\$policy_name -ErrorAction SilentlyContinue){return, $true}
	return, $false
}

#get status of PRM service after installing
function PRM.PRMServiceStatus(){return (Get-Service PRM).Status}

function PRM.WaitPRMService($timeout = 120, $delay = 5){
	$time = 0
	WindowsBase.Log "Starting PRM service wait."
	while(($time -le $timeout) -and ((PRM.PRMServiceStatus) -ne "Running")){	
		if(!(PRM.PRMServiceStatus)){
			WindowsBase.Log "Can not get state of PRM service state."
			return $false
		}
		Start-Sleep $delay
		$time = $time + $delay
	}
	if((PRM.PRMServiceStatus) -ne "Running"){
		WindowsBase.Log "PRM service was not running."
		return $false
	}
	WindowsBase.Log "PRM service started"
	return $true
}

#write object properties to log (like in PS console)
function PRM.Log($prm_object){
	WindowsBase.Log ("---------------------" + $prm_object + "---------------------")
	WindowsBase.Log (($prm_object | Format-list) | Out-String)
	WindowsBase.Log ("------------- end of " + $prm_object + " info ---------------")
}

#Parse events(find whith error, and send failure assertion)
function PRM.ParseEvents (){
    $isEventListFine = $true
    WindowsBase.Log "Parse PRM events"
    $errorEventList = @()
    $errorEventList = $errorEventList + (get-item prm::events\ -filter "type=Error")
    if($errorEventList -ne @()){
        foreach($item in $errorEventList){
            $message = "`nEvent Error message: " + $item.message
			$eventData = [hashtable]$item.data
			If($eventData.Count -gt 0){
				$eventDataString = "Events Error: `n"
				foreach($dataKey in $eventData.Keys){
					$eventDataString += $dataKey + ": " + $eventData[$dataKey] + "`n"
				}
				 $message = $message + "`n" + $eventDataString
			}
			NUnit.Assert $false $message			
        }
		$isEventListFine = $false
    }
    
    WindowsBase.Log "Parse check integrity data"
    $checkIntegrityEventList = @()
    $checkIntegrityEventList = $checkIntegrityEventList + (get-item prm::events\ -filter "eventId=3059")
    if($checkIntegrityEventList -ne @())
    {
        foreach($item in $checkIntegrityEventList){
            $message = "`nCheck Integrity message: " + $item.message
			$eventData = [hashtable]$item.data
			If($eventData.Count -gt 0){
				$eventDataString = "Check Integrity Data: `n"
				foreach($dataKey in $eventData.Keys){
					$eventDataString += $dataKey + ": " + $eventData[$dataKey] + "`n"
				}
				 $message = $message + "`n" + $eventDataString
			}
            if($message -match "CHK_NOT_FIXED")
            {
                $eventOid = $item.EventOid
                NUnit.Assert $false "Found CHK_NOT_FIXED in check integrity event! Search event with EventOid=$eventOid in PRM journal for more details."
                $isEventListFine = $false
            }
        }
    }
    
    if($isEventListFine)
    {
        WindowsBase.Log "Events are fine!"
    }
	return, $isEventListFine
}
#collect logs from PRM computers
function PRM.CollectLogs{
    Param(
        $resultFolder,
        $agentList = [Array](gi prm::computers)# -filter "role notcontains AdminServer")
    )
    foreach ($agent in $agentList)
    {
		$Error.Clear()
		try{
        	$resultFile = Get-PRMLogs -ComputerId $agent.Id -ArchiveFile ($resultFolder + "\" + $agent.Name + ".zip")
			NUnit.Assert $true ("Collected logs from: " + $agent.Name)
		}
		catch{
			$message = ("Can't collect logs from: " + $agent.Name + "state: " + $agent.State + "`n See error:`n " + $Error)
			NUnit.Assert $false $message
			$Error.Clear()
		}
    }
}

#Parse PRM log
function PRM.ParseLog{
    Param
	(
		[string] $prmlog
	)
	$reader = [System.IO.File]::OpenText($prmlog)
	$errorMessages = @()
	try {
	    for(;;) {
	        $item = $reader.ReadLine()
	        if ($item -eq $null) { break }
	        # process the line
	        			
			#  ========================  Additional information loggin ========================
			if ($item -match "Total changed chains [a-f\d]+, sectors 0x[a-f\d]+"){
                $message = "`n'total changed chains\sectors' info found"
                $message += "`n[path]$prmlog[/path]"
                $message += "`n[info]" + (($item -split '"')[1] -split '"')[0] + "[/info]`n"
				Write-Host $message
            }
            if ($item -match "Clusters [a-f\d]+ volume copy time [a-f\d]+ in [a-f\d]+ msec"){
                $message = "`n'clusters\copy time' info found"
                $message += "`n[path]$prmlog[/path]"
                $message += "`n[info]" + (($item -split '"')[1] -split '"')[0] + "[/info]`n"
				Write-Host $message
            }
            if ($item -cmatch "asdF5hh"){
                $message = "Password is found in logs!`n $item"
                NUnit.Assert $false $message
                Write-Host $message
            }
            if ($item -cmatch "Qwerty123"){
                $message = "Password is found in logs!`n $item"
                NUnit.Assert $false $message
                Write-Host $message
            }
			#  ========================  Additional information loggin ========================
			
			$flag_list = @("I", "E", "D")
            $result = (($item -split '"')[0] -split ",")[-3]
			if(-not ($flag_list -contains $result)){
				$result = (($item -split '"')[0] -split ",")[-4]
			}
            if ($result -eq "E"){
                $message = ($item -split '"')[1]
				$skip_error_list = @(
										"exception RemotingException: Requested Service not found    at System.Runtime.Remoting.Proxies.RealProxy.HandleReturnMessage",
                                        "exception System.Xml.XmlException: Element 'prmSection' was not found.",
										"exception System.IO.FileNotFoundException: Could not load file or assembly 'Prm.Agent.Common, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null' or one of its dependencies.",
										"exception System.Xml.XmlException: 'None' is an invalid XmlNodeType."
										)
				$skip_error = $false
				foreach ($err in $skip_error_list){
					if ($message -match $err){
						$skip_error = $true
					}
				}
                
				if(-not $skip_error){
					$message = `
					  "`n	Previous message:   " + $previousMessage`
					+ "`n	Error message:      " + $item 
					$errorMessages += $message `
					+ "`n	-----------------------------------------------------------------------------------------------------------------------------------`n"
				}
			}
			$previousMessage = $item #($item -split '"')[1]
		}
	}
	finally { $reader.Close() }
	if($errorMessages -ne $null){ 
		$errorMessages = @("`n`n	|Founded in:         " `
		+ [io.path]::GetFileName($prmlog) + "	|`n") + $errorMessages
	}
	# result 
	return $errorMessages
}
#find all events with attachments and parse logs from attachments
function PRM.ParseEventAttachment{
	WindowsBase.Log "Parse logs in events attachments"
	$events = Get-Item prm::events | Where-Object {$_.hasAttachment}
	$tmp_dir = ("c:" + "\attachments")
	if (Test-Path $tmp_dir) { $_t = Remove-Item -Path $tmp_dir -Confirm:$false -Force:$true -Recurse:$true -ErrorAction:SilentlyContinue }
	[string] $summaryError = $null
	try{
		foreach($event in $events){
			$errorMessages = @()
			$_t = New-Item $tmp_dir -ItemType directory
			$filename = (Get-PRMEventAttachment $tmp_dir $event).Name
			if(Test-Path -Path "$tmp_dir\$filename"){
				$shell_app=new-object -com shell.application
				$zip_file = $shell_app.namespace("$tmp_dir\$filename")
				$destination = $shell_app.namespace($tmp_dir)
				$destination.Copyhere($zip_file.items())
				#get and parse logs from temporary folder
				$log_list = gci "$tmp_dir" *.log -recurse
				if ($log_list -ne $null){
					foreach ($log in $log_list){
						$errorMessages += PRM.ParseLog $log.fullname					
					}
					if($errorMessages -ne $null){
						$event_table = @{Expression={$_.eventOid};Label="Oid";width=8}, `
							@{Expression={$_.eventId};Label="ID";width=6}, `
							@{Expression={$_.type};Label="Type";width=12}, `
							@{Expression={$_.componentFlag};Label="Component";width=20}, `
							@{Expression={$_.policyName};Label="Policy Name";width=48}, `
							@{Expression={$_.severity};Label="Severity";width=10}, `
							@{Expression={$_.creationTime};Label="Created";width=22}, `
							@{Expression={$_.targetComputerName};Label="Target Computer Name";width=22}, `
							@{Expression={$_.sourceComputerName};Label="Source Computer Name";width=22}
						$event_detail = ($event | Format-Table $event_table -Wrap | Out-String -Width 180)						
						$summaryError += "`------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------`n" `
						+ $event_detail.substring(2,$event_detail.Length-6)
						foreach($errorMessage in $errorMessages){ $summaryError +=  $errorMessage }					
						$summaryError += "`------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------`n`n`n"
					}
				}
			}
			else{ Write-Host "Attachment does not exists: $tmp_dir\$filename" }
			$_t = Remove-Item -Path $tmp_dir -Confirm:$false -Force:$true -Recurse:$true
		}
	}
	catch{
		WindowsBase.Log "Unexpected error during parsing logs"
	}
	if(($summaryError -ne $null) -and ($summaryError -ne "")){
		WindowsBase.Log ("End parsing logs in events attachments: ==========  " + $summaryError)
		$summaryError = "`n`n`n`n`n`n----------------------------------------------------------------------- Parse event attachments logs -------------------------------------------------------------------------------`n" `
		+ $summaryError 
		NUnit.Assert $false $summaryError
	}
	WindowsBase.Log "End parsing logs in events attachments"
}
#parse log from collected archives
function PRM.ParseCollectedLogs{
	Param
	(
		[string] $path
	)
	WindowsBase.Log "Parse collected PRM logs"
	$zip_list = Get-ChildItem $path *.zip -recurse
	$tmp_dir = ("c:" + "\attachments")
	if (Test-Path $tmp_dir) { $_t = Remove-Item -Path $tmp_dir -Confirm:$false -Force:$true -Recurse:$true -ErrorAction:SilentlyContinue }
	[string] $summaryError = $null
	try{	
		if ($zip_list -ne $null){
			foreach ($zip in $zip_list){
				$_t = New-Item $tmp_dir -ItemType directory
				$shell_app=new-object -com shell.application
				$zip_file = $shell_app.namespace($zip.fullname)
				$destination = $shell_app.namespace($tmp_dir)
				$destination.Copyhere($zip_file.items())
				#get and parse logs from temporary folder
				$log_list = gci $tmp_dir *.log -recurse
				if ($log_list -ne $null){
					foreach ($log in $log_list){
						$errorMessages += PRM.ParseLog $log.fullname
					}
					if($errorMessages -ne $null){
						$summaryError += "`n---------------------------------------------- " + "Error message for:  " + $zip.BaseName + " ------------------------------------------------------"
						foreach($errorMessage in $errorMessages){
							if($errorMessage -ne $null){ $summaryError +=  $errorMessage }
						}
						$summaryError += "-------------------------------------------------------- " + $zip.BaseName + " ----------------------------------------------------------------`n`n"
					}
				}
				$_t = Remove-Item -Path $tmp_dir -Confirm:$false -Force:$true -Recurse:$true
			}
		}
	}
	catch{
		WindowsBase.Log "Unexpected error during parsing logs"
	}
	if(($summaryError -ne $null) -and ($summaryError -ne "")){
		WindowsBase.Log ("End parsing collected PRM logs:  ==========   " + $summaryError)
		$summaryError = "`n-------------------------------------------------------------------------- Parse collected logs -----------------------------------------------------------------------------------" `
		+ $summaryError
		NUnit.Assert $false $summaryError
	}
	WindowsBase.Log "End parsing collected PRM logs"
}
#export events to html report
function PRM.ExportEvents{
	Param
	(
		[string] $path
	)
	WindowsBase.Log "Export PRM events to $path"
	$prmEventList =  gi prm::events	
	#region get computers table
		$computersTable = @()
		foreach($comp in  (gi prm::computers)){
			$obj = New-Object -TypeName PsObject
			$obj | Add-Member -MemberType:NoteProperty -Name "Name" -Value $comp.Name
			$obj | Add-Member -MemberType:NoteProperty -Name "ID" -Value $comp.Id
			$roles = ""
			$comp.Role |% { [string]$roles += ($_.ToString() + " ") }
			$obj | Add-Member -MemberType:NoteProperty -Name "Roles" -Value $roles
			$obj | Add-Member -MemberType:NoteProperty -Name "State" -Value $comp.State			
			$obj | Add-Member -MemberType:NoteProperty -Name "Domain" -Value $comp.Software.Domain
			$obj | Add-Member -MemberType:NoteProperty -Name "Workgroup" -Value $comp.Software.Workgroup
			$obj | Add-Member -MemberType:NoteProperty -Name "Networks" -Value $comp.Hardware.Networks
			$obj | Add-Member -MemberType:NoteProperty -Name "CPU" -Value $comp.Hardware.CPU
			$obj | Add-Member -MemberType:NoteProperty -Name "RAM" -Value $comp.Hardware.RAM
			$obj | Add-Member -MemberType:NoteProperty -Name "Volumes" -Value $comp.Hardware.Volumes
			$osVersion = $comp.OSVersion
			if ($comp.Software."64-bit OS" -eq "True") { $osVersion += " x64" }else{ $osVersion += " x86" }
			$obj | Add-Member -MemberType:NoteProperty -Name "OSVersion" -Value $osVersion
			$obj | Add-Member -MemberType:NoteProperty -Name "Time zone" -Value $comp.Software."Time zone"
			$computersTable += $obj
		}
		$comps = $computersTable | ConvertTo-HTML 
		$computersTable = @()
		$_t = $false
		$comps | % {
			if($_ -eq "<table>"){$_t = $true}
			if($_t){$computersTable += $_}
			if($_ -eq "</table>"){$_t = $false}
		}
		
		$computersTableString = @'
	<div id="comp" style="display: none">
		<form>
'@	+ ($computersTable | Out-String) + "`n	</form></div>" 
	#endregion get computers table
	
	$head = @'
	<style type="text/css" media="screen">
	body{color:#FFFFFF;background-color:#1270A6;font-size:10pt;font-family:'trebuchet ms', helvetica, sans-serif;font-weight:normal;padding-:0px;margin:0px;overflow:auto;}
	.mytable{width:100%; font-size:12px;border:1px solid #CACCAC;}
	a{font-family:Tahoma;color:Orange;Font-Size:10pt display: block;}
	table,tr,td,th {font-family:Tahoma;color:Black;Font-Size:10pt;width:auto;}

	td{ padding:2px; border-bottom:1px solid #ccc; border-right:1px solid #ccc; }
	th{font-weight:bold;background-color:#CACCAC;}
	tr:nth-child(even) {background: #e8f5fa}
	tr:nth-child(odd) {background: #bfebfc}
	tr.datacellError {font-weight:bold;background-color:#f5ae9f;color:black;}
	tr.datacellWarning {background-color:#f5eaab;color:black;}
	</style>
	<script src="/js/jquery/jquery-1.10.1.min.js"></script>
	<script src="/js/jquery/tablefilter.js"></script>
	<script>
	$(document).ready(function() {
	    $('input[type="checkbox"]').click(function() {
	        var index = $(this).attr('name').substr(3);
	        index--;
	        $('table[id="table_3"] tr').each(function() { 
	            $('td:eq(' + index + ')',this).toggle();
	        });
	        $('th.' + $(this).attr('name')).toggle();
	    });
	});
	</script>
'@

	$body = ("PRM Events`n" + (Get-Date -f o)) + "`n" + `
	'<button id="cols">Select columns</button><button id="comp">PRM Computers Info </button>' + `
@'
	<div id="cols" style="display: none">
		<form>
			<input type="checkbox" name="col1" checked="true" /> eventOid </br>
			<input type="checkbox" name="col2" checked="true" /> eventId  </br>
			<input type="checkbox" name="col3" checked="true" /> creationTime  </br>
			<input type="checkbox" name="col4" checked="true" /> type  </br>
			<input type="checkbox" name="col5" checked="true" /> severity  </br>
			<input type="checkbox" name="col6" checked="true" /> componentFlag  </br>
			<input type="checkbox" name="col7" checked="true" /> policyName  </br>
			<input type="checkbox" name="col8" checked="true" /> policyId  </br>
			<input type="checkbox" name="col9" checked="true" /> targetComputerName </br>
			<input type="checkbox" name="col10" checked="true" /> targetComputerId  </br>
			<input type="checkbox" name="col11" checked="true" /> sourceComputerName  </br>
			<input type="checkbox" name="col12" checked="true" /> sourceComputerId  </br>
			<input type="checkbox" name="col13" checked="true" /> message  </br>
			<input type="checkbox" name="col14" checked="true" /> hasAttachment  </br>
		</form>
	</div>
'@

	$props = "eventOid,eventId,creationTime,type,severity,componentFlag,policyName,policyId,targetComputerName,targetComputerId,sourceComputerName,sourceComputerId,message,hasAttachment"
	$props = $props.split(",")
	
	
	
	$rez = @()
	foreach($event in  $prmEventList){
		$obj = New-Object -TypeName PsObject
		foreach($property in $props) { 
			$obj | Add-Member -MemberType:NoteProperty -Name $property -Value ($event."$property")
		}
		If($event.data.Count -gt 0){
			$str = ""
			foreach ($dataKey in $event.data.Keys ){ 
				$str = [string]( $dataKey + ":`n" + $event.data[$dataKey])
			}
			$obj.message = $obj.message + "`n" + $str
		}
		$rez += $obj
	}
	$html = $rez | Select-Object $props | ConvertTo-Html -Body $body -Head $head 

	$colHeader =@'
	<tr>
		<th class="col1" >eventOid</th>
		<th class="col2" >eventId</th>
		<th class="col3" >creationTime</th>
		<th class="col4" >type</th>
		<th class="col5" >severity</th>
		<th class="col6" >componentFlag</th>
		<th class="col7" >policyName</th>
		<th class="col8" >policyId</th>
		<th class="col9" >targetComputerName</th>
		<th class="col10" >targetComputerId</th>
		<th class="col11" >sourceComputerName</th>
		<th class="col12" >sourceComputerId</th>
		<th class="col13" >message</th>
		<th class="col14" >hasAttachment</th>
	</tr>
'@

	$postScripts =@'
	<script language="javascript" type="text/javascript">
	//<![CDATA[
		var table3Filters = {
			col_0: "none",
			col_3: "select",
			col_4: "select",
			col_5: "select",
			col_6: "select",
			col_7: "select",
			col_8: "select",
			col_9: "select",
			col_10: "select",
			col_11: "select",
			col_13: "select"
		}
		setFilterGrid("table_3",0,table3Filters);
	//]]>
	</script>

	<script> 
	$('button').click(function () {		
		if ((this).id == 'cols') {
			$('div[id="cols"]').toggle(); 
		}
		if ((this).id == 'comp') {
			$('div[id="comp"]').toggle();
		}
	});
    </script>
'@

	$rh = @()
	$adminServerName = (gi prm::computers -filter "role contains AdminServer").Name
	$html |% {
		if($_ -match "<tr><th>"){$rh += $colHeader }
		elseif($_ -match "<table>"){ $rh += $computersTableString ; $rh += '<table id="table_3" cellspacing="0" class="mytable" >' }
		elseif($_ -match "<tr><td>"){
			$rowString = $_.Replace("`n","<br>")
			if($_ -match "<td>Error</td>"){
				$rowString = $rowString.replace("<tr>","<tr class=`"datacellError`">")
			}
			elseif($_ -match "<td>Warning</td>"){
				$rowString = $rowString.replace("<tr>","<tr class=`"datacellWarning`">")
			}
			if($_ -match "<td>True</td></tr>" ){
				$indexStart =  $rowString.IndexOf("<td>") + 4
				$indexEnd = $rowString.IndexOf("</td><td>")
				$eventOid = $rowString.Substring($indexStart, ($indexEnd - $indexStart))
				$attachIndex = $rowString.IndexOf("<td>True</td></tr>")
				$link = '<a href="' + $adminServerName + ".zip%21/EventAttachments/event_" + $eventOid + '_files.zip">' + "True</a>"
				$rowString = $rowString.Substring(0, $attachIndex) + "<td>" + $link + "</td></tr>"
			}
			$rh += $rowString
		}
		elseif($_ -match "</body>"){$rh += $postScripts ; $rh += $_ }	
		else{ $rh += $_ }
	}
	$rh | Out-File $path -Encoding "ASCII"
	WindowsBase.Log "Export PRM events finished."
}

# hdm log oarsers
function PRM.ParsePwLog{
    <#
        .SYNOPSIS
            Parse HDM pwlog.txt log file.
        .DESCRIPTION
            Parse HDM pwlog.txt log file. 
            If log is fine function returns 0 else function returns text message about errors.
        .PARAMETER  logPath
            Path to pwlog.txt Example: c:\tmp\pwlog.txt
        .EXAMPLE
            PS C:\> Test-QaPwLog c:\tmp\pwlog.txt
        .INPUTS
            System.String
        .OUTPUTS
            System.Int or System.String
    #>
    Param(
        $logPath
    )
	WindowsBase.Log ("Start parsing PwLog: $logPath.")
    if(test-path $logPath)
    {
		try{
	        $plainText = [system.io.file]::ReadAllText($logPath)
	        $lineList = $plainText -split "\r\n"
	        
	        $errorList = @("error")
	        $ignoreList = @('Scanning directories and files for errors', 'file: "')
	        
	        $errorCount = 0
	        $errorLog = ""
	        
	        foreach ($line in $lineList)
	        {
	            $lineErrorCount = 0
	            foreach ($err in $errorList)
	            {
	                $lineErrorCount += ([regex]::matches($line, $err)).count
	            }
	            $lineIgnoreCount = 0
	            foreach ($ignore in $ignoreList)
	            {
	                $lineIgnoreCount += ([regex]::matches($line, $ignore)).count
	            }
	            $errorCount += ($lineErrorCount - $lineIgnoreCount)
	            if ($lineErrorCount -gt $lineIgnoreCount)
	            {
	                $errorLog = $errorLog + $line + "`n"
	            }
	        }
	        if ($errorCount -ne 0)
	        {
	            $message = "There are $errorCount errors in $logpath" + ". Errors: `n"
	            $message = $message + $errorLog
	        	NUnit.Assert $false $message
	        }
		}
		catch{
			WindowsBase.Log ("Unexpected error during parsing log [$logPath]:`n" + $Error)
		}
    }
    else
    {
        NUnit.Assert $false "test-path $logpath failed!"
    }
	WindowsBase.Log ("Parsing PwLog [$logPath] finished successfull.")
}

function PRM.ParseStubactLog{
    <#
        .SYNOPSIS
            Parse HDM stubact.log log file.
        .DESCRIPTION
            Parse HDM stubact.log log file. 
            If log is fine function returns 0 else function returns text message about errors.
        .PARAMETER  logPath
            Path to stubact.log Example: c:\tmp\stubact.log
        .EXAMPLE
            PS C:\> Test-QaPwLog c:\tmp\stubact.log
        .INPUTS
            System.String
        .OUTPUTS
            System.Int or System.String
    #>
    Param(
        $logPath
    )
	WindowsBase.Log ("Start parsing StubactLog: $logPath.")
    if(test-path ($logPath))
    {
		try{
	        $plainText = [system.io.file]::ReadAllText($logPath)
	        if ($plainText -match "\[Operation\]")
	        {
	            $allOperationList = ($plainText -split "\[Operation\]")
	            $allOperationList = $allOperationList[1..($allOperationList.Length - 1)]
	            
	            $operationList = @()
	            
	            foreach ($item in $allOperationList)
	            {
	                $isIgnore = $false
	                
	                $item = ($item -split "___")[0]
	                $item = ($item -split "\r\n#")[0]
	                
	                $item = $item -replace ">> ",""
	                $item = $item -replace " \r\n",""
	                $item = $item -replace "DiskVirtual:","DiskVM:"
	                $item = $item -replace "CopyToVirtual:","CopyToVirtualDisk:"
	                
	                
	                $item = $item -replace "RootEn.+\r\n",""
	                $item = $item -replace "Use alternate boot .+\r\n",""
	                $item = $item -replace "FSTyp.+\r\n",""
	                $item = $item -replace "\r\n",""
	                $item = $item -replace "Drive info.+\[Result\]","[Result]"
	        
	                #stupid checks
	                if ($item -match "Delete partition")
	                {
	                    $item = $item -replace "Error: 0 \(0x0\).+","Error: 0 (0x0)"
	                }
	                if ($item -match "Restore partition or disk")
	                {
	                    $item = $item -replace "One2One.+\[Target\]","[Target]"
	                }
	                if ($item -match "Set partition flags")
	                {
	                    $item = $item -replace "Letter:.+\[Parameters\]","[Parameters]"
	                }
	                if ($item -match "Copy partition")
	                {
	                    $item = $item -replace "Letter:.+\[Target\]","[Target]"
	                    $item = $item -replace "Letter:.+\[Parameters\]","[Parameters]"
	                }
	                if ($item -match "Backup partition")
	                {
	                    $item = $item -replace "\[Target index\].+\[Result\]","[Result]"
	                    $item = $item -replace "Letter: CBaseArchive:.+\[Result\]","[Result]"
	                }
	                #
	                
	                #List of operations to ignore
	                #"Error: 69643 (0x1100B)Restart is needed for operations completion" - ignore operation with restart code
	                #"Code: 344 (0x158)" - ignore set archive db operation in BS
	                $ignoreList = @("Error: 69643 \(0x1100B\)Restart is needed for operations completion", "Code: 344 \(0x158\)")
	                foreach ($ignore in $ignoreList)
	                {
	                    if ($item -match $ignore)
	                    {
	                        $isIgnore = $true
	                    }
	                }
	                
	                if (-not ($operationList -contains $item))
	                {
	                    if ($isIgnore -eq $false)
	                    {
	                        $operationList = $operationList + $item
	                    }
	                }
	            }
	            
	            $virtualList = @()
	            $realList = @()
	            foreach ($item in $operationList)
	            {
	                if ($item -match "Error: 0")
	                {
	                    if($item -match "Virtual: 0 \(0x0\)")
	                    {
	                        $item = $item -replace "Virtual: 0 \(0x0\)",""
	                        $realList = $realList + $item
	                    }
	                    if($item -match "Virtual: 1 \(0x1\)")
	                    {
	                        $item = $item -replace "Virtual: 1 \(0x1\)",""
	                        $virtualList = $virtualList + $item
	                    }
	                    
	                }
	                else
	                {
	                    NUnit.Assert $false ("Error in stubact " + $logPath + "`nOperation:`n" + $item)
	                }
	            }
	            
	            $virtualList = $virtualList | sort
	            $realList = $realList | sort
	            if ($realList.Length -gt 0)
	            {
	                $difference = Compare-Object -ReferenceObject $virtualList -DifferenceObject $realList -PassThru
	                if ($difference -ne $null)
	                {
	                   NUnit.Assert $false ("Comparing real and virtual operations failed. Difference:`n" + $difference)
	                }
	            }
	            else
	            {
	                NUnit.Assert $false "Number of real operations = 0"
	            }
	        }
	        else
	        {
	            NUnit.Assert $false "No operations found at all"
	        }
		}
		catch{
			WindowsBase.Log ("Unexpected error during parsing log [$logPath]:`n" + $Error)
		}
	}
    else
    {
        NUnit.Assert $false "test-path $logpath failed!"
    }
	WindowsBase.Log ("Parsing StubactLog [$logPath] finished successfull.")
}

function PRM.ParseHdmLog{
     <#
        .SYNOPSIS
            Parse HDM log file. (stubact or pwlog)
        .DESCRIPTION
            Parse HDM log file. (stubact or pwlog)
            If log is fine function returns 0 else function returns text message about errors.
        .PARAMETER  logPath
            Path to stubact.log Example: c:\tmp\stubact.log
        .PARAMETER  logType
            Possible values are: auto, stubact, pwlog
            auto: log type is detected by log name
            stubact: log type is set to parse log like stubact.log
            pwlog: log type is set to parse log like pwlog.txt
        .EXAMPLE
            PS C:\> Test-QaHdmLog c:\tmp\stubact.log
            PS C:\> Test-QaHdmLog -logPath c:\tmp\mylog.log -logType stubact
        .INPUTS
            System.String
            System.String
        .OUTPUTS
            System.Int or System.String
    #>
    Param(
        $logPath,
        $logType = "auto"
    )
    if($logType -eq "stubact")
    {
        return (PRM.ParseStubactLog $logPath)
    }
    if($logType -eq "pwlog")
    {
        return (PRM.ParsePwLog $logPath)
    }
    if($logType -eq "auto")
    {
        if($logPath -match "stubact.log")
        {
            return (PRM.ParseStubactLog $logPath)
        }
        if($logPath -match "pwlog.txt")
        {
            return (PRM.ParsePwLog $logPath)
        }
        NUnit.Assert $false "Can not detect HDM log by name. Use logType parameter in function"
    }
}

function PRM.StorageReport(){
	<#
        .SYNOPSIS
            Report of the storage
        .DESCRIPTION
            The report about the content of backup storage
        .PARAMETER  storageName
            Name of storage
		.PARAMETER  fullReport
            Type of report: full/short($true/$false)
        .EXAMPLE
            PS C:\> PRM.StorageReport "StorageName" $true
        .INPUTS
            System.String, System.Bool
        .OUTPUTS
            No output(Write to host)
    #>
	Param
	(
		[string] $storageName,
		[bool] $fullReport = $false
	)
	$storage = "$storageName" | gi prm::storages\ 
	$storageServerName = ($storage.Server)
	$storageServer =  gi prm::computers\$storageServerName
	$isDedup = ($storage.SibStorageHost -ne [Guid]::Empty)
	$t = "Storage: " + $storageName + "  StorageServer: " + $storageServerName + "  RAM: " + $storageServer.Hardware["RAM"]  + "  CPU: " + $storageServer.Hardware["CPU"] +`
	"`n  Path: " + $storage.Address + "  StorageType: " + $storage.MediumType + "  isDedup: " + $isDedup
	if($isDedup){ 
		$SibStorageServer = gi prm::computers  -Filter "id = $($storage.SibStorageHost)" 
		$t += "  SibStorageServer: " + $SibStorageServer.Name
		$t += "`n  SibStoragePath: " + $SibStorageServer.SibStorageParams.StoragePath + "  SibStorageBlockSize: " + (WindowsBase.FormatHumanReadable $SibStorageServer.SibStorageParams.BlockSize)
	}
	Write-Host $t	
	$t = "  Volumes: " + $storageServer.Hardware["Volumes"]	
	Write-Host $t
	$cataloges = gi prm::storages\"$storageName"\
	foreach($catalog in $cataloges){
		$t = "   Catalog: " + $catalog.name + "   SessionCount: " + $catalog.SessionCount + "   Size: " + (WindowsBase.FormatHumanReadable $catalog.Size)
		Write-Host $t
		$sessions =  gi ($catalog.PSPath + "\data_sessions\")
		if($fullReport){
			foreach($session in $sessions){
				$t = "      Created: " + $session.CreationTime + "  Daration: " + ($session.CompletionTime - $session.CreationTime) + `
				"   Size: " + (WindowsBase.FormatHumanReadable $session.Size)
				Write-Host $t
				$volumes = $session.Items
				foreach($volume in $volumes){
					if($volume.ItemType.ToString() -eq "Volume"){
						$DiskProperties = [hashtable]$volume.Properties["properties"]
						$DiskProperties.Keys | % {if($_.tostring()-eq "Letter"){$volumeLetterKey = $_}}
						$totalClusters = $volume.Properties["totalClusters"]
						$freeClusters = $volume.Properties["freeClusters"]
						$clusterSize = $volume.Properties["clusterSize"]
						$fileSystem = $volume.Properties["fileSystem"]
						$usedSpace = ($totalClusters - $freeClusters) * $clusterSize
						$freespace = $freeClusters * $clusterSize
						$totalSpace = $totalClusters * $clusterSize
						$t = "         " + $DiskProperties[$volumeLetterKey] + ":  " + $volume.ItemName +`
						"`n           " + "Total: " + (WindowsBase.FormatHumanReadable $totalSpace) + "  Used: " + (WindowsBase.FormatHumanReadable $usedSpace) + "  Free: " + (WindowsBase.FormatHumanReadable $freespace)
						Write-Host $t
					}
				}
			}
		}
	}
}

function PRM.StoragesReport(){
	<#
        .SYNOPSIS
            Report of the storage
        .DESCRIPTION
            The report about the content of backup storage
		.PARAMETER  fullReport
            Type of report: full/short($true/$false)
        .EXAMPLE
            PS C:\> PRM.StoragesReport $true
        .INPUTS
            System.Bool
        .OUTPUTS
            No output(Write to host)
    #>
	Param
	(
		[bool] $fullReport = $false
	)
	$storages = gi prm::storages
	foreach($storage in $storages){
		PRM.StorageReport $storage.Name $fullReport
	}
}

