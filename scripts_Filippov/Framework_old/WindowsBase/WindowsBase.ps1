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
		[string] $name = "TestShare"
	)	
	$Computer = "localhost"
	$Method = "Create"
	if(!(Test-Path -Path $path)){ $t = New-Item -Path $path -ItemType directory }
	$description = "This is shared for tests"	
	$sd = ([WMIClass] "\\$Computer\root\cimv2:Win32_SecurityDescriptor").CreateInstance()
	$ACE = ([WMIClass] "\\$Computer\root\cimv2:Win32_ACE").CreateInstance()
	$Trustee = ([WMIClass] "\\$Computer\root\cimv2:Win32_Trustee").CreateInstance()
	$Trustee.Name = "EVERYONE"
	$Trustee.Domain = $Null
	$Trustee.SID = @(1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0)
	$ace.AccessMask = 2032127
	$ace.AceFlags = 3
	$ace.AceType = 0
	$ACE.Trustee = $Trustee
	$sd.DACL += $ACE.psObject.baseobject 
	$mc = [WmiClass]"\\$Computer\ROOT\CIMV2:Win32_Share"
	$InParams = $mc.psbase.GetMethodParameters($Method)
	$InParams.Access = $sd
	$InParams.Description = $description
	$InParams.MaximumAllowed = $Null
	$InParams.Name = $name
	$InParams.Password = $Null
	$InParams.Path = $path
	$InParams.Type = [uint32]0
	$R = $mc.PSBase.InvokeMethod($Method, $InParams, $Null)
	switch ($($R.ReturnValue)){
		0 {Write-Host "Share:$name Path:$path Result:Success"; break}
		2 {Write-Host "Share:$name Path:$path Result:Access Denied" -foregroundcolor red -backgroundcolor yellow;break}
		8 {Write-Host "Share:$name Path:$path Result:Unknown Failure" -foregroundcolor red -backgroundcolor yellow;break}
		9 {Write-Host "Share:$name Path:$path Result:Invalid Name" -foregroundcolor red -backgroundcolor yellow;break}
		10 {Write-Host "Share:$name Path:$path Result:Invalid Level" -foregroundcolor red -backgroundcolor yellow;break}
		21 {Write-Host "Share:$name Path:$path Result:Invalid Parameter" -foregroundcolor red -backgroundcolor yellow;break}
		22 {Write-Host "Share:$name Path:$path Result:Duplicate Share" -foregroundcolor red -backgroundcolor yellow;break}
		23 {Write-Host "Share:$name Path:$path Result:Reedirected Path" -foregroundcolor red -backgroundcolor yellow;break}
		24 {Write-Host "Share:$name Path:$path Result:Unknown Device or Directory" -foregroundcolor red -backgroundcolor yellow;break}
		25 {Write-Host "Share:$name Path:$path Result:Network Name Not Found" -foregroundcolor red -backgroundcolor yellow;break}
		default {Write-Host "Share:$name Path:$path Result:*** Unknown Error ***" -foregroundcolor red -backgroundcolor yellow;break}
    }
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
