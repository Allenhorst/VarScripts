param (
    [String]
    # Specify an identifier for new desk. Select a first unused numeric value in
    # http://prm-wiki.paragon-software.com/display/QA/Test+Infrastructure
    $deskIdentifier = "03",


    [String] $UserName = "paragon\autotester",
	
    [String] $Password = "asdF5hh",
	
    [String]
    # Specify a username for authenticating with the vCenter server.
    $viUserName = "paragon\autotester",
	
    [String]
    # Specify a password for authenticating with the vCenter server.
    $viPassword = "asdF5hh",

    [String]  $vCenter = "vcenter-spb-prm.paragon-software.com",
    
    [String]
    # Specify the IP address or the DNS name of the ESX host on which you 
    # want to configure new desk.
    $esxHost = "srv049.paragon-software.com",

    [String]
    # Specify a username for authenticating with the ESX-host.
    $esxUserName = "autotester",
	
    [String]
    # Specify a password for authenticating with the ESX-host.
    $esxPassword = "asdF5hh"
)
Disconnect-VIServer * -Confirm:$false
Start-Sleep 2
Connect-VIServer -Server $esxHost -User $esxUserName -Password $esxPassword 
 Start-Sleep 2
 Add-PSSnapin VMware.VimAutomation.Core
$suffix = "-$deskIdentifier"
$guser = "Administrator"
$gpass = "Qwerty123"

function CreateSnapshot ($vm, $snapname){
	#$timoutTime = (Get-Date).AddSeconds($timeOutSeconds)
	#do{
	#	Start-Sleep -Seconds 5
		New-Snapshot -Name $snapname -VM $vm 
	#}while((!(Get-Snapshot -Name $snapname -VM $vm)) -or ((Get-Date) -lt $timoutTime))
}

function RevertSnapshot ($vm, $snapname){
	Set-VM -vm $vm -Snapshot $snapname -Confirm:$false
    Start-Sleep -Seconds 5
}

function RenameSnapshot ($vm, $snapname, $snapNewName){
    $snap = Get-Snapshot -VM (Get-VM -Name $vm) -Name $snapname
    Set-Snapshot -Snapshot $snap -Name $snapNewName
    Start-Sleep 10
}

function VMStart ($vm){
	$status = $false
	while(!$status)
	{
    	start-vm -vm $vm
		$toolsStatus = (Get-VM -Name $vm | Get-View | Select-Object @{N="Name";E={$_.Name}},@{Name="ToolsStatus";E={$_.Guest.ToolsStatus}}).ToolsStatus
		$status = (($toolsStatus -ne "toolsNotRunning") -and ($toolsStatus -ne "toolsNotInstalled"))
		Start-Sleep 15
	}
}





function VMShutDown ($vm){
    shutdown-vmguest -VM $vm -Confirm:$false   
	$wait_shutdown = $false
    while($wait_shutdown){
        start-sleep 5
        $vm_powerstate = (Get-VM $vm).powerstate
        if($vm_powerstate -eq "poweredoff"){
            $wait_shutdown = $false
        }
		$toolsStatus = (Get-VM -Name $vm | Get-View | Select-Object @{N="Name";E={$_.Name}},@{Name="ToolsStatus";E={$_.Guest.ToolsStatus}}).ToolsStatus
		$status = (($toolsStatus -ne "toolsNotRunning") -and ($toolsStatus -ne "toolsNotInstalled"))
		if($status){Shutdown-VMGuest -VM $vm -Confirm:$false -ErrorAction:SilentlyContinue}
    }
	}

