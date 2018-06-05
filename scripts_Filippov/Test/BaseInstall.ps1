#add disk and esx storages
function AddEsxStorage{
    param (
            $TestHost,
            $server_name, 
            $storage_name, 
            $server_folder,
            
            $esx = "vsphere-qa",
            $datastore = ("AutoTestServers/datastore/" + $TestHost + ":hdd1"),
            $hostpath = ("AutoTestServers/host/_TestServers/Autotests/" + $TestHost + ".paragon-software.com/" + $TestHost + ".paragon-software.com"),
            $vmfolderpath = "AutoTestServers/vm",
            $resourcepoolpath = ("AutoTestServers/host/_TestServers/Autotests/" + $TestHost + ".paragon-software.com/Resources/Replicas")
    )
    if(-not $server_name){
        return -1
    }
    if(-not $storage_name){
        $storage_name = "esx_storage_" + $server_name
    }
    if(-not $server_folder){
        $server_folder = Join-Path $env:SYSTEMDRIVE $storage_name
    }
    new-item prm::storages\$storage_name -address $datastore -server $server_name -mediumtype "esx" -properties @{CatalogPath = "$server_folder"; Host = "$esx"; hostpath = "$hostpath"; resourcepoolpath = "$resourcepoolpath"; vmfolderpath = "$vmfolderpath"}
}

function AddDiskStorage{
    param (
            $server_name, 
            $storage_name, 
            $server_folder,
            $virtualDiskParams = $null
    )
    if(-not $server_name){
        return -1
    }
    if(-not $storage_name){
        $storage_name = "disk_storage_" + $server_name
    }
    if(-not $server_folder){
        $server_folder = Join-Path $env:SYSTEMDRIVE $storage_name
    }
    
    WindowsBase.Log ("Create Disk Storage")
    WindowsBase.Log ("disk storage type = " + $storage_name)
    WindowsBase.Log ("disk storage address = " + $server_folder)
    WindowsBase.Log ("backup server name = " + $server_name)
    WindowsBase.Log ("virtualDiskParams = " + $virtualDiskParams)
    
    switch ($virtualDiskParams)
    {
        $null   {PRM.Log (new-item prm::storages\$storage_name -address $server_folder -server $server_name -mediumtype "disk"); break}
        "VMDK"  {PRM.Log (new-item prm::storages\$storage_name -address $server_folder -server $server_name -mediumtype "disk" -props @{"VirtualDiskParams"=(New-PrmVmdkVirtualDiskParams)}); break}
        "VHDX"  {PRM.Log (new-item prm::storages\$storage_name -address $server_folder -server $server_name -mediumtype "disk" -props @{"VirtualDiskParams"=(New-PrmVhdxVirtualDiskParams)}); break}
        "PVHD"  {PRM.Log (new-item prm::storages\$storage_name -address $server_folder -server $server_name -mediumtype "disk" -props @{"VirtualDiskParams"=(New-PrmPvhdVirtualDiskParams)}); break}
        "VHD"   {PRM.Log (new-item prm::storages\$storage_name -address $server_folder -server $server_name -mediumtype "disk" -props @{"VirtualDiskParams"=(New-PrmVhdVirtualDiskParams)});  break}
        "VDI"   {PRM.Log (new-item prm::storages\$storage_name -address $server_folder -server $server_name -mediumtype "disk" -props @{"VirtualDiskParams"=(New-PrmVdiVirtualDiskParams)});  break}
        default {PRM.Log (new-item prm::storages\$storage_name -address $server_folder -server $server_name -mediumtype "disk"); break}
    }
}

