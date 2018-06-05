param (
   [string]$cmd,
   [string]$username = $null,
   [string]$password = $null,
   [string]$brokerAddr = $null,
   [string]$startupType = $null,
   [switch]$help = $false
)

$ErrorActionPreference = "Stop"

function prtHeader {
   Param(
      [Parameter(Mandatory=$true)]
      [string]$header1
   )

   Write-Host "*************************"
   Write-Host "***"
   Write-Host "*** $header1"
   Write-Host "***"
   Write-Host "*************************"
}

function configAmqp {
   Param(
      [Parameter(Mandatory=$true)]
      [string]$username,
      [Parameter(Mandatory=$true)]
      [string]$password,
      [Parameter(Mandatory=$true)]
      [string]$brokerAddr
   )

   sourceCafenv
   $uriAmqpFile = "$env:input_dir\persistence\protocol\amqpBroker_default\uri_amqp.txt"
   (Get-Content $uriAmqpFile) -Replace '#amqpUsername#',"$username" -Replace '#amqpPassword#',"$password" -Replace '#brokerAddr#',"$brokerAddr" | Set-Content $uriAmqpFile
}

function enableCaf {
   Param(
      [Parameter(Mandatory=$true)]
      [string]$username,
      [Parameter(Mandatory=$true)]
      [string]$password
   )

   sourceCafenv
   $uriAmqpFile = "$env:input_dir\persistence\protocol\amqpBroker_default\uri_amqp.txt"
   (Get-Content $uriAmqpFile) -Replace '#amqpUsername#',"$username" -Replace '#amqpPassword#',"$password" | Set-Content $uriAmqpFile
}

function setBroker {
   Param(
      [Parameter(Mandatory=$true)]
      [string]$brokerAddr
   )

   sourceCafenv
   $uriAmqpFile = "$env:input_dir\persistence\protocol\amqpBroker_default\uri_amqp.txt"
   (Get-Content $uriAmqpFile) -Replace '#brokerAddr#',"$brokerAddr" | Set-Content $uriAmqpFile
}

function setListenerConfigured {
   sourceCafenv
   "Manual" | Out-File "$env:input_dir/monitor/listenerConfiguredStage1.txt"
}

function setListenerStartupType {
   Param(
      [Parameter(Mandatory=$true)]
      [string]$startupType
   )

   sourceCafenv
   $appconfigFile = "$env:config_dir\ma-appconfig"
   (Get-Content $appconfigFile) -Replace 'listener_startup_type=.*', "listener_startup_type=$startupType" | Set-Content $appconfigFile
}

function sourceCafenv {
   $cafenvAppconfig = "$Env:ProgramData\VMware\VMware CAF\pme\config\cafenv-appconfig"
   if (! (Test-Path "$cafenvAppconfig")) {
      $cafenvAppconfig = "$Env:ProgramData\VMware\VMWare Tools\VMware CAF\pme\config\cafenv-appconfig"
      if (! (Test-Path "$cafenvAppconfig")) {
         $cafenvAppconfig = "$Env:ProgramData\VMware\VMware CAF\Client\config\cafenv-appconfig"
         if (! (Test-Path "$cafenvAppconfig")) {
            Write-Error "*** cafenv-appconfig file not found - $cafenvAppconfig"
         }
      }
   }

   $tmpCafenv = "$Env:TEMP/_cafenv-appconfig_.ps1"
   (Get-Content "$cafenvAppconfig") -Replace "^([a-z_].*)=(.*$)", '$Env:$1 = "$2"' | Select-String -Pattern "\[globals\]" -NotMatch | Set-Content "$tmpCafenv"
   . "$tmpCafenv"
}

function validatePathExists {
   Param(
      [Parameter(Mandatory=$true)]
      [string]$path
   )

   if (! (Test-Path $path)) {
      throw [System.IO.FileNotFoundException] "$path not found."
   }
}

function validateEnvVariable {
   Param(
      [Parameter(Mandatory=$true)]
      [string]$envVariable
   )

   if (! (Test-Path Env:$envVariable)) {
      Write-Error "$envVariable - envVariable is not set"
   }
}

