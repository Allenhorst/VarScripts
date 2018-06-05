function Test-Chkdsklog($chkdskData){
    
    $data = $chkdskData
    
    $error_list = @('epair', 'orphane', 'Fixing incorrect information', 'points to unused file', "Correcting errors in the master file table's (MFT) DATA attribute")
    $count = 0
    
    foreach ($err in $error_list){
        $count = $count + ([regex]::matches($data, $err).count)
    }
    
    #check for forced chkdsk volumes
    $count = $count + ([regex]::matches($data, 'valid').count) - ([regex]::matches($data, 'opened handles to this volume are now invalid').count)
    
    #stupid check - need to use this for win7
    $count = $count + ([regex]::matches($data, 'ecover').count) - ([regex]::matches($data, '0 unindexed files recovered').count) - ([regex]::matches($data, 'Volume label is Recovery.').count)
    
    $count = $count + ([regex]::matches($data, 'orrupt').count) - ([regex]::matches($data, 'might report errors when no corruption is present').count)
    
    #stupid check - need to use for win10
    $count = $count + ([regex]::matches($data, 'lost').count) - ([regex]::matches($data, '0 unindexed files recovered to lost and found').count)
    
    if($count -eq 0){
        $message = "Chkdsk log from Windows events is fine!"
        write-host $message
    }
    else{
        $message = ([string]$count) + " errors in chkdsk log!!!`n" + $data
        write-host $message
    }
}

function Test-ChkdskEvents
{
    $eventIdList = @(1001, 26214, 26180, 26212)

    
    try
    {
        $eventList = @()
        $logList = [array](get-eventlog -list)
        $chkdskData = ""
        $ignoreSourceList = @("Microsoft-Windows-LoadPerf", "LoadPerf", "Windows Error Reporting")
        foreach($log in $logList)
        {
            if($log.log -eq "application")
            {
                if($log.entries[0])
                {
                    $waitChkdskLimit = [TimeSpan]::FromSeconds(10*60)
                    $timerChkdsk = [System.Diagnostics.StopWatch]::StartNew()
                    $isChkdskFound = $false
                    
                    while (($isChkdskFound -eq $false) -and ($timerChkdsk.Elapsed -le $waitChkdskLimit))
                    {
                        $eventList = [array]((get-eventlog application) | where {(($eventIdList -contains $_.EventId) -and (-not ($ignoreSourceList -contains $_.Source))) -or `
                                                                                        ($_.message -match "The type of the file system is")})
                        if(-not $eventList)
                        {
                            start-sleep 5
                        }
                        else
                        {
                            $isChkdskFound = $true
                        }
                    }
                    if ($timerChkdsk.Elapsed -gt $waitChkdskLimit)
                    {
                        write-host "There are no chkdsk events found!"
                    }
                    else
                    {
                        foreach($event in $eventList)
                        {
                            $chkdskData = $chkdskData  + $event.message
                        }
                        write-host $chkdskData
                        if($chkdskData -ne "")
                        {
                            Test-Chkdsklog $chkdskData
                        }
                    }
                }
            }
        }
    } 
    catch{write-host ("Errors occured: " + $Error)}
}

$diskpartScriptPath = $env:temp + "\diskpart.script"
"rescan" | out-file $diskpartScriptPath -Encoding "ASCII"
diskpart /s "$diskpartScriptPath"

Test-ChkdskEvents
ipconfig /renew