function AddUNCStorage{
    param (
            $server_name, 
            $storage_name, 
            $file_server,
            $shared_folder,
            $user,
            $password,
            $virtualDiskParams = $null
    )
    if(-not $server_name){
        return -1
    }
    if(-not $storage_name){
        $storage_name = "shared_storage_" + $server_name
    }    
    WindowsBase.Log ("Create network file share Storage")
    WindowsBase.Log ("backup server name = " + $server_name)
    WindowsBase.Log ("backup storage name = " + $storage_name)
    WindowsBase.Log ("shared storage folder = " + $shared_folder)
    WindowsBase.Log ("shared storage folder user: $user password: $password")
    WindowsBase.Log ("virtualDiskParams: $virtualDiskParams")
    WindowsBase.New-FileShare -path "C:\$shared_folder" -name $shared_folder -user $user
    PRM.Log (New-Item prm::credentials\ -host "\\$file_server\$shared_folder" -credentialstype "Network" -domain "" -login $user -password (ConvertTo-SecureString -String $password -AsPlainText -Force) )
    
    
    switch ($virtualDiskParams)
    {
        $null   {PRM.Log (New-Item prm::storages\$storage_name -address "NetStore" -Props @{Host="\\$file_server\$shared_folder"}  -server $server_name -MediumType "network"); break}
        "VMDK"  {PRM.Log (New-Item prm::storages\$storage_name -address "NetStore" -Props @{Host="\\$file_server\$shared_folder"; "VirtualDiskParams"=(New-PrmVmdkVirtualDiskParams)}  -server $server_name -MediumType "network"); break}
        "VHDX"  {PRM.Log (New-Item prm::storages\$storage_name -address "NetStore" -Props @{Host="\\$file_server\$shared_folder"; "VirtualDiskParams"=(New-PrmVhdxVirtualDiskParams)}  -server $server_name -MediumType "network"); break}
        "PVHD"  {PRM.Log (New-Item prm::storages\$storage_name -address "NetStore" -Props @{Host="\\$file_server\$shared_folder"; "VirtualDiskParams"=(New-PrmPvhdVirtualDiskParams)}  -server $server_name -MediumType "network"); break}
        "VHD"   {PRM.Log (New-Item prm::storages\$storage_name -address "NetStore" -Props @{Host="\\$file_server\$shared_folder"; "VirtualDiskParams"=(New-PrmVhdVirtualDiskParams)}  -server $server_name -MediumType "network"); break}
        "VDI"   {PRM.Log (New-Item prm::storages\$storage_name -address "NetStore" -Props @{Host="\\$file_server\$shared_folder"; "VirtualDiskParams"=(New-PrmVdiVirtualDiskParams)}  -server $server_name -MediumType "network"); break}
        default {PRM.Log (New-Item prm::storages\$storage_name -address "NetStore" -Props @{Host="\\$file_server\$shared_folder"}  -server $server_name -MediumType "network"); break}
    }
}


# Admin Server base policies
function IstallAdminServer($hostName, $roles = "Adminserver, Agent, BackupServer, InstallationServer, AuthorityServer", $addAdminCredential = "True"){

    if($addAdminCredential -eq "True")
    {
        $domain = [Environment]::UserDomainName
        $login = [Environment]::UserName
        if((gwmi win32_computersystem).partofdomain -eq $true)
        {
            $isCredentialExist = (gi prm::credentials\ | where {$_.CredentialsType -eq "ads"})
            if(-not($isCredentialExist))
            {
                AddCredentials "" $login "Qwerty123" "ads" $domain
            }
        }
        else
        {
            $isCredentialExist = (gi prm::credentials\ | where {($_.CredentialsType -eq "system") -and ($_.Host -eq $hostName)})
            if(-not($isCredentialExist))
            {
                AddCredentials $hostName $login "Qwerty123"
            }
        }
    }
    
    PRM.Log (New-item prm::computers\$hostName -Role $roles)
    $delay ="1"
    $timeout = [timespan]::FromSeconds(180)
    $sw = [System.Diagnostics.StopWatch]::StartNew()
    while((((gi prm::computers\$hostName).State -notmatch "Online") ) -and ($sw.Elapsed -le $timeout)){
        start-sleep $delay
    }
    if($sw.Elapsed -ge $timeout){        
        WindowsBase.Log ("Timeout exceeded!!!")
    }
    WindowsBase.Log ((gi prm::computers\$hostName).State)    
}

function AddReportStorage($adminServer, $reportStorageName, $reportsPath){
    PRM.Log (New-item prm::storages\$reportStorageName -mediumtype report -server $adminServer -address $reportsPath)
}

# Create credentials
function AddCredentials($hostname, $login, $password, $type = "system", $domain = ""){
    $password = (ConvertTo-SecureString $password -AsPlainText -Force)
    
    $credentialTypeList = @("system", "esx", "ads", "ftp")
    
    if(-not ($credentialTypeList -contains $type)){
        WindowsBase.Log ("Credential type = " + $type + " is not supported!")
    }
    
    if($type -eq "system"){
        WindowsBase.Log ("Add credentials host: " + $hostname + " type: " + $type)
        $login = $hostname + "\" + $login
        PRM.Log (New-item prm::credentials\ -host $hostname -ct $type -domain $domain -login $login -password $password)
    }
    if($type -eq "esx"){
        WindowsBase.Log ("Add credentials host: " + $hostname + " type: " + $type)
        PRM.Log (New-item prm::credentials\ -host $hostname -ct $type -domain $domain -login $login -password $password)
    }
    if($type -eq "ads"){
        WindowsBase.Log ("Add credentials type: " + $type)
        PRM.Log (New-item prm::credentials\ -host "" -ct $type -domain $domain -login $login -password $password)
    }
    if($type -eq "ftp"){
        WindowsBase.Log ("Add credentials host: " + $hostname + " type: " + $type)
        PRM.Log (New-item prm::credentials\ -host $hostname -ct $type -domain $domain -login $login -password $password)
    }
}