function prtHelp {
   $scriptName = Split-Path $MyInvocation.scriptName -Leaf
   Write-Host "*** $scriptName -cmd command - Runs commands that help with debugging CAF"
   Write-Host "  * configAmqp brokerUsername brokerPassword brokerAddress  Configures AMQP"
   Write-Host "  * enableCaf brokerUsername brokerPassword                 Enables CAF"
   Write-Host "  * setBroker brokerAddress                                 Sets the Broker into the CAF config file"
   Write-Host "  * setListenerConfigured                                   Indicates that the Listener is configured"
   Write-Host "  * setListenerStartupType startupType                      Sets the startup type used by the Listener (Manual, Automatic)"
   Write-Host ""
   Write-Host "  * getAmqpQueueName                                        Gets the AMQP Queue Name"
   Write-Host ""
   Write-Host "  * validateInstall                                         Validates that the files are in the right locations and have the right permissions"
   Write-Host ""
   Write-Host "  * clearCaches                                             Clears the CAF caches"
}

function validateInstall {
   sourceCafenv
   validateServices
   validatePathExistsBin
   validatePathExistsConfig
   validatePathExistsScripts
   validatePathExistsInstall
   validatePathExistsInvokers
   validatePathExistsProviderReg
}

function validatePathExistsBin {
   validatePathExists "$env:bin_dir/CafIntegrationSubsys.dll"
   validatePathExists "$env:bin_dir/CommAmqpIntegration.dll"
   validatePathExists "$env:bin_dir/CommAmqpIntegrationSubsys.dll"
   validatePathExists "$env:bin_dir/CommAmqpListener.exe"
   validatePathExists "$env:bin_dir/CommIntegrationSubsys.dll"
   validatePathExists "$env:bin_dir/ConfigProvider.exe"
   validatePathExists "$env:bin_dir/Framework.dll"
   validatePathExists "$env:bin_dir/glib-2.0.dll"
   validatePathExists "$env:bin_dir/gthread-2.0.dll"
   validatePathExists "$env:bin_dir/iconv.dll"
   validatePathExists "$env:bin_dir/InstallProvider.exe"
   validatePathExists "$env:bin_dir/IntegrationSubsys.dll"
   validatePathExists "$env:bin_dir/intl.dll"
   validatePathExists "$env:bin_dir/log4cpp.dll"
   validatePathExists "$env:bin_dir/MaIntegrationSubsys.dll"
   validatePathExists "$env:bin_dir/ManagementAgentHost.exe"
   validatePathExists "$env:bin_dir/ProviderFx.dll"
   validatePathExists "$env:bin_dir/rabbitmq.4.dll"
   validatePathExists "$env:bin_dir/RemoteCommandProvider.exe"
   validatePathExists "$env:bin_dir/TestInfraProvider.exe"
   validatePathExists "$env:bin_dir/VgAuthIntegrationSubsys.dll"
}

function validatePathExistsConfig {
   validatePathExists "$env:config_dir/cafenv-appconfig"
   validatePathExists "$env:config_dir/CommAmqpListener-appconfig"
   validatePathExists "$env:config_dir/CommAmqpListener-context-amqp.xml"
   validatePathExists "$env:config_dir/CommAmqpListener-context-common.xml"
   validatePathExists "$env:config_dir/CommAmqpListener-context-tunnel.xml"
   validatePathExists "$env:config_dir/CommAmqpListener-log4cpp_config"
   validatePathExists "$env:config_dir/IntBeanConfigFile.xml"
   validatePathExists "$env:config_dir/ma-appconfig"
   validatePathExists "$env:config_dir/ma-context.xml"
   validatePathExists "$env:config_dir/ma-log4cpp_config"
   validatePathExists "$env:config_dir/providerFx-appconfig"
   validatePathExists "$env:config_dir/providerFx-log4cpp_config"
   validatePathExists "$env:config_dir/vgauth.conf"
}

function validatePathExistsScripts {
   validatePathExists "$env:config_dir/../scripts/setUpVgAuth.bat"
   validatePathExists "$env:config_dir/../scripts/start-listener.bat"
   validatePathExists "$env:config_dir/../scripts/start-ma.bat"
   validatePathExists "$env:config_dir/../scripts/start-VGAuthService.bat"
   validatePathExists "$env:config_dir/../scripts/stop-listener.bat"
   validatePathExists "$env:config_dir/../scripts/stop-ma.bat"
   validatePathExists "$env:config_dir/../scripts/stop-VGAuthService.bat"
   validatePathExists "$env:config_dir/../scripts/tearDownVgAuth.bat"
   validatePathExists "$env:config_dir/../scripts/vgAuth.bat"
}

