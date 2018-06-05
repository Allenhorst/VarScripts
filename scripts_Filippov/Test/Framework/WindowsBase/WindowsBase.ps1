#get OS type(bit)
function WindowsBase.is64bit() {
  return (Test-Path ($env:SystemRoot + "\SysWOW64"))
}

#Program Files for x86 processes
function WindowsBase.ProgramFiles() {
  if (WindowsBase.is64bit -eq $true) {
    (Get-Item "Env:ProgramFiles(x86)").Value
  }
  else {
    (Get-Item "Env:ProgramFiles").Value
  }
}

#Get relative path
function WindowsBase.RelativePath{
    param
    (
        [string]$path = $(throw "Missing: path"),
        [string]$basepath = $(throw "Missing: base path")
    )    
	$i = [system.io.path]::GetFullPath($basepath).Length + 1
	$j = [system.io.path]::GetFullPath($path).Length - $i -(Split-Path -Leaf $path).Length 
		
    return [system.io.path]::GetFullPath($path).SubString($i,$j)
}   

#delay
function WindowsBase.Delay($wtTime = 3, $message = "") {
  $start = Get-Date
  $outof = $start.AddSeconds($wtTime)
  $tSpan = New-Timespan $start $outof

  while ($tSpan -gt 0) {
    $tSpan = New-Timespan $(Get-Date) $outof
    Write-Host $([string]::Format("`r Time remaining: {0:d2}:{1:d2}:{2:d2}",`
     $tSpan.Hours, $tSpan.Minutes, $tSpan.Seconds)) -non -f cyan
    Start-Sleep 1
  }
   Write-Host $("`r                                              ")
   if ($message -ne ""){Write-Host $message}
}

#write log whith timestamps
function WindowsBase.Log([string]$logline){	
	$time = (Get-Date -f o)
	$logline = "[" + $time + "] - " + $logline
	Write-host $logline
}

function WindowsBase.ParseWindowsEvents{
    $id = "parse-WinEvents"
    $logs = @()
    $logs = $logs + (get-eventlog -list)
    
    $all_events = @()
    foreach($log in $logs){
        if($log.log -eq "application"){
            if($log.entries[0]){
                $all_events = $all_events + (get-eventlog application)
            }
        }
        if($log.log -eq "system"){
            if($log.entries[0]){
                $all_events = $all_events + (get-eventlog system)
            }
        }
    }
    
    $search_patterns = @("prm", "scripts.exe")
	$source_patterns = @("vss")
	
    $events = @()
    foreach($search_pattern in $search_patterns){
        $events = $events + ($all_events | where {$_.message -match $search_pattern})
    }
	foreach($source_pattern in $source_patterns){
        $events = $events + ($all_events | where {$_.source -eq "vss"})
    }
    $events = [array]($events | where {$_.entrytype -eq "error"})
    
    $errors_data = ""
    if($events){
		$events > "$env:homedrive\test\results\win_events_errors.log"
        foreach($event in $events){
            $errors_data =  $errors_data + 
                            "`nEvent source: " + $event.source + "`n" +
                            $event.message + "`n" +
                            "#----------------------------------------------------------------#`n"
        }
        $message = $errors_data
        NUnit.assert $false $message
        return -1
    }
    else{
        $message = "$id check = OK"
        WindowsBase.Log $message
        return 0
    }
}

function WindowsBase.Remove-FileShare{
	Param
	(
		[string] $name = "TestShare"
	)
	Get-WmiObject -Class Win32_Share -Filter ("Name='" + $name + "'") | Remove-WmiObject
}

function WindowsBase.New-FileShare{
	Param
	(
		[string] $path = "C:\TestShare",
		[string] $name = "TestShare",
        [string] $user = "Everyone"
	)	
	if(-not (test-path $path)){mkdir $path}
    net share "$name=$path" "/GRANT:$user,FULL"
    
	#FireWall rules
	If([System.Environment]::OSVersion.Version.Major -ge 6){
		$t = cmd /c 'netsh advfirewall firewall set rule group="Remote Desktop" new enable=Yes'
		$t = cmd /c 'netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes'
	}
	else{
		$t = cmd /c 'netsh firewall set service type = FILEANDPRINT mode = ENABLE'
	}
}

function WindowsBase.FormatHumanReadable{
	<#
        .SYNOPSIS
            Format byte string
        .DESCRIPTION
            Format byte string to human readable form(KB,MB....)
        .PARAMETER  size
            size in byres
        .EXAMPLE
            PS C:\> WindowsBase.FormatHumanReadable 102400
        .INPUTS
            System.Int32, System.Int64, System.UInt64 e.t.c.
        .OUTPUTS
            System.String
    #>
	Param
	(
		$size
	)
    switch ($size) 
    {
        {$_ -ge 1PB}{"{0:#.##'Pb'}" -f ($size / 1PB); break}
        {$_ -ge 1TB}{"{0:#.##'Tb'}" -f ($size / 1TB); break}
        {$_ -ge 1GB}{"{0:#.##'Gb'}" -f ($size / 1GB); break}
        {$_ -ge 1MB}{"{0:#.##'Mb'}" -f ($size / 1MB); break}
        {$_ -ge 1KB}{"{0:#.#'Kb'}" -f ($size / 1KB); break}
        default {"{0}" -f ($size) + "B"}
    }
}

function WindowsBase.GetExceptionInfo{
    $exceptionMessage = $error[0].Exception.Message
    $exceptionTrace = $error[0].Exception.StackTrace
    $scriptName = $error[0].InvocationInfo.ScriptName
    $lineNumber = $error[0].InvocationInfo.ScriptLineNumber
    
    $message =  "---ExceptionInfo---------------------------------------------`n" 
    $message += "ExceptionMessage: $exceptionMessage" + "`n"
    $message += "ExceptionStackTrace: $exceptionTrace" + "`n"
    $message += "Exception was found in script: $scriptName" + "`n"
    $message += "Exception was found in line number: $lineNumber" + "`n-------------------------------------------------------------------"
    
    return $message
}

function WindowsBase.LogExceptionInfo{
    Param(
        $writeError = $true
    )
    
    $message = WindowsBase.GetExceptionInfo
    WindowsBase.Log $message
    if($writeError -eq $true)
    {
        write-error $message
    }
}

function WindowsBase.StartProcess{
	<#
        .SYNOPSIS
            Start process
        .DESCRIPTION
            Function start process and return result object
        .PARAMETER  path
            Path to executable file
        .PARAMETER  arguments
            Process arguments
		.PARAMETER  rediroutput
            Redirect output
        .EXAMPLE
            all parameters are set by user
            PS C:\> 
        .EXAMPLE
            use default values for storageName and storageFolder
            PS C:\> 
        .INPUTS
            System.String,System.String,System.Boolean,System.Boolean
        .OUTPUTS
            Powershell object with properties: process exitcode, output, error
    #>
    Param (
        [String] $path, 
        [String] $arguments = $null,
		[bool] $wait = $true,
		[bool] $rediroutput = $true,
		[bool] $writeResultToLog = $true
    )    
	#create log files
	$guid = [System.Guid]::NewGuid().ToString()	
	$log = "$Env:TEMP\$guid.log"
	$elog = "$Env:TEMP\err$guid.log"
	"" | Out-File $log 
	"" | Out-File $elog 
	$exec = "Start-Process `"$path`"  -PassThru "
	if($rediroutput -eq $true){$exec = $exec + " -RedirectStandardOutput $log -RedirectStandardError $elog -NoNewWindow:`$true "}
	#Start-Process -ArgumentList
	if($arguments -ne $null){$exec = $exec + " -ArgumentList '" + $arguments + "'"}
	if($wait -eq $true){$exec = $exec + " -wait"}	
	$p = Invoke-Expression $exec
	$pr = @{}
	$pr.exitcode = $p.ExitCode
	$pr.output = [IO.File]::ReadAllText($log)
	$pr.error = [IO.File]::ReadAllText($elog)
	#remove log files
	Remove-Item $log
	Remove-Item $elog
	if($writeResultToLog){
		WindowsBase.Log ("Exite code: " + $pr.exitcode)
		WindowsBase.Log ("Output: " + $pr.output)
		WindowsBase.Log ("ErrOutput: " + $pr.error)
	}
	#Clear-Host
	return $pr
}