# ESX Agent base config
function AddAgentHost($agentHost, $user, $pass, $_role, $type = "system", $domain = ""){
    PRM.Log (New-Item prm::computers\$agentHost -Role $_role)
    # credentials
    AddCredentials $agentHost $user $pass
}

#ESX server and cedential add
function AddViServer($esxagentHost, $_viserver, $_viuser, $_vipass){
    
    $endpoint = (gi prm::endpoints) | where {$_.name -eq $_viserver}
    if($endpoint -eq $null)
    {
        PRM.Log (ni prm::endpoints\$_viserver -et Esx -host $_viserver -port 0)
    }
    # credentials
    AddCredentials $_viserver $_viuser $_vipass "esx"
}

#--- check align, report_path, alignment
function AddAlignmentPolicies($esxagentHost, $reportStorageName, $CheckAlignmentPolicyName = "Prob2", $AlignmentPolicyName = "vmPAT"){
    PRM.Log (ni prm::policies\$CheckAlignmentPolicyName -PolicyType ReportAcquisition -computer $esxagentHost)
    (gi prm::policies\$CheckAlignmentPolicyName).ComponentMask = "EsxAgent"
    PRM.Log (ni prm::rules\checkAlign -RuleType PartitionAlignment -policies $CheckAlignmentPolicyName)    
    PRM.Log (ni prm::policies\$AlignmentPolicyName -PolicyType VMPartitionAlignment -computer $esxagentHost)
    (gi prm::policies\$AlignmentPolicyName).ComponentMask = "EsxAgent"
    # assign report storage
    PRM.Log (ni prm::rules\ReportMe -RuleType ReportStorage -policies $CheckAlignmentPolicyName, $AlignmentPolicyName -props @{storage = $reportStorageName})
}

#--- Alignment report to xml
function XMLReportRull($adminServer, $reportStorageName, $reportsPath, $reportPolicyName = "DoReport"){
    AddReportStorage $adminServer $reportStorageName $reportsPath
    PRM.Log (ni prm::policies\$reportPolicyName -PolicyType "Report" -computer $adminServer)
    (gi prm::policies\$reportPolicyName).ComponentMask = "ReportManager"
    PRM.Log (ni prm::rules\ReportStoregeRull -RuleType ReportStorage -policies $reportPolicyName -props @{storage = $reportStorageName})
    PRM.Log (ni prm::rules\ReportFolderRull -RuleType ReportDocumentPath -policies $reportPolicyName -props @{ReportDocumentPath=$reportsPath})
    PRM.Log (ni prm::rules\ReportTypeRull -RuleType ReportParameters -policies $reportPolicyName -props @{ReportType = "esxvm"})
}

#Installation policy (need report storage added in XMLReportRull)
function AgentInstallPolicy($adminServer, $agentHost, $PolicyName = "InstallBClnt"){    
    PRM.Log (New-Item prm::policies\$PolicyName -PolicyType "Installation" -Computers $adminServer)
    (gi prm::policies\$PolicyName).ComponentMask = "InstallationServer"
    #PRM.Log (New-Item prm::rules\inst_rule_clnt -RuleType InstallationBehavior -Policies $PolicyName -Properties @{Behavior="Install, Update, Remove"; Path="c:\temp"; Destinations=$agentHost})
    $filter = new-object prm.base.SearchFilter
    $filter.fieldid = [prm.common.PrmSearchComputerFields]::Address
    $filter.filterOperator = [Prm.Base.SearchFilterOperator]::Equal
    $filter.value = $agentHost
    PRM.Log (New-Item prm::rules\inst_rule_clnt -RuleType InstallationBehavior -Policies $PolicyName -Properties @{Behavior="Install, Update, Remove"; Path="c:\temp"; Filter = $filter})
    return, $PolicyName
}