function validatePathExistsInstall {
   validatePathExists "$env:config_dir/../install/caf-dbg.ps1"
   validatePathExists "$env:config_dir/../install/GuidGen.vbs"
   validatePathExists "$env:config_dir/../install/postInstall.bat"
}

function validatePathExistsInvokers {
   validatePathExists "$env:invokers_dir/cafTestInfra_CafTestInfraProvider_1_0_0.bat"
   validatePathExists "$env:invokers_dir/caf_ConfigProvider_1_0_0.bat"
   validatePathExists "$env:invokers_dir/caf_InstallProvider_1_0_0.bat"
   validatePathExists "$env:invokers_dir/caf_RemoteCommandProvider_1_0_0.bat"
}

function validatePathExistsProviderReg {
   validatePathExists "$env:input_dir/providerReg/cafTestInfra_CafTestInfraProvider_1_0_0.xml"
   validatePathExists "$env:input_dir/providerReg/caf_ConfigProvider_1_0_0.xml"
   validatePathExists "$env:input_dir/providerReg/caf_InstallProvider_1_0_0.xml"
   validatePathExists "$env:input_dir/providerReg/caf_RemoteCommandProvider_1_0_0.xml"
}

function validateServices {
   $listenerServiceName = "VMwareCAFCommAmqpListener"
   $listenerService = Get-Service | Where-Object {$_.ServiceName -eq "$listenerServiceName" -and ($_.Status -eq "Stopped" -or $_.Status -eq "Running")}
   if (! $listenerService) {
      Write-Error "Service must be 'Running' or 'Stopped' - $listenerServiceName"
   }

   $maServiceName = "VMwareCAFManagementAgentHost"
   $maService = Get-Service | Where-Object {$_.ServiceName -eq "$maServiceName" -and $_.Status -eq "Running"}
   if (! $maService) {
      Write-Error "Service must be 'Running' - $maServiceName"
   }
}

function clearCaches() {
   sourceCafenv
   validateEnvVariable "output_dir"
   validateEnvVariable "log_dir"
   validateEnvVariable "bin_dir"

   prtHeader "Clearing the CAF caches"
   Remove-Item -Force -Recurs -ErrorAction SilentlyContinue "$env:output_dir/schemaCache/*"
   Remove-Item -Force -Recurs -ErrorAction SilentlyContinue "$env:output_dir/comm-wrk/*"
   Remove-Item -Force -Recurs -ErrorAction SilentlyContinue "$env:output_dir/providerHost/*"
   Remove-Item -Force -Recurs -ErrorAction SilentlyContinue "$env:output_dir/responses/*"
   Remove-Item -Force -Recurs -ErrorAction SilentlyContinue "$env:output_dir/requests/*"
   Remove-Item -Force -Recurs -ErrorAction SilentlyContinue "$env:output_dir/split-requests/*"
   Remove-Item -Force -Recurs -ErrorAction SilentlyContinue "$env:output_dir/request_state/*"
   Remove-Item -Force -Recurs -ErrorAction SilentlyContinue "$env:output_dir/events/*"
   Remove-Item -Force -Recurs -ErrorAction SilentlyContinue "$env:output_dir/tmp/*"
   Remove-Item -Force -Recurs -ErrorAction SilentlyContinue "$env:output_dir/att/*"
   Remove-Item -Force -Recurs -ErrorAction SilentlyContinue "$env:log_dir/*.log"
   Remove-Item -Force -Recurs -ErrorAction SilentlyContinue "$env:bin_dir/*.log"
}

function getAmqpQueueName() {
   sourceCafenv
   Select-String -Path "$env:config_dir/persistence-appconfig" -Pattern "^reactive_request_amqp_queue_id"
}

if ($help) {
   prtHelp
}

switch ($cmd) {
   "clearCaches" {
      clearCaches
   }
   "configAmqp" {
      configAmqp -username "$username" -password "$password" -brokerAddr "$brokerAddr"
   }
   "enableCaf" {
      enableCaf -username "$username" -password "$password"
   }
   "setBroker" {
      setBroker -brokerAddr "$brokerAddr"
   }
   "setListenerConfigured" {
      setListenerConfigured
   }
   "setListenerStartupType" {
      setListenerStartupType -startupType "$startupType"
   }
   "validateInstall" {
      validateInstall
   }
   "getAmqpQueueName" {
      getAmqpQueueName
   }
   default {
      prtHelp
   }
}
