param (
    [String]
    # Specify an identifier for new desk. Select a first unused numeric value in
    # http://prm-wiki.paragon-software.com/display/QA/Test+Infrastructure
    $deskIdentifier = "78",


    [String] $UserName = "paragon\autotester",
	
    [String] $Password = "asdF5hh",
	
    [String]
    # Specify a username for authenticating with the vCenter server.
    $viUserName = "paragon\autotester",
	
    [String]
    # Specify a password for authenticating with the vCenter server.
    $viPassword = "asdF5hh",

    [String]  $vCenter = "vcenter-obn-prm.paragon-software.com",
    
    [String]
    # Specify the IP address or the DNS name of the ESX host on which you 
    # want to configure new desk.
    $esxHost = "sb617.paragon-software.com",

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

function waitTools($vm){
	$status = $false
	while(!$status)
	{
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

function Script-CopyHyperV{
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

		net use V: "\\fs-obn\machines\Hyper-V\Clean\BIOS\2012R2\Generation1"  /user:paragon\autotester asdF5hh /y
		if not exist "V:\" (goto mmm1)

		ECHO Mounting remote folder is succsess
		
		xcopy V:\ C:\HyperV /S /I
		
		
		ECHO Ok. Unmounting...
		net use V: /DELETE /y
		ECHO Exiting
		exit 0
"@
	Clear-Host
	return $install_prereq
}

function Script-InstallUpdates{
	Param
	(

	)
    # TODO: add debugger user
	$install_updates =@"
		:: Enable Windows Update for installing updates
sc config wuauserv start=delayed-auto

ECHO install KB2919442
wusa.exe C:\HyperV\Update1\Windows8.1-KB2919442-x64.msu /quiet /norestart
C:\HyperV\Update1\clearcompressionflag.exe
ECHO install KB2919355
wusa.exe C:\HyperV\Update1\Windows8.1-KB2919355-x64.msu /quiet /norestart
ECHO install KB2932046
wusa.exe C:\HyperV\Update1\Windows8.1-KB2932046-x64.msu /quiet /norestart
ECHO install KB2959977
wusa.exe C:\HyperV\Update1\Windows8.1-KB2959977-x64.msu /quiet /norestart
ECHO install KB2937592
wusa.exe C:\HyperV\Update1\Windows8.1-KB2937592-x64.msu /quiet /norestart
ECHO install KB2938439
wusa.exe C:\HyperV\Update1\Windows8.1-KB2938439-x64.msu /quiet /norestart
ECHO install KB2934018
wusa.exe C:\HyperV\Update1\Windows8.1-KB2934018-x64.msu /quiet /norestart

:: Disable Windows Update
sc config wuauserv start= disabled
"@
	Clear-Host
	return $install_updates
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

function InvokeVMScript{
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
            $res = Invoke-VMScript -VM $vm -GuestUser $guser -GuestPassword $gpass -ScriptText "$scriptCommand" -ToolsWaitSecs 600 -WarningAction:SilentlyContinue
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



function main
(
$computers
)
	{	
	foreach ($comp in $computers)
	{
		$wait_shutdown = $true
        $vm=""
		$vm = $comp + $suffix
				
		Write-Host "Start Revert Snapshot $vm"
		RevertSnapshot $vm "Domain"
		Write-Host "Done Revert Snapshot $vm"
		
		Write-Host "Start VM $vm"
		VMStart $vm
		$t=false
		Start-Sleep 15
		
		
		$res = CustomInvokeVMScript $vm (Script-CopyHyperV -shared_folder "\\fs-obn\machines\Hyper-V\Clean\BIOS\2012R2\Generation1" -user "prmgui\administrator" -pass "Qwerty123") "c:\" "CopyHyperV.bat" $true
		Write-Host "$res"
		Start-Sleep 5
		
		$script_install_hyperv = "Install-WindowsFeature -Name Hyper-V -ComputerName $vm -IncludeManagementTools -LogPath C:\installHyperV_logs.txt -Restart"
		$res  = InvokeVMScript $vm $script_install_hyperv
		Write-Host "$res"
		Start-Sleep 15
		waitTools $vm
		
		$vm1 = "(Get-Item 'C:\HyperV\w611went86en-00\Virtual Machines\*.xml').ToString()"
		$vm1 = "(Get-Item 'C:\HyperV\w630went64en-00\Virtual Machines\*.xml').ToString()"
		
		$scriptimport1 = "Import-VM -Path $vm1"
		$scriptimport2 = "Import-VM -Path $vm2"
		
		$res  = InvokeVMScript $vm $scriptimport1
		Write-Host "$res"
		$res  = InvokeVMScript $vm $scriptimport2
		Write-Host "$res"
		

		Write-Host "Shut Down VM $vm"
		#VMShutDown $vm
		
		Start-Sleep 15
		if($res){
		#CreateSnapshot  $vm "HyperV"
		}
		
		}
}

#$my_machines = "w513wpro86en,w522sstd64en,w522sweb86en,w602sstd64en,w602sstd86en,w602wbus86en,w610sstd64en,w611went64en,w620sstd64en,w620went64en,w630sstd64en,w630wpro64en,w630wpro86en,prm-ct-01,prm-ct-02,prm-ct-03,prm-ct-04,prm-ct-05,prm-ct-06,prm-ct-08,prm-ct-12,prm-ct-13,prm-ct-14,prm-ct-15,prm-ct-16,prm-ct-17,prm-ct-18"
#$standardDeskArmsList = "w513wpro86en,w522sstd64en,w522sweb86en,w602sstd64en,w602sstd86en,w602wbus86en,w610sstd64en,w611went64en,w620sstd64en,w620went64en,w630sstd64en,w630went64en,w630went86en,prm-ct-01,prm-ct-02,prm-ct-03,prm-ct-04,prm-ct-05,prm-ct-06,prm-ct-08,prm-ct-09,prm-ct-10,prm-ct-11,prm-ct-12,prm-ct-13,prm-ct-14,prm-ct-15,prm-ct-16,prm-ct-17,prm-ct-18"
$my_machines = "w630sstd64en"




[string[]] $vmList = ($my_machines.Split(","))

 $t = false

 main $vmList



	
#sc config wuauserv start=delayed-auto
#net start wuauserv




:: Enable Windows Update for installing updates
sc config wuauserv start=delayed-auto

ECHO install KB2919442
wusa.exe C:\HyperV\Update1\Windows8.1-KB2919442-x64.msu /quiet /norestart
C:\HyperV\Update1\clearcompressionflag.exe
ECHO install KB2919355
wusa.exe C:\HyperV\Update1\Windows8.1-KB2919355-x64.msu /quiet /norestart
ECHO install KB2932046
wusa.exe C:\HyperV\Update1\Windows8.1-KB2932046-x64.msu /quiet /norestart
ECHO install KB2959977
wusa.exe C:\HyperV\Update1\Windows8.1-KB2959977-x64.msu /quiet /norestart
ECHO install KB2937592
wusa.exe C:\HyperV\Update1\Windows8.1-KB2937592-x64.msu /quiet /norestart
ECHO install KB2938439
wusa.exe C:\HyperV\Update1\Windows8.1-KB2938439-x64.msu /quiet /norestart
ECHO install KB2934018
wusa.exe C:\HyperV\Update1\Windows8.1-KB2934018-x64.msu /quiet /norestart

:: Disable Windows Update
sc config wuauserv start= disabled