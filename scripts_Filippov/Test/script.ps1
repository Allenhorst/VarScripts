import-module "C:\test\Framework\Framework.ps1"

$formatList = @()
$formatList += 'format fs=refs quick'

$backupPolicyName = "BackupPolicy"
#restore policy for volume e:
$restorePolicyName = "RecoveryPolicy1"

$isContinue = $true
$iteration = 1

while ($isContinue)
{
    WindowsBase.Log ("Start Iteration $iteration")
	$createNewData = get-random @($true, $false, $false, $false)
	if($iteration -eq 1){$createNewData = $true}
	if($createNewData)
	{
		#format
		WindowsBase.Log ("Format")
		$script = 'select volume 3
' + (get-random $formatList)
		$script
		$script | out-file $env:temp\diskpart.script -Encoding "ASCII"
		
		diskpart /s $env:temp\diskpart.script
		
		#genFiles
		WindowsBase.Log ("Generate files")
		$fgPath = "c:\test\fg.exe"
		$path = "e:\fgData"
		$size = get-random (4096..65536)
		$sizeLimit = (get-random(16..128))*1024*1024
		
		$totalSize = 0
		while ($totalSize -le $sizeLimit)
		{
			$minSize = $size
			$maxSize = $minSize * (get-random (1..16))
			$fgSize = $maxSize * (get-random (1..16))
			$totalSize += $fgSize
			
			$minSize = "$minSize" + "b"
			$maxSize = "$maxSize" + "b"
			$fgSize = "$fgSize" + "b"
			
    		Start-Process -FilePath $fgPath -ArgumentList ("/s /allsize:$fgSize /root:'" + $path + "' /minsize:$minSize /maxSize:$maxSize") -Wait
			
		}
	}
	else
	{
		WindowsBase.Log ("Change files")
		$fileList = (gci e: -recurse) | where {$_.attributes -ne "Directory"}
		$fileList = get-random $fileList -count (get-random (2..$fileList.length) -count 1)
		foreach ($file in $fileList)
		{
			Add-Content $file.fullname "Hello! Your file was changed for increment!" -Force
		}
	}

	#md5 count
	WindowsBase.Log ("Count md5")
    $fsumCount = c:\test\fsum.exe e:\ /t:f /r /o
	if(-not ($fsumCount -match "All results were written successfully"))
    {
        WindowsBase.Log ("calculate md5 failed")
        WindowsBase.Log ("$fsumCount")
        $isContinue = $false
		break
    }
    
	WindowsBase.Log ("Backup")
    $task = submit-prmpolicy (gi prm::policies\$backupPolicyName)
    if((PRM.Wait-PolicyTask $task) -eq $false)
    {
        WindowsBase.Log "$backupPolicyName failed"
        $isContinue = $false
		break
    }

    #format
	WindowsBase.Log ("Format")
	$script = 'select volume 3
' + (get-random $formatList)
	$script | out-file $env:temp\diskpart.script -Encoding "ASCII"
	
	diskpart /s $env:temp\diskpart.script
	
	#restore
	WindowsBase.Log ("Restore")
    $task = submit-prmpolicy (gi prm::policies\$restorePolicyName)
    if((PRM.Wait-PolicyTask $task) -eq $false)
    {
        WindowsBase.Log "$restorePolicyName failed"
        $isContinue = $false
		break
    }
    
	#md5Check
	WindowsBase.Log ("Check md5")
	$fsumCheck = c:\test\fsum.exe e:\ /t:f /r /v
	if(-not ($fsumCheck -match "Files not changed"))
    {
        WindowsBase.Log ("check md5 failed")
        WindowsBase.Log ("$fsumCheck")
        $isContinue = $false
		break
    }
	
	#increase iteration 
	$iteration += 1
}