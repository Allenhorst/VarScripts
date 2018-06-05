﻿
function PRM.AdminServer(){return (gi prm::computers -filter "role contains adminserver")}

function PRM.ConnectAdminServer(){
    connect-prmserver -name (PRM.AdminServer).Name
}

# replication components: "Directory, EventManager, CredentialsManager"
function PRM.Replicate($computer=$null, $Components = "Directory, CredentialsManager, EventManager, TaskManager", $timeout = 900) { 
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

function PRM.Wait-PolicyTask{
    Param(
        $policyTask,
        $waitTestLimit = [TimeSpan]::FromSeconds(3*60*60),
        [int] $delay = 5
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

function PRM.SubmitPolicy{
    Param
    (
        $policy_name, 
        [boolean] $wait = $true,
        $timeout = [TimeSpan]::FromSeconds(3*60*60)
    )    
    $policyTask = submit-prmpolicy (gi prm::Policies\$policy_name)
    if ($wait){
        start-sleep 2
        return (PRM.Wait-PolicyTask $policyTask $timeout)
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
    return (test-path prm::policies\$policy_name)
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
    $typeName = $prm_object.GetType().Name
    WindowsBase.Log ("---------------------" + $typeName + " " + $prm_object + "---------------------")
    WindowsBase.Log (($prm_object | Format-list) | Out-String)
    WindowsBase.Log ("------------- end of " + $typeName + " " + $prm_object + " info ---------------")
}

function PRM.GetEventErrorData{
    Param(
        $event
    )
    $eventErrorData = ""
    $eventMessage = $event.Message
    $eventData = [hashtable]$event.data
    if($eventData.Count -gt 0)
    {
        $eventDataString = "Events Error: `n"
        foreach($dataKey in $eventData.Keys){
            $eventDataString += $dataKey + ": " + $eventData[$dataKey] + "`n"
        }
        $eventErrorData = $eventMessage + "`r`n" + $eventDataString
    }
    return $eventErrorData
    
}
 

#Parse events(find whith error, and send failure assertion)
function PRM.ParseEvents(){
    $isEventListFine = $true
    WindowsBase.Log "Parse PRM events"
    foreach($item in (get-item prm::events\ -filter "type=Error")){
        $isEventListFine = $false
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
    
    WindowsBase.Log "Parse check integrity data"
    foreach($item in (get-item prm::events\ -filter "eventId=3059")){
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
        elseif($message -match "CHK_FAILED")
        {
            $eventOid = $item.EventOid
            NUnit.Assert $false "Found CHK_FAILED in check integrity event! Search event with EventOid=$eventOid in PRM journal for more details."
            $isEventListFine = $false
        }
    }
    
    if($isEventListFine)
    {
        WindowsBase.Log "Events are fine!"
    }
    return $isEventListFine
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
            $message = "Can't collect logs from: " + $agent.Name + "state: " + $agent.State + "`n"
            $message += WindowsBase.GetExceptionInfo
            NUnit.Assert $false $message
        }
    }
}

#Parse PRM log
function PRM.ParseLog{
    Param
    (
        [string] $prmlog
    )
    $skip_error_list = @(
                        "exception RemotingException: Requested Service not found    at System.Runtime.Remoting.Proxies.RealProxy.HandleReturnMessage",
                        "exception System.Xml.XmlException: Element 'prmSection' was not found.",
                        "exception System.IO.FileNotFoundException: Could not load file or assembly 'Prm.Agent.Common, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null' or one of its dependencies.",
                        "exception System.Xml.XmlException: 'None' is an invalid XmlNodeType."
                        )
    $errorMessages = @()
    
    #skip parsing for wix logs (bug 78118)
    if($prmlog -match "wix"){return $errorMessages}
    
    #parse windows events
    if($prmLog -match "WindowsEvents")
    {
        $xpath = "//*[EntryType='Error' and ./Message[contains(translate(., 'ABCDEFGHJIKLMNOPQRSTUVWXYZ', 'abcdefghjiklmnopqrstuvwxyz'),'prm.') or contains(translate(., 'ABCDEFGHJIKLMNOPQRSTUVWXYZ', 'abcdefghjiklmnopqrstuvwxyz'),'paragon')]]"
        $errorEventList = @()
        $errorEventList = [array](Select-Xml -Path $prmlog -XPath $xpath)
        if ($errorEventList.length -ge 1)
        {
            foreach($errorEvent in $errorEventList)
            {
                $message = "Error found in Windows Events. Log $prmlog" + "`n" + $errorEvent.Node.Message + "`n--------------------------------------------------------------------------`n`n"
                $errorMessages += $message
            }
        }
        return $errorMessages
    }
    
    #parse sqlite db
    if($prmLog.EndsWith(".db"))
    {
        try
        {
            WindowsBase.Log ("DB path $prmlog is found")
            $sqlUtilityPath = "$pwd\psg-search-password-in-sqlite-database-1.0.0.0\SearchPasswordInSqLiteDatabase.exe"
            if(-not (test-path $sqlUtilityPath)){$sqlUtilityPath = "$env:THIRDPARTY\psg-search-password-in-sqlite-database-1.0.0.0\SearchPasswordInSqLiteDatabase.exe"}
            if(-not (test-path $sqlUtilityPath)){$sqlUtilityPath = "c:\THIRDPARTY\psg-search-password-in-sqlite-database-1.0.0.0\SearchPasswordInSqLiteDatabase.exe"}
            if(test-path $sqlUtilityPath)
            {
                WindowsBase.Log ("Utility for searching $sqlUtilityPath is found.`nSearching passwords in $prmlog is started")
                $checkPasswordResult = &"$sqlUtilityPath" "$prmLog" "Qwerty123" "asdF5hh"
                if(-not ($checkPasswordResult -match "Life is good"))
                {
                    WindowsBase.Log ($checkPasswordResult)
                    $message = "Error! Password was found in sqlite database $prmLog Check TestLog for more details."
                    $errorMessages += $message
                }
                WindowsBase.Log ("Searching passwords in $prmlog is completed")
            }
        }catch
        {
            WindowsBase.Log ("Exception in check db for passwords")
            WindowsBase.LogExceptionInfo
        }
        return $errorMessages
    }
    
    [char]$flagI = 'I'
    [char]$flagD = 'D'
    [char]$flagE = 'E'
    [char]$flagC = 'C'
    [char]$flagW = 'W'
    [char]$flagV = 'V'
    $flag_list = @($flagI, $flagE, $flagD, $flagC, $flagW, $flagV)
    [string]$previousMessage = ""
    [string]$item = ""
    $allLines = [System.IO.File]::ReadAllLines($prmlog)
    for($i=0; $i -lt $allLines.Count; $i++) {
        $previousMessage = $item #($item -split '"')[1]
        $item = $allLines[$i]
        if ($item -eq $null) { break }
        # process the line
                        
        #  ========================  Additional information loggin ========================
        if ($item -match "Total changed chains [a-f\d]+, sectors 0x[a-f\d]+"){
            $message = "`n'total changed chains\sectors' info found"
            $message += "`n[path]$prmlog[/path]"
            $message += "`n[info]" + (($item -split '"')[1] -split '"')[0] + "[/info]`n"
            Write-Host $message
        }
        elseif ($item -match "Clusters [a-f\d]+ volume copy time [a-f\d]+ in [a-f\d]+ msec"){
            $message = "`n'clusters\copy time' info found"
            $message += "`n[path]$prmlog[/path]"
            $message += "`n[info]" + (($item -split '"')[1] -split '"')[0] + "[/info]`n"
            Write-Host $message
        }
        elseif ($item -cmatch "asdF5hh"){
            $message = "Password is found in logs!`n $item"
            $message += "`n[path]$prmlog[/path]"
            NUnit.Assert $false $message
            Write-Host $message
        }
        elseif ($item -cmatch "Qwerty123"){
            $message = "Password is found in logs!`n $item"
            $message += "`n[path]$prmlog[/path]"
            NUnit.Assert $false $message
            Write-Host $message
        }
        #  ========================  Additional information loggin ========================
            
        [int]$idx = $item.IndexOf(',')   # index of first comma char
        if($idx -lt 0) { 
            continue
        }
        $result = $item[$idx+1]
        if(($flag_list -notcontains $result) -or ($item[$idx+2] -ne ',')){
            continue
        }
        if (($result -eq $flagE) -or ($result -eq $flagC)){
            $idx = $item.IndexOf('"', $idx)    # index of first double quote char
            if($idx -lt 0) { 
                $message = "Log line with flag '$result' has no the message text`n $item" 
                $message += "`n[path]$prmlog[/path]"
                NUnit.Assert $false $message
                Write-Host $message
                continue
            }

            $message = $item.Substring($idx+1)
            $skip_error = $false
            foreach ($err in $skip_error_list){
                if ($message -match $err){
                    $skip_error = $true
                    break
                }
            }
                
            if(-not $skip_error){
                $message = `
                    "`n    Previous message:   " + $previousMessage`
                + "`n    Error message:      " + $item 

                $errorMessages += $message `
                + "`n    -----------------------------------------------------------------------------------------------------------------------------------`n"
            }
        }
    }
    if($errorMessages.Length -ne 0) { 
        $errorMessages = @("`n`n    |Founded in:         " `
        + [io.path]::GetFileName($prmlog) + "    |`n") + $errorMessages
    }
    # result 
    return $errorMessages
}

#find all events with attachments and parse logs from attachments
function PRM.ParseEventAttachment{
    Param(
        $startEventOid = $null,
        $endEventOid = $null,
        $reportPath = $null
    )
    WindowsBase.Log "Parse logs in events attachments"
    
    if($Results -eq $null){$Results = $env:Temp}
    
    #prm.management.log becomes too large - so we need to move it for catching bug 83073 
    
    try
    {
        WindowsBase.Log ("prm_log_path: $prm_log_path")
        $currentTime = (Get-Date).Ticks
        $logPath = "$results\PrmManagement_" + "$currentTime" + "_.log"
        
        WindowsBase.Log ("copy $prm_log_path to $logPath")
        copy-item $prm_log_path ("$results\PrmManagement_" + "$currentTime" + "_.log")
        WindowsBase.Log ("remove $prm_log_path")
        ri $prm_log_path
        if(test-path $prm_log_path)
        {
            WindowsBase.Log ("$prm_log_path was not removed")
        }
        else
        {
            WindowsBase.Log ("$prm_log_path was removed successfully")
        }
    }
    catch
    {
        WindowsBase.Log "shit-happens. cannot move $prm_log_path to $logPath"
        WindowsBase.LogExceptionInfo
    }
    
    
    $tmp_dir = ($Results + "\EventAttachmentTMP")
    if (Test-Path $tmp_dir) { $null = Remove-Item -Path $tmp_dir -Confirm:$false -Force:$true -Recurse:$true -ErrorAction:SilentlyContinue }
    [string] $summaryError = ""
    $event_table =@( 
        @{Expression={$_.eventOid}; Label="Oid";width=8},
        @{Expression={$_.eventId}; Label="ID";width=6},
        @{Expression={$_.type}; Label="Type";width=12},
        @{Expression={$_.componentFlag}; Label="Component";width=20},
        @{Expression={$_.policyName}; Label="Policy Name";width=48},
        @{Expression={$_.severity}; Label="Severity";width=10},
        @{Expression={$_.creationTime}; Label="Created";width=22},
        @{Expression={$_.targetComputerName}; Label="Target Computer Name";width=22},
        @{Expression={$_.sourceComputerName}; Label="Source Computer Name";width=22}
        )
    $shell_app=new-object -com shell.application
    $attachFilter = New-PRMEventSearchFilter HasAttachment -Equal $true
    
    $eventList = [array](gi prm::events -PrmFilters @($attachFilter))
    
    if($startEventOid -ne $null)
    {
        $eventList = [array]($eventList | where {$_.eventOid -ge $startEventOid})
    }
    if($endEventOid -ne $null)
    {
        $eventList = [array]($eventList | where {$_.eventOid -le $endEventOid})
    }
    
    foreach($event in $eventList){
        if($event -eq $null){break}
        
        $eventOid = $event.EventOid
        WindowsBase.Log ("Get attach for event $eventOid")
        #create tmp directory
        try
        {
            $null = New-Item $tmp_dir -ItemType directory
        }
        catch{WindowsBase.LogExceptionInfo}
        
        #check if attach is fine
        $filename = $null
        try
        {
            $filename = (Get-PRMEventAttachment $tmp_dir $event).Name
        }
        catch
        {
            $message = "Error! Cannot get attachment for EventOid $eventOid`n"
            $message += WindowsBase.GetExceptionInfo
            $summaryError += $message
        }
        
        #parse attach
        if($filename -ne $null)
        {
            try
            {
                if(Test-Path -Path "$tmp_dir\$filename"){
                    $zip_file = $shell_app.namespace("$tmp_dir\$filename")
                    $destination = $shell_app.namespace($tmp_dir)
                    $destination.Copyhere($zip_file.items())
                    #get and parse logs from temporary folder
                    $errorMessages = @()
                    foreach ($log in (gci "$tmp_dir" *.log -recurse)){
                        foreach($errMsg in (PRM.ParseLog $log.fullname)) {
                            $errorMessages += $errMsg
                        }
                    }
                    if($errorMessages.Length -ne 0){
                        $event_detail = ($event | Format-Table $event_table -Wrap | Out-String -Width 180)                        
                        $summaryError += "`------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------`n" `
                        + $event_detail.substring(2,$event_detail.Length-6)
                        foreach($errorMessage in $errorMessages){ $summaryError +=  $errorMessage }                    
                        $summaryError += "`------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------`n`n`n"
                    }
                }
                else
                { 
                    $message = "Attachment does not exists: $tmp_dir\$filename"
                    Write-Host $message
                    $summaryError += $message
                }
            }
            catch
            {
                WindowsBase.Log "Unexpected error occured while parsing event with eventOid = $eventOid"
                WindowsBase.LogExceptionInfo
                $summaryError += $message
            }
        }
        
        #remove tmp dir
        if(Test-Path $tmp_dir)
        {
            try
            {
                $null = Remove-Item -Path $tmp_dir -Confirm:$false -Force:$true -Recurse:$true
            }
            catch{WindowsBase.LogExceptionInfo}
        }
    }
    if($summaryError.Length -ne 0){
        WindowsBase.Log ("End parsing logs in events attachments: ==========  " + $summaryError)
        $summaryError = "`n`n`n`n`n`n----------------------------------------------------------------------- Parse event attachments logs -------------------------------------------------------------------------------`n" `
        + $summaryError
        if($reportPath -ne $null)
        {
            $summaryError | out-file $reportPath
        }
        NUnit.Assert $false $summaryError
    }
    WindowsBase.Log "End parsing logs in events attachments"
}

function PRM.ParseCollectedLogs{
    Param
    (
        [string] $path
    )
    WindowsBase.Log "Parse collected PRM logs"
    $tmp_dir = ($path + "\CollectedLogsTMP")
    if (Test-Path $tmp_dir) { $null = Remove-Item -Path $tmp_dir -Confirm:$false -Force:$true -Recurse:$true -ErrorAction:SilentlyContinue }
    [string] $summaryError = ""
    try{    
        $shell_app=new-object -com shell.application
        foreach ($zip in (Get-ChildItem $path *.zip -recurse)){
            $null = New-Item $tmp_dir -ItemType directory
            $zip_file = $shell_app.namespace($zip.fullname)
            $destination = $shell_app.namespace($tmp_dir)
            $destination.Copyhere($zip_file.items())
            #get and parse logs from temporary folder
            $errorMessages = @()
            foreach ($log in (gci $tmp_dir -include *.log,WindowsEvents*.xml,*.db -recurse)){
                foreach($errMsg in (PRM.ParseLog $log.fullname)) {
                    $errorMessages += $errMsg
                }
            }
            if($errorMessages.Length -ne 0){
                $summaryError += "`n---------------------------------------------- " + "Error message for:  " + $zip.BaseName + " ------------------------------------------------------"
                foreach($errorMessage in $errorMessages){
                    if($errorMessage -ne $null){ $summaryError +=  $errorMessage }
                }
                $summaryError += "-------------------------------------------------------- " + $zip.BaseName + " ----------------------------------------------------------------`n`n"
            }
            $null = Remove-Item -Path $tmp_dir -Confirm:$false -Force:$true -Recurse:$true
        }
    }
    catch{
        WindowsBase.Log ("Unexpected error during parsing logs!`n")
        WindowsBase.LogExceptionInfo
    }
    if($summaryError.Length -ne 0){
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
    #region get computers table
    $compprops = @(
        "Name",
        "Id",
        @{Name="Roles"; Expression={[string]::Join(" ", ($_.Role -join ", "))}},
        "State", 
        @{Name="Domain"; Expression={$_.Software.Domain}}, 
        @{Name="Workgroup"; Expression={$_.Software.Workgroup}}, 
        @{Name="Networks"; Expression={$_.Hardware.Networks}},
        @{Name="CPU"; Expression={$_.Hardware.CPU}},
        @{Name="RAM"; Expression={$_.Hardware.RAM}},
        @{Name="Volumes"; Expression={$_.Hardware.Volumes}},
        @{Name="OSVersion"; Expression={if ($_.Software["64-bit OS"] -eq "True") { $_.OSVersion + " x64" }else{ $_.OSVersion + " x86" }}},
        @{Name="Time zone"; Expression={$_.Software["Time zone"]}}
    )
    $computersTable = @()
    $_t = $false
    foreach($element in (gi prm::computers | Select-Object -Property $compprops | ConvertTo-HTML)) {
        if($element -eq "<table>"){$_t = $true}
        if($_t){$computersTable += $element}
        if($element -eq "</table>"){$_t = $false}
    }
        
    $computersTableString = @'
    <div id="comp" style="display: none">
        <form>
'@    + ($computersTable | Out-String) + "`n    </form></div>" 
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
    <script src="/js/jquery/jquery-1.11.1.min.js"></script>
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

    $eventprops = "eventOid","eventId","creationTime","type","severity","componentFlag","policyName","policyId","targetComputerName","targetComputerId","sourceComputerName","sourceComputerId","message","hasAttachment"
    $rez = @()
    foreach($event in (gi prm::events)){
        $obj = Select-Object -InputObject $event -Property $eventprops
        If($event.data.Count -gt 0){
            $str = ""
            foreach ($dataKey in $event.data.Keys ){ 
                try{ $str = [string]( $dataKey + ":`n" + $event.data[$dataKey]) }
                catch{ 
                    $str = [string]$dataKey  
                    WindowsBase.Log ("Cant get data for event with oid: " + $event.eventOid )
                    WindowsBase.LogExceptionInfo
                }
            }
            $obj.message = $obj.message + "`n" + $str
        }
        $rez += $obj
    }
    $html = $rez | ConvertTo-Html -Body $body -Head $head 

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
    foreach($element in $html) {
        if($element -match "<tr><th>"){$rh += $colHeader }
        elseif($element -match "<table>"){ $rh += $computersTableString ; $rh += '<table id="table_3" cellspacing="0" class="mytable" >' }
        elseif($element -match "<tr><td>"){
            $rowString = $element.Replace("`n","<br>")
            if($element -match "<td>Error</td>"){
                $rowString = $rowString.replace("<tr>","<tr class=`"datacellError`">")
            }
            elseif($element -match "<td>Warning</td>"){
                $rowString = $rowString.replace("<tr>","<tr class=`"datacellWarning`">")
            }
            if($element -match "<td>True</td></tr>" ){
                $indexStart =  $rowString.IndexOf("<td>") + 4
                $indexEnd = $rowString.IndexOf("</td><td>")
                $eventOid = $rowString.Substring($indexStart, ($indexEnd - $indexStart))
                $attachIndex = $rowString.IndexOf("<td>True</td></tr>")
                $link = '<a href="' + $adminServerName + ".zip%21/EventAttachments/event_" + $eventOid + '_files.zip">' + "True</a>"
                $rowString = $rowString.Substring(0, $attachIndex) + "<td>" + $link + "</td></tr>"
            }
            $rh += $rowString
        }
        elseif($element -match "</body>"){$rh += $postScripts ; $rh += $element }    
        else{ $rh += $element }
    }
    $rh | Out-File $path -Encoding "ASCII"
    WindowsBase.Log "Export PRM events finished."
    
    $outPath = join-path (split-path $path) "AutomaticTestAnalysis"
    try
    {
        if(-not (test-path $outPath))
        {
            mkdir $outPath
        }
        WindowsBase.Log "Save PRM keywords to $outPath is started."
        $keywordPath = join-path $outPath "Keywords.txt"
        $bugTemplatePath = join-path $outPath "BugTemplate.txt"
        $keywordResult = Prm.AddKeywordList $keywordPath $bugTemplatePath
        WindowsBase.Log "Save PRM keywords is finished."
        
        if($keywordResult -eq -1)
        {
            if( ((gi prm::computers -filter "role contains EsxAgent") -ne $null) -or `
                ((gi prm::computers -filter "role contains EsxStorageMedium") -ne $null) -or `
                ((gi prm::computers -filter "role contains NfsServer") -ne $null) )
            {
                $esxLogFolderPath = join-path (split-path $path) "esxLogs"
                if($TestHost -eq $null){$TestHost = $env:esx}
                if($TestHost -ne $null)
                {
                    $vs = Create-VServer $TestHost
                    $vs.GetVMHostLogs($esxLogFolderPath)
                }
                else{WindowsBase.Log "Cannot collect logs from Esx. Esx Host Name was not found"}
            }
        }
    }
    catch
    {
        WindowsBase.Log ("shit-happens. cannot save keywords.")
        WindowsBase.LogExceptionInfo
    }
    
    try
    {
        WindowsBase.Log "Save Task Performance Report to $outPath is started."
        $imagePath = join-path $outPath "TaskPerformance.png"
        Prm.AddTaskPerformanceReport $imagePath
        WindowsBase.Log "Save AutomaticTestAnalysis to $outPath is completed."
    }
    catch
    {
        WindowsBase.Log "shit-happens. cannot save task performance report."
        WindowsBase.LogExceptionInfo
    }
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
            $errorList = @("error")
            $ignoreList = @('Scanning directories and files for errors', 'file: "')
            
            [int]$errorCount = 0
            [string]$errorLog = ""
            
            foreach ($line in ([system.io.file]::ReadAllLines($logPath)))
            {
                [int]$lineErrorCount = 0
                foreach ($err in $errorList)
                {
                    $lineErrorCount += ([regex]::matches($line, $err)).count
                }
                [int]$lineIgnoreCount = 0
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
            WindowsBase.Log ("Unexpected error during parsing log [$logPath]:`n")
            WindowsBase.LogExceptionInfo
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
                    elseif ($item -match "Restore partition or disk")
                    {
                        $item = $item -replace "One2One.+\[Target\]","[Target]"
                    }
                    elseif ($item -match "Set partition flags")
                    {
                        $item = $item -replace "Letter:.+\[Parameters\]","[Parameters]"
                    }
                    elseif ($item -match "Copy partition")
                    {
                        $item = $item -replace "Letter:.+\[Target\]","[Target]"
                        $item = $item -replace "Letter:.+\[Parameters\]","[Parameters]"
                    }
                    elseif ($item -match "Backup partition")
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
                            $realList += $item
                        }
                        elseif($item -match "Virtual: 1 \(0x1\)")
                        {
                            $item = $item -replace "Virtual: 1 \(0x1\)",""
                            $virtualList += $item
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
            WindowsBase.Log ("Unexpected error during parsing log [$logPath]:`n")
            WindowsBase.LogExceptionInfo
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

function PRM.StorageListReport{
    write-host("##teamcity[blockOpened name='StorageListReport']")
    
    $storageList = [array](gi prm::storages)
    foreach($storage in $storageList)
    {
        if(-not $storage){break}
        PRM.StorageReport $storage.Name
    }
    
    write-host("##teamcity[blockClosed name='StorageListReport']")
}

function PRM.StorageReport{
    Param
    (
        [string] $storageName
    )
    try
    {
        $storage = gi prm::storages\$storageName 
        if($storage)
        {
            PRM.Log $storage
            
            $catalogList = [array](gi prm::storages\"$storageName"\)
            foreach($catalog in $catalogList)
            {
                if(-not $catalog){break}
                PRM.Log $catalog
                
                $sessionList = [array]$catalog.GetSessions()
                foreach($session in $sessionList)
                {
                    if(-not $session){break}
                    PRM.Log $session
                }
            }
        } 
    }
    catch
    {
        WindowsBase.Log "shit happens in PRM.StorageReport"
        WindowsBase.LogExceptionInfo
    }
}

function Prm.AddKeywordList{
    Param(
        $keywordPath,
        $bugTemplatePath = $null
    )
    $infoList = @()
    #event description
    #101  - Add computer
    #102  - Update computer
    #107  - Add policy
    #108  - Update policy* bug 76996
    #117  - Add rule
    #118  - Update rule* bug 76996
    #121  - Assign rule to policy
    #124  - Update storage
    #125  - Add storage
    #174  - Set credential
    #228  - Update computer Address
    #3019 - Create data catalog
    #3022 - Update data catalog
    
    #not used
    #128 - Create Task
    #129 - Submit Task
    #130 - Run Task
    #136 - Task is finished
    
    #write-host "gathering events is started"
    #$topEventList = @(gi prm::events -Filter "EventId=101; EventId=102; EventId=107; EventId=108; EventId=117; EventId=121; EventId=124; EventId=125; EventId=174; EventId=3019; EventId=3022" -sortby "EventOid")
    #write-host "gathering events is finished"
    
    #keywords to collect
    $roleAgentNameList = @()
    $credentialTypeList = @()
    $storageTypeList = @()
    
    $policyTypeRuleTypeList = @()
    $policyNameList = @()
    $ruleTypeList = @()
    $policyTypeList = @()
    $componentMaskList = @()
    $componentMaskPolicyTypeList = @()
    
    #dictionary for collecting info
    [hashtable]$policyIdPolicyTypeDict = @{}
    [hashtable]$storageIdStorageTypeDict = @{}
    [hashtable]$policyIdComponentMaskDict = @{}
    [hashtable]$catalogIdCatalogNameDict = @{}
    [hashtable]$ruleIdPolicyIdDict = @{}
    
    #prm object description
    [hashtable]$idDescriptionDict = @{}
    
    #work with policy events
    foreach ($event in (gi prm::events -Filter "EventId=107; EventId=108" -sortby "EventOid"))
    {
        if($event -eq $null){break}
        $eventId = $event.EventId
        $eventOid = $event.EventOid
        try
        {
            #get policy info
            $values = @($event.data.Values)
            $policyInfo = $values[0]
            
            #get policy name
            $policyName = $policyInfo.Name
            if($policyName -ne $null)
            {
                $policyNameList += ("PolicyName_" + $policyName)
            }
            
            #get policy Id
            $policyId = $policyInfo.Id.GUID
            
            #get policy Type
            $policyType = $policyInfo.type
            
            #get componentMask
            $componentMask = $policyInfo.componentMask
            
            #add info to dictionaries for use in other events
            $policyIdComponentMaskDict[$policyId] = $componentMask
            $policyIdPolicyTypeDict[$policyId] = $policyType
            
            $policyTypeList += ("PolicyType_" + $policyType)
            $componentMaskList += ("ComponentMask_" + $componentMask)
            $componentMaskPolicyTypeList += ("ComponentMaskPolicyType_" + $componentMask + "_" + $policyType)
        }
        catch
        {
            WindowsBase.Log "shit happens in PRM.AddKeywordList EventId=$eventId EventOid = $eventOid"
            WindowsBase.LogExceptionInfo
        }
    }
    
    foreach ($event in (gi prm::events -Filter "EventId=121" -sortby "EventOid"))
    {
        if($event -eq $null){break}
        $eventId = $event.EventId
        $eventOid = $event.EventOid
        try
        {
            #get policy Id
            $policyId = $event.PolicyId
            
            #get rule Id
            $message = $event.message
            $ruleId = (($message -split "rule name = ")[-1] -split ",")[0]
            
            $ruleIdPolicyIdDict[$ruleId] = $policyId.guid
        }
        catch
        {
            write-host "shit happens in PRM.AddKeywordList EventId=$eventId EventOid = $eventOid"
            WindowsBase.LogExceptionInfo
        }
    }
    
    #work with computer events
    foreach($event in (gi prm::events -Filter "EventId=101; EventId=102" -sortby "EventOid"))
    {
        if($event -eq $null){break}
        $eventId = $event.EventId
        $eventOid = $event.EventOid
        try
        {
            #get computer info list
            $values = @($event.data.Values)
            $value = $values[0]
            $computerInfoList = [array]($value.eventObject)
            
            #get info from computer list
            foreach($computerInfo in $computerInfoList)
            {
                #get agent role
                $roleString = $computerInfo.role
                
                #get agentName
                $agentName = [string]$computerInfo.Address
                $agentId = $computerInfo.Id.GUID
                if((([bool]($agentName -as [ipaddress])) -or ($agentName -match "minint")) -or ($roleString -match "Recovery"))
                {
                    $agentName = "WinPE"
                }
                else
                {
                    #remove agent suffix
                    $agentName = $agentName.ToLower()
                    $suffix = $agentName.Substring($agentName.Length - 3, 3)
                    if($suffix -match "-\d\d")
                    {
                        $agentName = $agentName.Substring(0, $agentName.Length - 3)
                    }
                }
                
                #add for fakes in 700 test
                if($agentName -match "fake")
                {
                    $agentName = "fakecomputer"
                }
                
                #generate keyword
                [hashtable]$computerDict = @{}
                $computerDict["ObjectType"] = "Agent"
                $computerDict["Name"] = $agentName
                $computerDict["Role"] = $roleString
                $computerDict["Description"] = "Agent: Name='" + $agentName + "'. Role='" + $roleString + "'. Id='" + $agentId + "'"
                $idDescriptionDict[$agentId] = $computerDict

                $agentRoleList = ([array](([String]($roleString) -replace "\s","") -split ","))
                foreach($agentRole in $agentRoleList)
                {
                    $roleAgentNameList += ("RoleAgentName_" + $agentRole + "_" + $agentName) 
                }
            }
        }
        catch
        {
            WindowsBase.Log "shit happens in PRM.AddKeywordList EventId=$eventId EventOid = $eventOid"
            WindowsBase.LogExceptionInfo
        }
    }
    
    #work with storage events
    foreach($event in (gi prm::events -Filter "EventId=124; EventId=125" -sortby "EventOid"))
    {
        if($event -eq $null){break}
        $eventId = $event.EventId
        $eventOid = $event.EventOid
        try
        {
            #get storage info
            if($event.data -ne $null)
            {
                $values = @($event.data.Values)
                $value = $values[0]
                $storageInfo = $value.eventObject
                
                #get storage type
                $mediumType = $storageInfo.mediumtype
                $dedupPrefix = ""
                $encryptedPrefix = ""
                if($storageInfo.properties.SibStorageId -ne $null)
                {
                    $dedupPrefix = "Dedup"
                }
                
                if($storageInfo.properties.Encryption -ne $null)
                {
                    $encryptedPrefix = "Encrypted"
                }
                #add info to dictionary for other events
                $storageId = $storageInfo.Id.GUID
                if(($mediumType -ne $null) -and ($storageId -ne $null))
                {
                    $mediumType = $encryptedPrefix + $dedupPrefix + $mediumType
                    $storageIdStorageTypeDict[$storageId] = $mediumType
                    
                    [hashtable]$storageDict = @{}
                    $storageDict["ObjectType"] = "Storage"
                    $storageDict["Name"] = $storageInfo.Name
                    $backupServerId = $storageInfo.computerId.GUID
                    $storageDict["BackupServerName"] = $idDescriptionDict[$backupServerId]["Name"]
                    $storageDict["Type"] = $mediumType
                    $storageDict["Description"] = "Storage: Name='" + $storageInfo.Name + "'. MediumType='" + $mediumType + "'. BackupServerName='" + $idDescriptionDict[$backupServerId]["Name"] + "'. StorageId=" + $storageId + "'"
                    
                    $idDescriptionDict[$storageId] = $storageDict
                }
            }
        }
        catch
        {
            WindowsBase.Log "shit happens in PRM.AddKeywordList EventId=$eventId EventOid = $eventOid"
            WindowsBase.LogExceptionInfo
        }
    }
    foreach($key in $storageIdStorageTypeDict.Keys)
    {
        if($key -eq $null){break}
        $storageTypeList += ("Storage_" + $storageIdStorageTypeDict[$key])
    }
    
    #work with credential events
    foreach($event in (gi prm::events -Filter "EventId=174" -sortby "EventOid"))
    {
        if($event -eq $null){break}
        $eventId = $event.EventId
        $eventOid = $event.EventOid
        try
        {
            $message = $event.message
            $type = ($message -split "type = ")[-1]
            $type = ($type -split ",")[0]
            $credentialTypeList = $credentialTypeList + ("CredentialType_" + $type)
            
            $credentialDict = @{}
            $credentialDict["ObjectType"] = "Credential"
            $credentialDict["EventOid"] = $eventOid
            $message = ($message -split "successfull: ")[1]
            $credentialDict["Description"] = "Credential: " + $message
            
            $idDescriptionDict[$eventOid] = $credentialDict
        }
        catch
        {
            WindowsBase.Log "shit happens in PRM.AddKeywordList EventId=$eventId EventOid = $eventOid"
            WindowsBase.LogExceptionInfo
        }
    }
    
    #work with catalog events
    foreach($event in (gi prm::events -Filter "EventId=3019; EventId=3022" -sortby "EventOid"))
    {
        if($event -eq $null){break}
        $eventId = $event.EventId
        $eventOid = $event.EventOid
        try
        {
            $values = @($event.data.Values)
            $value = $values[0]
            $catalogInfo = $value.eventObject
            $catalogName = $catalogInfo.name
            $catalogName = $catalogName.ToLower()
            $catalogId = $catalogInfo.Id.GUID
            
            $suffix = $catalogName.Substring($catalogName.Length - 3, 3)
            if($suffix -match "-\d\d")
            {
                $catalogName = $catalogName.Substring(0, $catalogName.Length - 3)
            }
            $catalogIdCatalogNameDict[$catalogId] = $catalogName
        }
        catch
        {
            WindowsBase.Log "shit happens in PRM.AddKeywordList EventId=$eventId EventOid = $eventOid"
            WindowsBase.LogExceptionInfo
        }
    }
    
    #work with tasks now
    foreach($task in Get-PrmTasks)
    {
        if($task -eq $null){break}
        try
        {
            $policy = $task.GetPolicy()
            $policyId = $policy.Id.GUID
            $policyName = $policy.Name

            $componentMask = $policy.ComponentMask
           
            $policyType = $policy.PolicyType
            $policyTypeString = $policyType.ToString()

            if(($policyTypeString -eq "StorageTicket") -or ($policyTypeString -eq "NfsServerMount")) {continue}

            $ruleList = @($policy.Rules)
            $ruleTypeList = @()
            
            foreach($rule in $ruleList)
            {
                if($rule -eq $null) {break}
                $ruleTypeList += $rule.RuleType
            }
            
            if($policyType -eq "Maintenance")
            {
                if($ruleTypeList -contains "CheckIntegrity")
                {
                    $policyTypeString = "Maintenance(CheckIntegrity)"
                }
                else
                {
                    $policyTypeString = "Maintenance(Retention)"
                }
            }
            
            [hashtable]$policyDict = @{}
            $policyDict["ObjectType"] = "Policy"
            $policyDict["Name"] = $policyName
            if($policyName -eq $null)
            {
                $policy
            }
            $policyDict["Type"] = $policyTypeString
            $policyDict["ComponentMask"] = $componentMask
            $policyDict["ComputerList"] = ""
            $policyDict["SubmitParameters"] = ""
            $computerGuidList = [array]($policy.Computers)
            foreach($computerGuid in $computerGuidList)
            {
                if($computerGuid -eq $null){break}
                $agentId = $computerGuid.GUID
                $policyDict["ComputerList"] += $idDescriptionDict[$agentId]["Name"]
            }
            $policyDict["RuleList"] = "`n"
            
            foreach($rule in $ruleList)
            {
                if($rule -eq $null){break}
                $ruleType = $rule.RuleType
                $ruleDescription = "$ruleType"
                $keywordDescription = "Task_" + $componentMask +"_" + $policyTypeString + "_" + $ruleType
                
                if($ruleType -eq "BackupStorage")
                {
                    $storageId = $rule.parameters.GUID
                    $prefix = "From"
                    if($policyType -eq "Backup")
                    {
                        $prefix = "To"
                    }
                    $keywordDescription += ("_$prefix" + $storageIdStorageTypeDict[$storageId])
                    $ruleDescription += ("_$prefix" + $idDescriptionDict[$storageId]["Name"])
                }
                
                if($ruleType -eq "BackupCatalog")
                {
                    $catalogId = $rule.parameters.GUID
                    $catalogName = $catalogIdCatalogNameDict[$catalogId]
                    $catalogName = $catalogName.ToLower()
                    $keywordDescription += ("_" + $catalogName)
                    $ruleDescription += ("_" + $catalogName)
                }
                
                if($ruleType -eq "EsxVmProtection")
                {
                    $vmTargetName = "undefined"
                    if($rule.parameters.itempath -ne $null)
                    {
                        $vmTargetName = ((($rule.parameters.itempath)[-1]) -split ("_"))[-1]
                    }
                    elseif($rule.parameters.vmselection.filter -ne $null)
                    {
                        $vmTargetName = $rule.parameters.vmselection.filter.tostring()
                    }
                    $vmTargetName = $vmTargetName.ToLower()
                    
                    $suffix = $vmTargetName.Substring($vmTargetName.Length - 3, 3)
                    if($suffix -match "-\d\d")
                    {
                        $vmTargetName = $vmTargetName.Substring(0, $vmTargetName.Length - 3)
                    }
                    
                    $keywordDescription += ("_" + $vmTargetName)
                    $ruleDescription += ("_" + $vmTargetName)
                }
                
                if($ruleType -eq "ArchiveStorage")
                {
                    $baseStorageId = $rule.parameters.storageId.GUID
                    $archiveStorageId = $rule.parameters.archiveStorageId.GUID
                    $baseStorageType = $storageIdStorageTypeDict[$baseStorageId]
                    $archiveStorageType = $storageIdStorageTypeDict[$archiveStorageId]
                    $keywordDescription += ("_From" + $baseStorageType + "To" + $archiveStorageType)
                    $ruleDescription += ("_From" + $idDescriptionDict[$baseStorageId]["Name"] + "To" + $idDescriptionDict[$archiveStorageId]["Name"])
                }
                
                if($ruleType -eq "ExportedStorage")
                {
                    $storageId = $rule.parameters.GUID
                    $keywordDescription += ("_From_" + $storageIdStorageTypeDict[$storageId])
                    $ruleDescription += ("_From" + $idDescriptionDict[$storageId]["Name"])
                }
                
                if($ruleType -eq "ExportedCatalog")
                {
                    $catalogId = $rule.parameters.GUID
                    $catalogName = $catalogIdCatalogNameDict[$catalogId]
                    $catalogName = $catalogName.ToLower()
                    $keywordDescription += ("_" + $catalogName)
                    $ruleDescription += ("_" + $catalogName)
                }
                
                if($ruleType -eq "RebuildStorage")
                {
                    $storageId = $rule.parameters.GUID
                    $keywordDescription += ("_" + $storageIdStorageTypeDict[$storageId])
                    $ruleDescription += ("_" + $idDescriptionDict[$storageId]["Name"])
                }
                
                if($ruleType -eq "MaintainedStorages")
                {
                    $storageGuidList = [array]($rule.parameters)
                    foreach($storageGuid in $storageGuidList)
                    {
                        $storageId = $storageGuid.GUID
                        $keywordDescription += ("_" + $storageIdStorageTypeDict[$storageId])
                        $ruleDescription += ("_" + $idDescriptionDict[$storageId]["Name"])
                    }
                }
                
                if($ruleType -eq "MaintenanceMode")
                {
                    $keywordDescription += ("_" + $rule.Parameters)
                    $ruleDescription += ("_" + $rule.Parameters)
                }
                
                if($ruleType -eq "VolumeProtection")
                {
                    $computerGuidList = [array]($policy.Computers)
                    foreach($computerGuid in $computerGuidList)
                    {
                        $catalogId = $computerGuid.GUID
                        if($catalogIdCatalogNameDict[$catalogId] -ne $null)
                        {
                            $keywordDescription += ("_" + $catalogIdCatalogNameDict[$catalogId])
                        }
                    }
                }
                
                if($ruleType -eq "ExportStorageParameters")
                {
                    $encrypted = ""
                    if($rule.parameters.Encryption -ne $null)
                    {
                        $encrypted = "Encrypted"
                    }
                    
                    $virtualDiskFormat = $rule.parameters.VirtualDiskParams.Format
                    
                    $keywordDescription += ("_To_" + $encrypted + $virtualDiskFormat)
                    $ruleDescription += ("_To_" + $encrypted + $virtualDiskFormat)
                }
                
                $policyTypeRuleTypeList += $keywordDescription
                $policyDict["RuleList"] += ("        " + $ruleDescription + "`n")
            }
            
            #work with policy params
            $paramDict = [hashtable] $task.Parameters
            foreach($key in $paramDict.Keys)
            {
                if($key -eq $null){break}
                $policyDict["SubmitParameters"] += (" " + $key + "='" + $paramDict[$key] + "';")
            }
            if($policyDict["SubmitParameters"] -eq "")
            {
                $policyDict["SubmitParameters"] = " 'None'"
            }
            
            $policyDict["Description"] = "Policy '" + $policyName + "'`r`n    Id='" + $policyId + "'`r`n    Type='" + $policyTypeString + "'`r`n    ComponentMask='" + $componentMask + "'`r`n    Computers='" + $policyDict["ComputerList"] + "'.`r`n    Rules:" + $policyDict["RuleList"] + "'"
            $idDescriptionDict[$policyId] = $policyDict
            
            if($task.StartTime -ne $null)
            {
                [hashtable]$taskDict = @{}
                $taskDict["Date"] = get-date($task.StartTime)
                $taskDict["Message"] = $taskDict["Date"].ToString() + ", " + "Task is Started : PolicyName='" + $policyName + "' Id='" + $policyId + "' Type='" + $policyTypeString + "' SubmitParameters:" + $policyDict["SubmitParameters"]
                $infoList += $taskDict
            }
            if($task.FinishTime -ne $null)
            {
                [hashtable]$taskDict = @{}
                $taskDict["Date"] = get-date($task.FinishTime)
                $resultStatus = $task.ResultStatus
                $taskDict["Message"] = $taskDict["Date"].ToString() + ", " + "Task is Finished: ResultStatus='" + $resultStatus + "' PolicyName='" + $policyName + "' Id='" + $policyId + "' Type='" + $policyTypeString + "' SubmitParameters:" + $policyDict["SubmitParameters"]
                $infoList += $taskDict
            }
        }
        catch
        {
            WindowsBase.Log "shit happens in task parsing"
            WindowsBase.LogExceptionInfo
        }
    }
    
    $descriptionList = @()
    foreach($key in $idDescriptionDict.Keys)
    {
        $descriptionList += $idDescriptionDict[$key]
    }

    $descriptionCredentialList = [array]($descriptionList | where {$_["ObjectType"] -eq "Credential"})
    $descriptionAgentList = [array]($descriptionList | where {$_["ObjectType"] -eq "Agent"})
    $descriptionStorageList = $descriptionList | where {$_["ObjectType"] -eq "Storage"}
    $descriptionPolicyList = $descriptionList | where {$_["ObjectType"] -eq "Policy"}
    
    $descriptionCredentialList = [array]($descriptionCredentialList | sort-object {$_["EventOid"]})
    $descriptionAgentList = [array]($descriptionAgentList | sort-object {$_["Name"]})
    $descriptionStorageList = [array]($descriptionStorageList | sort-object {$_["Name"]})
    $descriptionPolicyList = [array]($descriptionPolicyList | sort-object {$_["Name"]})
    
    $descriptionList = $descriptionCredentialList + $descriptionAgentList + $descriptionStorageList + $descriptionPolicyList
    #save event Errors
    $errorInfoList = @()

    foreach($errorEvent in (get-item prm::events -filter "type=Error" -sortby "EventOid"))
    {
        if($errorEvent -eq $null){break}
        [hashtable]$errorEventDict = @{}
        $errorEventDict["Date"] = get-date($errorEvent.CreationTime)
        $policyId = $errorEvent.PolicyId.GUID
        $policyName = ""
        if($idDescriptionDict.Keys -contains $policyId)
        {
            $policyName = $idDescriptionDict[$policyId]["Name"]
        }
        $errorEventDict["Message"] = $errorEventDict["Date"].ToString() + ", PolicyName='" + $policyName + "'. PolicyId='" + $policyId + "'`r`n" + (PRM.GetEventErrorData $errorEvent)
        $errorInfoList += $errorEventDict
    }

    #save results
    $data = @()
    $deskDescription = ""
    $stepsToReproduce = ""
    $actualResults = ""
    
    #get buildNumber
    $buildNumber = "unknown"
    try
    {
        $pc = ([array](gi prm::computers))[0]
        $key = @($pc.PrmPackagesVersions.Keys)[0]
        $buildNumber = $pc.PrmPackagesVersions[$key].ToString()
    }
    catch
    {
        WindowsBase.Log "Can not detect build number. (Most possible reason - bug 78214 with build number detection for PRM on Linux)"
        WindowsBase.LogExceptionInfo -writeError $false
    }
    
    #save to disk
    try
    {
        $data += ($roleAgentNameList + $storageTypeList + $credentialTypeList + $policyTypeRuleTypeList + $policyNameList)
        $data = [array]($data | select -uniq | sort)
        $data | out-file $keywordPath -Encoding "ASCII"
        
        #generate Bug Template
        $infoList = [array]($infoList | sort-object { $_["Date"] })
        $errorInfoList = [array]($errorInfoList | sort-object { $_["Date"] })
        foreach($description in $descriptionList)
        {
            if($description -eq $null){break}
            $deskDescription += ($description["description"]  + "`r`n")
        }
        foreach($info in $infoList)
        {
            if($info -eq $null){break}
            $stepsToReproduce += ($info["Message"] + "`r`n")
        }
        foreach($info in $errorInfoList)
        {
            if($info -eq $null){break}
            $actualResults += ($info["Message"] + "`r`n")
        }
        
        $bugTemplate = 'BRIEF:

BUILD_NUMBER:
' + $buildNumber + '

STEPS_TO_REPRODUCE:
' + $stepsToReproduce + '
ACTUAL_RESULTS:
' + $actualResults + '
EXPECTED_RESULTS:

DESK_DESCRIPTION:
' + $deskDEscription + '
LOG_QUATATION:

ADDITIONAL_INFO:'
        
        if($bugTemplatePath -ne $null)
        {
            $bugTemplate  | out-file "$bugTemplatePath" -Encoding "ASCII"
            if($errorInfoList -ne $null)
            {
                if($errorInfoList[0] -ne $null){ return -1 } else { return 0 }
            }
        }
    }
    catch
    {
        WindowsBase.Log "shit happens in PRM.AddKeywordList #save to file $keywordPath"
        WindowsBase.LogExceptionInfo
    }
}

function Prm.AddTaskPerformanceReport{
    Param(
        $imagePath
    )
    try
    {
        #Get Prm Data from tasks DB
        $nameList = @()
        $durationList = @()
        $timingList = @()
        $taskList = @()
        
        $taskList = [array](Get-PrmTasks)
        $taskList = [array]($taskList | where {$_.StartTime -ne $null})
        $taskList = ($taskList | Sort-Object StartTime)
        
        $taskIsErrorList = @()
        $taskIsValidationLevelList = @()
        
        $totalTaskDuration = 0
        $testDuration = 0
        
        foreach($task in $taskList)
        {
            $isError = 0
            $isValidate = 0
            
            $policy = $task.GetPolicy()
            $policyName = $policy.Name
           
            $policyType = $policy.PolicyType
            $policyTypeString = $policyType.ToString()
            
            if($policyName -eq $null)
            {
                $policyName = "PolicyName = Null. PolicyType = $policyTypeString"
            }
            
            if(($policyTypeString -eq "StorageTicket") -or ($policyTypeString -eq "NfsServerMount")) {continue}
            
            if(-not(Prm.IsTaskFinishedSuccessfully $task))
            {
                $policyName += (" (ResultStatus=" + $task.ResultStatus + "; State="+ $task.State + ")")
                $isError = 1
            }
            
            $validateLevel = Prm.GetTaskValidationLevel $task
            if($validateLevel -ne $null)
            {
                $policyName += (" (Validation=" + $validateLevel + ")")
                $isValidate = 1
            }
            
            if($task.FinishTime -ne $null)
            {
                $duration = ($task.FinishTime - $task.StartTime).TotalSeconds
                if($duration -lt 0)
                {
                    $isError = 1
                    $policyName += (" (Task duration is negative!)")
                }
            }
            else
            {
                $duration = ((Get-Date).ToUniversalTime() - $task.StartTime).TotalSeconds
                $policyName += (" (Task was not completed!)")
            }
            
            
            $durationList += $duration
            $nameList += $policyName
            $taskIsErrorList += $isError
            $taskIsValidationLevelList += $isValidate
            
            $timing = ($task.StartTime - $taskList[0].StartTime).TotalSeconds
            $timingList += $timing
            
            $currentDuration = $timing + $duration
            if($currentDuration -gt $testDuration)
            {
                $testDuration = $currentDuration
            }
            $totalTaskDuration += $duration
        }
        
        $parallelMetric = $totalTaskDuration / $testDuration
        $parallelMetric = "$parallelMetric"
        #done 
        
        #Create chart
        [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
        [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
        
        $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart 
        
        $taskNumber = $nameList.Length
        $Chart.Width = 30 * $taskNumber + 50
        if($Chart.Width -lt 1000)
        {
            $Chart.Width = 1000
        }
        $Chart.Height = 800 
        $Chart.Left = 0 
        $Chart.Top = 0
        
        $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea 
        $Chart.ChartAreas.Add($ChartArea)
        
        [void]$Chart.Series.Add("Data1")
        [void]$Chart.Series.Add("Data2")
        
        $Chart.Series["Data1"].Points.DataBindXY($nameList, $durationList)
        $Chart.Series["Data2"].Points.DataBindXY($nameList, $timingList)
        
        #set different colors for different task resultstatus\state
        $counter = 0
        while($counter -lt $taskIsErrorList.Length)
        {
            $Chart.Series["Data1"].Points[$counter].Color = "Green"
            if($taskIsValidationLevelList[$counter] -eq 1)
            {
                $Chart.Series["Data1"].Points[$counter].Color = "DeepSkyBlue"
            }
            if($taskIsErrorList[$counter] -eq 1)
            {
                $Chart.Series["Data1"].Points[$counter].Color = "Red"
            }
            $counter++
        }
        
        $Chart.Series["Data2"].ChartType = "Point"
        $Chart.Series["Data2"].Color = "Black"
        $Chart.Series["Data2"].YAxisType = "Secondary"
        
        # display the chart on a form 
        $Chart.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right -bor 
                        [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left 
        $Form = New-Object Windows.Forms.Form 
        $Form.Text = "PRM Task Performance" 
        $Form.Width = $Chart.Width - 50 
        $Form.Height = 750 
        
        # add title and axes labels 
        $ChartArea.AxisX.Interval = 1
        
        $ChartArea.AxisX.Title = "Policy names sorted by StartTime. TotalTaskDuration/TestDuration = $parallelMetric"
        $ChartArea.AxisY.Title = "Task duration in seconds (Bars). Green=SuccessfullyFinished. Blue=Validation. Red=Failed."
        $ChartArea.AxisY2.Title = "Task start in seconds (Points)"
    
        $ChartArea.AxisY2.MajorGrid.LineDashStyle = "NotSet"
        
        $Chart.SaveImage("$imagePath", "PNG")
    }
    catch
    { 
        WindowsBase.Log ("Exception occured during image saving") 
        WindowsBase.LogExceptionInfo
    }
    
}

function Prm.IsTaskFinishedSuccessfully{
    Param(
        $task
    )
    $isTaskFine = $false
    if($task.ResultStatus -eq "Success")
    {
        if($task.State -eq "Finished")
        {
            $isTaskFine = $true
        }
    }
    
    if($task.ResultStatus -eq "None")
    {
        if($task.State -eq "Scheduled")
        {
            $isTaskFine = $true
        }
    }
    return $isTaskFine
}

function Prm.GetTaskValidationLevel{
    Param(
        $task
    )
    $submitParameters = ""
    
    $paramDict = [hashtable] $task.Parameters
    foreach($key in $paramDict.Keys)
    {
        if($key -eq $null){break}
        $submitParameters += ($key.ToString() + "=" + $paramDict[$key].ToString())
    }
    if($submitParameters -match "Validation=Low")
    {
        return "Low"
    }
    if($submitParameters -match "Validation=Medium")
    {
        return "Medium"
    }
    if($submitParameters -match "Validation=High")
    {
        return "High"
    }
    
    return $null
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
