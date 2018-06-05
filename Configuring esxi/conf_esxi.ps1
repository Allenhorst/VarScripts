#Configuring esxi

#input parameters : hostname
$Hostname = "srvXXX"
$userpass = ""
$user  = "root"
# 1. Добавить пользователея autotester с паролем "asdF5hh" (см. п. 7), дать админские права.  

$conn = Connect-VIServer -Protocol https -Server $Hostname -User $user -Password $userpass 
$whost = $conn | Get-VMHost 
$esxiver = Get-VMHost | % { $($_.Version) }

New-VMHostAccount -Id autotester -Password asdF5hh -Description "for testing purpose"

New-VIPermission -Entity $Hostname -Principal autotester -Role "Administrator" -Propagate:$true

# 2. Прописать необходимые зоны:  Сonfiguration=>DNS and Routing=>Search Domains (Properties =>Look for hosts.... )  = paragon-software.com prm.test su.test localhost



Get-VMHost Host | Get-VMHostNetwork | Set-VMHostNetwork -SearchDomain "paragon-software.com prm.test su.test localhost"


# $dnsServers = ("192.168.111.3","192.168.111.4")
# 
# Get-VMHost | Get-View | %{
#    $ns = Get-View -Id $_.configManager.networkSystem
#    $dns = $ns.networkConfig.dnsConfig
#  
#     $dns.Address = @()
#     foreach($server in $dnsServers) {
#       $dns.Address += $server
#   }
#   $ns.UpdateDnsConfig($dns)
# }

# 3. Добавить датасторы, именование датасторов: "srv(sb)X:hdd(ssd)Y", где X - имя сервера, Y - идетификатор датастора (1,2...n)

$password = $userpass | ConvertTo-SecureString -asPlainText -Force
$username = $user
$credential = New-Object System.Management.Automation.PSCredential($username,$password)

$get_disks_com = '/sbin/esxcfg-scsidevs -A | grep -v mpx | awk ''{print $2}'''


New-SSHSession -ComputerName $whost -Credential $credential  -AcceptKey

$disks = (Invoke-SshCommand -Index 0 -Command  $get_disks_com).Output


$ssd_c = 1 # names begin from 1
$hdd_c = 1 # names begin from 1

foreach ($disk in $disks)
{

   
    $isSSD_com = "esxcli storage core device list -d " + $disk + '| grep -i ''Is SSD'' | awk -F '': '' ''{ print $2}'' ' 
    $isSSD = (Invoke-SshCommand -Index 0 -Command $isSSD_com).Output  
   
    if !($isSSD) {
         $datastore_name = $Hostname + ":hdd" + $hdd_c
         $hdd_c++
         New-Datastore -VMHost $Hostname -Name $datastore_name -Path $disk -Vmfs -FileSystemVersion 5
    }
    else {
        $datastore_name = $Hostname + ":ssd" + $ssd_c
        $ssd_c++
        New-Datastore -VMHost $Hostname -Name $datastore_name -Path $disk -Vmfs -FileSystemVersion 5
    }
    
}

#via ssh    
    #disks=/sbin/esxcfg-scsidevs -A | grep -v "mpx" | awk '{print $2}'
    #esxcli storage core device list -d ${disk}" | grep -i 'Is SSD' | awk -F ': ' '{ print $2}') (true\false)



# 4. Указать директорию хранения системных логов, в качестве хранилища использовать: Configuration - Advanced Settings - Syslog - Syslog.global.logDir [ srv(sb)X:hdd1 ] .logs 
if ($hdd_c > 1) {
    $dest = "["+ $Hostname + ":hdd1] .logs"
    Get-AdvancedSetting -Entity $Hostname -Name "Syslog.global.logDir" | Set-AdvancedSetting -Value $dest
}
else {
    $dest = "["+ $Hostname + ":ssd1] .logs"
    Get-AdvancedSetting -Entity $Hostname -Name "Syslog.global.logDir" | Set-AdvancedSetting -Value $dest
}

# ssh needed => do it later
# 5. В ESXi Shell (по ssh) активировать SNMP командой: esxcli system snmp set -e yes -c public 

$snmp_com = "esxcli system snmp set -e yes -c public"
Invoke-SshCommand -Index 0 -Command $snmp_com

# 6. (для ESXi 6.0+) Активировать Managed Object Browser 

if ($esxiver.Split(".")[0] > 5 ) { # esxi major > 5
    Get-AdvancedSetting -Entity $Hostname -Name "Config.HostAgent.plugins.solo.enableMob" | Set-AdvancedSetting -Value "true"
} 



# 7. (для ESXi 6.5+) Настроить политику сложности паролей: в файле /etc/pam.d/passwd удалить первую и третью строку а из второй строки  удалить и привести файл к виду 

if ($esxiver.Split(".")[0] > 5 ) && ($esxiver.Split(".")[1] > 0) { # esxi > 6.0
    


# 8. Увеличить количество NFS подключений:

Get-AdvancedSetting -Entity $Hostname -Name "NFS.MaxVolumes" | Set-AdvancedSetting -Value "256"



# 9. Настроить ntp сервер


Add-VmHostNtpServer -VMHost $Hostname -NtpServer "172.30.1.2" # all except fre
#Allow NTP queries outbound through the firewall
Get-VMHostFirewallException -VMHost $Hostname | where {$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled:$true
#Start NTP client service and set to automatic
Get-VmHostService -VMHost $Hostname | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService
Get-VmHostService -VMHost $Hostname | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "automatic"

10. Настроить хост для возможности мониторинга температуры дисков