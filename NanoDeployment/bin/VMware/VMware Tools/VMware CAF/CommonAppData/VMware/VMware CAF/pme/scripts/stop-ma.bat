@echo off

if "%~1" == "help" (
   call :helpMessage %~1
)

set processName=ManagementAgentHost
set serviceName=VMwareCAFManagementAgentHost

for /f "tokens=2 delims=," %%x in ('tasklist /nh /fi "imageName eq %processName%" /fo csv') do set pid=%%x
if "%pid%" == "" (
   echo Process not running - %processName%
   exit /B 1
)

set stopType=%~1
if "%stopType%" == "" (
   echo net stop %serviceName%
   net stop %serviceName%
) else if "%stopType%" == "service" (
   echo net stop %serviceName%
   net stop %serviceName%
) else if "%stopType%" == "process" (
   echo Killing process - %processName%, pid: %pid%
   taskkill /pid %pid% /f
)

goto:eof

:helpMessage
echo *** %0 %1
echo   Stops the Management Agent
echo     stopType: How to stop the Management Agent (service, process) [default: service]
exit /B 0
