$mountvolData = mountvol
$volumeGuidList = $mountvolData -match "{.+}"
$fsValidList = @("File System Name : NTFS", "File System Name : FAT", "File System Name : FAT32", "File System Name : exFAT")

$bootExecuteValue = ""
foreach($volumeGuid in $volumeGuidList)
{
    $volumeGuid = "\\" + ($volumeGuid -split "\\\\")[1]
    $fsutilData = (fsutil fsinfo volumeinfo "$volumeGuid")
    $fsName = $fsutilData -match "File System Name.+"
    if($fsValidList -contains $fsName)
    {
        $volumeGuid = '\??\Volume' + ($volumeGuid -split "Volume")[1]
        $volumeGuid = ($volumeGuid -split "}")[0] + "}"
        
        $bootExecuteValue += "autocheck autochk /p $volumeGuid\0"
    }
}

$bootExecuteValue = $bootExecuteValue  + 'autocheck autochk *'
cmd /c reg delete 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager' /v BootExecute /f
cmd /c reg add 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager' /v BootExecute /t REG_MULTI_SZ /d $bootExecuteValue

$diskpartScriptPath = $env:temp + "\diskpart.script"
"rescan" | out-file $diskpartScriptPath -Encoding "ASCII"
diskpart /s "$diskpartScriptPath"