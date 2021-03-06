param (
    [String]
    # Specify a username for authenticating with the vCenter server.
    $viUserName = "root",

    [String]
    # Specify a password for authenticating with the vCenter server.
    $viPassword = "vmware",

    [String]  $vCenter = "virtual-vcenter.paragon-software.com",
    
    [String]
    # Specify the IP address or the DNS name of the ESX host on which you 
    # want to configure new desk.
    $esxHost = "172.30.50.251"
)

$datacenterName = "datacenter"
$folderName = "Folder"
$poolName = "AppPool"
$vmname = "VM"
$vmVersion = "v8"

$startNameIndex = 1
$DiskStorageFormat = "Thin" #or thick
$DiskMB = 1 
$iteration1 = $startNameIndex + 1000
$iteration2 = $startNameIndex + 500

Add-PSSnapin VMWare.VimAutomation.Core

Disconnect-VIServer * -Force:$true  -Confirm:$false -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue

# Connect-VIServer -Server $esxHost -User $esxUserName -Password $esxPassword 


$server = Connect-VIServer -Server $vcenter -User $viUserName -Password  $viPassword
$vmHost = Get-VMHost -Server $server -Name "$esxHost*"

$rootFolderName  = "MaxDC"

#create Folder for max datacenter
Clear-Variable r -ErrorAction:SilentlyContinue  
Clear-Variable i -ErrorAction:SilentlyContinue  
Write-Host "Creating dataCenters. Please wait..."
$folder = Get-Folder -NoRecursion #| New-Folder -Name $rootFolderName
$dcCount = $startNameIndex

for($i =$startNameIndex; $i -lt $iteration1; $i++)
{
    $r = New-Datacenter -Location  $folder -Name "$datacenterName$dcCount" | fl 
    if(!$r) {
    Write-Host "Count of max Datacenters = $dcCount"
    break
    } 
    
    Write-Host "Created DataCenter $datacenterName$dcCount"
    Start-Sleep 1
    $dcCount++
 }
 
 
#create Max folders in DC
Clear-Variable r -ErrorAction:SilentlyContinue  
Clear-Variable i -ErrorAction:SilentlyContinue  
$folderLoc = Get-Datacenter -Name "$datacenterName$startNameIndex"
$fdCount = $startNameIndex

for($i = $startNameIndex; $i -lt $iteration2; $i++)
{
    $r = New-Folder -Name "$folderName$fdCount" -Location $folderLoc -Confirm:$false 
    if(!$r) {
    Write-Host "Count of max folders in DC  = $fdCount"
    break
    } 
    $folderLoc = Get-Folder -Name "$folderName$fdCount"
    Start-Sleep 1
    Write-Host "Created $folderName$fdCount"
    $fdCount++
 }
 $fdCount--
 
 
#create max polls in 
Clear-Variable r -ErrorAction:SilentlyContinue  
Clear-Variable i -ErrorAction:SilentlyContinue  
$lastFd = Get-Folder -Name "$folderName$fdCount"
Move-VMHost -VMHost $vmHost -Destination $lastFd
$poolLoc = Get-VMHost -Server $server -Name "$esxHost*"
$poolCount = $startNameIndex

for($i = $startNameIndex; $i -lt $iteration1; $i++)
{
    $r = New-ResourcePool -Name "$poolName$poolCount" -Location $poolLoc -Confirm:$false 
    if(!$r) {
    Write-Host "Count of max pools in ESXi  = $poolCount"
    break
    } 
    Write-Host "Created $poolName$poolCount"
    $poolLoc = Get-ResourcePool -Name "$poolName$poolCount"
    Start-Sleep 1
    $poolCount++
 }
  $poolCount--
 
#Create VMs
Clear-Variable r -ErrorAction:SilentlyContinue 
Clear-Variable i -ErrorAction:SilentlyContinue     
$VMsCount = $startNameIndex
for($i = $startNameIndex; $i -lt $iteration2; $i++)
{
    $r =  New-VM -Name "$vmname$VMsCount" -VMHost $vmHost -ResourcePool "$poolName$poolCount" -DiskMB $DiskMB -DiskStorageFormat $DiskStorageFormat -Version $vmVersion -Confirm:$false 
    if(!$r) {
    Write-Host "Count of max VMs = $VMsCount"
    break
    } 
    
    Write-Host "Created $vmname$VMsCount"
    Start-Sleep 1
    $VMsCount++
 }
 $VMsCount--
 
 
#Create more disks
Clear-Variable r -ErrorAction:SilentlyContinue    
Clear-Variable i -ErrorAction:SilentlyContinue  
$firstVM = Get-VM -Name "$vmname$startNameIndex"

  
$diskCount = $startNameIndex
for($i = $startNameIndex; $i -lt $iteration2; $i++)
{
    $r =  New-HardDisk -VM $firstVM  -CapacityKB 10000 -StorageFormat $DiskStorageFormat -Confirm:$false 
    if(!$r) {
    Write-Host "Count of max disks on VMs = $diskCount"
    break
    } 
    
    Write-Host "Created disk #$diskCount"
    Start-Sleep 5 #тут нужно не менее 5 сек
    $diskCount++
 }
 
 Write-Host "ENJOY!"