function Script-InstallRemoteDebugger{
	Param
	(

	)
    # TODO: add debugger user
	$install_prereq =@"
		:: Script-InstallRemoteDebugger
		cls
		ECHO Mounting remote folder...
		:mmm1
		timeout /t 10

		net use V: "\\fs-msk\distributives"  /user:paragon\autotester asdF5hh /y
		if not exist "V:\" (goto mmm1)

		ECHO Mounting remote folder is succsess
		:: Determin processor architecture
		SET bit=x86
		IF EXIST "%SystemDrive%\Program Files (x86)" (
		SET bit=x64
		)
		:: Remote Debugging Tools
		ECHO Remote Debugging Tools Installing...
		rem Sleeping for 5 sec...
		timeout /T 6
		cmd /c "V:\microsoft-visual-studio-10.0\en_visual_studio_2010_premium_x86_dvd_509357\Remote Debugger\rdbgsetup_%bit%.exe" /q
		ECHO Configure Remote Debugging Tools Service...
		ECHO Adding user Debugger...
		net user Debugger Qwerty123 /add /EXPIRES:NEVER /y
		net user Debugger /passwordchg:no /y
		WMIC USERACCOUNT WHERE "Name='Debugger'" SET PasswordExpires=FALSE
		net localgroup Administrators Debugger /add /y
		"C:\RKTools\Program Files\Windows Resource Kits\Tools\ntrights.exe" -u Debugger +r SeServiceLogonRight
		ECHO Configure service...
		sc config msvsmon100 start= auto obj= .\Debugger password= Qwerty123

		:: Adding new firewall policies
		IF %PROCESSOR_ARCHITECTURE%==AMD64 (
			netsh firewall add allowedprogram name = "MSVSMON_PRG_x86" program = "C:\Program Files\Microsoft Visual Studio 10.0\Common7\IDE\Remote Debugger\x86\msvsmon.exe" mode = Enable profile = ALL scope = ALL
			netsh firewall add allowedprogram name = "MSVSMON_PRG_x64" program = "C:\Program Files\Microsoft Visual Studio 10.0\Common7\IDE\Remote Debugger\x64\msvsmon.exe" mode = Enable profile = ALL scope = ALL
		) else (
			netsh firewall add allowedprogram name = "MSVSMON_PRG_x86" program = "C:\Program Files\Microsoft Visual Studio 10.0\Common7\IDE\Remote Debugger\x86\msvsmon.exe" mode = Enable profile = ALL scope = ALL
		)
		netsh firewall add portopening name = "MSVSMON_PRG_135" protocol = TCP port = 135 mode = ENABLE scope = ALL profile = ALL
		netsh firewall add portopening name = "MSVSMON_PRG_137" protocol = UDP port = 137 mode = ENABLE scope = ALL profile = ALL
		netsh firewall add portopening name = "MSVSMON_PRG_138" protocol = UDP port = 138 mode = ENABLE scope = ALL profile = ALL
		netsh firewall add portopening name = "MSVSMON_PRG_139" protocol = TCP port = 139 mode = ENABLE scope = ALL profile = ALL
		netsh firewall add portopening name = "MSVSMON_PRG_445" protocol = TCP port = 445 mode = ENABLE scope = ALL profile = ALL
		netsh firewall add portopening name = "MSVSMON_PRG_500" protocol = UDP port = 500 mode = ENABLE scope = ALL profile = ALL
		netsh firewall add portopening name = "MSVSMON_PRG_4500" protocol = UDP port = 4500 mode = ENABLE scope = ALL profile = ALL
		netsh firewall add portopening name = "MSVSMON_PRG_80" protocol = TCP port = 80 mode = ENABLE scope = ALL profile = ALL
		::
		ECHO Ok. Unmounting...
		net use V: /DELETE /y
		ECHO Exiting
		exit 0
"@
	Clear-Host
	return $install_prereq
}