#Install Agent
function InstallAgent($_testType, $agentHost, $agentUser, $agentPass, $role = "Agent, ESXAgent"){
    AddAgentHost $agentHost $agentUser $agentPass $role
    WindowsBase.Log ("Install ESXAagent: " + $agentHost)
    removeInstallPolicies
    if ($_testType -eq "Binary"){
        (gi prm::computers\$agentHost) - "RolePending"
        WindowsBase.Log ((gi prm::computers\$agentHost).State)
        PRM.Replicate $agentHost
        WindowsBase.Log ((gi prm::computers\$agentHost).State)        
    }
    elseif(($_testType -eq "MSI") -or ($_testType -eq "Distrib") -or ($_testType -eq "ISExtractor")){
        $ipolicy = (AgentInstallPolicy (PRM.AdminServer).Name $agentHost)
        PRM.Log (PRM.SubmitPolicy $ipolicy)
        PRM.Replicate $agentHost
        WindowsBase.Log ((gi prm::computers\$agentHost).State)    
    }
    else{
        WindowsBase.Log "Unknown test type $TestType"
        Exit 1
    }
    removeInstallPolicies
}

function replace_var($src, $var, $value){
    $t = Get-Content $src
    for ($i=0;$i -le ($t.Length-1);$i++){
        $t[$i] = ($t[$i] -replace "%$var%", $value)
    }
    $t | Out-File -filepath $src
}

function removeInstallPolicies(){
    if (gi prm::policies | where {$_.PolicyType -eq "Installation"}){    
        $_pls = gi prm::policies | where {$_.PolicyType -eq "Installation"}
        foreach($_pl in $_pls){
            ri prm::policies\$_pl -confirm:$False 
        }
        WindowsBase.Log "Removed all Installation policies"
    }    
    if (gi prm::rules | where {$_.RuleType -eq "InstallationBehavior"} ){
        $_rls = gi prm::rules | where {$_.RuleType -eq "InstallationBehavior"}
        foreach($_rl in $_rls){
            ri prm::rules\$_rl -confirm:$False
        }
        WindowsBase.Log "Removed all InstallationBehavior rules"
    }
}


<#========================== multi agents ========================================

#Install Agents
function InstallAgents($_testType, $Agents){
    AddESXAgents $Agents
    if ($_testType -eq "Binary"){
        # Install ESXAagent
        InstallAgentsState $Agents
        PRM.Replicate
    }
    elseif($_testType -eq "MSI"){
        # Install ESXAagent
        $ipn = InstallAgentsPolicy $Agents
        PRM.SubmitPolicy $ipn
        PRM.Replicate
    }
    else{
        "Unknown test type"
        WindowsBase.WriteResult $result_log "Unknown test type" "Failed" "TestType"
        Exit 1
    }
}

 function AddESXAgents($Agents){
    foreach ($Agent in $Agents){
        if ($Agent.Name){
            AddESXAgentHost $Agent.HostName $Agent.Creds.Name $Agent.Creds.Pass
        }
    }
}

 function InstallAgentsState($Agents){
    foreach ($Agent in $Agents){
        if ($Agent.Name){
            $_agn = $Agent.HostName 
            (gi prm::computers\$_agn) - "RolePending"
        }
    }
}
 
 function InstallAgentsPolicy($Agents){
    $policy_name = "InstallBClnt"
    $rule_pref = "inst_rule_"
    $Behavior = "Install, Remove"
    $Path= "c:\temp"
    
    removeInstallPolicies
    
    $p=New-Item prm::policies\$policy_name -PolicyType "Installation" -Computers PRM.AdminServer
    (gi prm::policies\$policy_name).ComponentMask = "InstallationServer"
    WindowsBase.Log "Added installation policy: $policy_name"
    foreach ($Agent in $Agents){
        if ($Agent.Name){
            $_rname = ($rule_pref + $Agent.HostName)
            $p=New-Item prm::rules\$_rname  -RuleType "InstallationBehavior" -Policies $policy_name -Properties @{Behavior=$Behavior; Path=$Path; Destinations=$Agent.HostName}
            WindowsBase.Log ("Added InstallationBehavior rule for: " + $Agent.Name)
        }
    }    
    WindowsBase.Log "Adding InstallAgentsPolicy $policy_name completed."    
    return $policy_name
}

function get_vicreds($vi_name){
    foreach ($VHost in $test_data.Test.VHosts.VHost){
        if ($VHost.Name -eq $vi_name){return, @($VHost.Name, $VHost.User, $VHost.Pass)}
    }
}

function get_vihost($vi_name){
    foreach ($VHost in $test_data.Test.VHosts.VHost){
        if ($VHost.Name -eq $vi_name){return, $VHost}
    }
}

function get_agent($vi_name){
    foreach ($Agent in $test_data.Test.Agents.Agent){
        if ($Agent.Name -eq $vi_name){return, $Agent}
    }
}

#============================== end =============================================#>