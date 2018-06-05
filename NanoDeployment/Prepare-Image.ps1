#Source: https://michaelryom.dk/auto-create-nano-server-for-esxi-with-powershell
#Created by Michael Ryom @MichaelRyom.dk
#Https://MichaelRyom.dk
#Go to https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-technical-preview and download Windows Server TP 5 - Nano ISO
#Link that might work ? http://care.dlservice.microsoft.com/dl/download/B/3/3/B33F3810-EE82-4C20-B864-394A2C4B6661/Nano-WindowsServerTechnicalPreview5.vhd
#Windows Server TP5 Licnese Key MFY9F-XBN2F-TYFMP-CCV49-RMYVH
#Download image if link works: wget http://care.dlservice.microsoft.com/dl/download/B/3/3/B33F3810-EE82-4C20-B864-394A2C4B6661/Nano-WindowsServerTechnicalPreview5.vhd -OutFile C:\temp\Windows-Nano-Server-TP5.VHD
#http://care.dlservice.microsoft.com/dl/download/8/9/2/89284B3B-BA51-49C8-90F8-59C0A58D0E70/14300.1000.160324-1723.RS1_RELEASE_SVC_SERVER_OEMRET_X64FRE_EN-US.ISO

#Variables that can be chnaged

#$vdisk = $VMWorkStation + "vmware-vdiskmanager.exe"

#$VMTools = "D:\ISO\" + "en_windows_server_2016_x64_dvd_9327751.iso"
$WorkingDir = "D:\Scripts\NanoDeployment\"
$ISOPath = "D:\ISO\"


$DriverInitialPath = "D:\Scripts\NanoDeployment\bin\VMware\VMware Tools\VMware\Drivers\"
$DriverTargetPath  = "D:\Scripts\NanoDeployment\Drivers\"



$NanoISOName = "en_windows_server_2016_x64_dvd_9327751.iso"
$NanoISOPath = $ISOPath + $NanoISOName

$NanoVMDKName = "Windows-Nano-Server-TP5.VMDK"
$NanoVMDKPath = $WorkingDir + $NanoVMDKName

$NanoVHDxName = "Nano01.vhdx"
$NanoVHDxPath = $WorkingDir + $NanoVHDxName

$DriversDir = $WorkingDir+"Drivers\"
$WindowsAdminPass = "Qwerty123"
$StarWind = "C:\StarWindIC\StarV2Vc.exe"
#^End of Variables that can be chnaged

#Test if PowerShell has been run as administrator - Source: http://www.jonathanmedd.net/2014/01/testing-for-admin-privileges-in-powershell.html
#if(([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] “Administrator”)){
#}else{
#Write-Host "This script requies that it is 'Run as Administrator' - Please run it again by right clicking and selete 'Run as Administrator'"
#$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#Exit
#}
#^End of Test if PowerShell has been run as administrator

#Test all variables needed




If(!(Test-Path $WorkingDir)){
New-Item $WorkingDir -type directory | Out-Null
}

If(!(Test-Path $DriversDir)){
New-Item $DriversDir -type directory | Out-Null
}

If(!(Test-Path $ISOPath)){
New-Item $ISOPath -type directory | Out-Null

}

#^End of Test all variables needed











#Source: http://www.v-front.de/2016/07/how-to-deploy-windows-nano-server-tp5.html
#Create Nano Server image
#Mount VMwareTools ISO  disk image


#Copy needed drivers
$pvscsi = "pvscsi\"
$vmxnet3 = "vmxnet3\NDIS6\"
Copy-Item ($DriverInitialPath+$pvscsi +  "*") ($DriverTargetPath + $pvscsi)
Copy-Item ($DriverInitialPath + $vmxnet3 + "*") ($DriverTargetPath + $vmxnet3)





#Mount Windows ISO disk image
$MountCDROM = Mount-DiskImage $NanoISOPath -StorageType ISO -Access ReadOnly -PassThru
$MountDriveWin = ($MountCDROM | Get-Volume).DriveLetter

Import-Module -Global $MountDriveWin":\NanoServer\NanoServerImageGenerator\NanoServerImageGenerator.psm1"
New-NanoServerImage -MediaPath $MountDriveWin":\" -BasePath ($WorkingDir + "Base\") -TargetPath $NanoVHDxPath -ComputerName Nano01 -EnableRemoteManagementPort -DriversPath $WorkingDir"Drivers" -AdministratorPassword (ConvertTo-SecureString -String $WindowsAdminPass -AsPlainText -Force) -DeploymentType Host -Edition Standard


#Convert VHDx to VMDK
.$StarWind if=$NanoVHDxPath ot=VMDK_VMFS of=$NanoVMDKPath vmdktype=scsi
if(!(Test-Path $NanoVMDKPath)){
Write-Host "Convertion failed! - See generic error above"
Break
}

#Clean up after VHDx creation
$MountCDROM | Dismount-DiskImage
Remove-Item $NanoVHDxPath
Remove-Item $WorkingDir"Drivers" -Force -Recurse
Remove-Item $WorkingDir"Base" -Force -Recurse