function CopyToGuest{
    Param(
        $source,
        $VM,
        $target,
        $guser = $guser,
        $gpass = $gpass
    )
    $fileName=[System.IO.Path]::GetFileName($source)
    while( !$fileExists ){
	    Copy-VMGuestFile -Source $source -Destination $target -vm $VM -LocalToGuest -GuestUser $guser -GuestPassword $gpass -Force:$true -WarningAction:SilentlyContinue
        $fullTarget = ($target + '\' + $fileName)
        $fileExists = (([string](VMware.InvokeVMScript $vm "if exist `"$fullTarget`" (echo exists)")).Trim() -like "*exists*")
    }
}

function VMware.InvokeVMScript{
	Param
	(
		$vm_Name, 
		$ScriptCommand,
        $guser = $guser,
        $gpass = $gpass
	)
    $res = $null
    $expectedOutput = ""
    while(!($res -and ($res.ScriptOutput -like "*$expectedOutput*"))){
        try{
            $vm = get-vm $vm_Name
            $res = Invoke-VMScript -VM $vm -GuestUser $guser -GuestPassword $gpass -ScriptType Bat -ScriptText "$scriptCommand" -ToolsWaitSecs 600 -WarningAction:SilentlyContinue
            $res
            Start-Sleep -Seconds 15
        }catch{
	   	    Write-Host "Some problems with Invoke-VMScript $vmFullName."
            $_
        }
    }
    return $res.ScriptOutput
}

function CustomInvokeVMScript{
	Param
	(
		$vm_Name, 
		$Script,
		$workDir,
		$scriptFileName,
		$redirectOut = $false,
        $encoding = "UTF8",
		$guser = "prmgui\administrator",
		$gpass = "Qwerty123",
        $isPSScript = $false
	)	
	$tmp = "$Env:TEMP\$scriptFileName"
	$Script | Out-File $tmp -Encoding $encoding
	CopyToGuest -source $tmp -VM $vm_name -target "$workDir" -guser $guser -gpass $gpass
	Remove-Item $tmp -Confirm:$false -Force:$true
    if(!$isPSScript){
	   $runSript = "cmd /c `"$workDir\$scriptFileName`""
    }else{
	   $runSript = "powershell -File `"$workDir\$scriptFileName`""
    }
	If($redirectOut){$runSript = $runSript + " >>$workDir\"+"$scriptFileName"+".log 2>>&1"}
    Write-host "$runSript"
	return VMware.InvokeVMScript $vm_name $runSript
}



function dns
(
$computers
)
	{	
	foreach ($comp in $computers)
	{
		$wait_shutdown = $true
        $vm=""
		$vm = $comp + $suffix
		Write-Host "Start Rename Snapshot $vm"
		RenameSnapshot $vm "Base" "Domain_NOTuserDebuger"
		
		
		Write-Host "Start Revert Snapshot $vm"
		RevertSnapshot $vm "Domain_NOTuserDebuger"
		Write-Host "Done Revert Snapshot $vm"
		
		Write-Host "Start VM $vm"
		VMStart $vm
		$t=false
		Start-Sleep 15
		
		
		$res = CustomInvokeVMScript $vm (Script-InstallRemoteDebugger -shared_folder "\\fs-msk\distributives" -user "prmgui\administrator" -pass "Qwerty123") "c:\deploy\" "InstallRemoteDebugger.bat" $true
		Start-Sleep 5
		
		нужно перезагрузиться 
		
		Write-Host "Shut Down VM $vm"
		VMShutDown $vm
		
		Start-Sleep 15
		if($res){
		CreateSnapshot  $vm "Base"
		}
		
		}
}
	


#$my_machines = "w513wpro86en,w522sstd64en,w522sweb86en,w602sstd64en,w602sstd86en,w602wbus86en,w610sstd64en,w611went64en,w620sstd64en,w620went64en,w630sstd64en,w630wpro64en,w630wpro86en,prm-ct-01,prm-ct-02,prm-ct-03,prm-ct-04,prm-ct-05,prm-ct-06,prm-ct-08,prm-ct-12,prm-ct-13,prm-ct-14,prm-ct-15,prm-ct-16,prm-ct-17,prm-ct-18"
#$standardDeskArmsList = "w513wpro86en,w522sstd64en,w522sweb86en,w602sstd64en,w602sstd86en,w602wbus86en,w610sstd64en,w611went64en,w620sstd64en,w620went64en,w630sstd64en,w630went64en,w630went86en,prm-ct-01,prm-ct-02,prm-ct-03,prm-ct-04,prm-ct-05,prm-ct-06,prm-ct-08,prm-ct-09,prm-ct-10,prm-ct-11,prm-ct-12,prm-ct-13,prm-ct-14,prm-ct-15,prm-ct-16,prm-ct-17,prm-ct-18"
$my_machines = "w610sstd64en,w611went64en,w620sstd64en,w620went64en,w630sstd64en,w630went64en,w630went86en,prm-ct-01,prm-ct-02,prm-ct-04,prm-ct-06,prm-ct-08,prm-ct-16,prm-ct-18,w630sstd64c1,w630sstd64c2"




[string[]] $vmList = ($my_machines.Split(","))

 $t = false

 dns $vmList



	


