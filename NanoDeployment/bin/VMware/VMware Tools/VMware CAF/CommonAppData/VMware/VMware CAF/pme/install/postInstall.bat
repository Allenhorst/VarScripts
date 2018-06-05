@echo off
setlocal enableextensions enabledelayedexpansion

set numArgs=0
for %%x in (%*) do set /A numArgs+=1

if "%~1" == "help" (
   echo "*** %~dpnx0 cafProgramFiles cafProgramData BrokerAddr"
   echo  "Installs everything necessary for a test PME"
   echo    "cafProgramFiles: Directory for the program files (default: ProgramFiles/VMware/VMware CAF/pme)"
   echo    "cafProgramData: Directory for program data (default: ProgramData/VMware/VMware CAF/pme)"
   echo    "BrokerAddr: The address of the broker (default: 10.25.91.81)"
   exit /b 1
)

set thisDir=%~dp0
set cafProgramFiles=%~1
set cafProgramData=%~2
set brokerAddr=%~3

if "!cafProgramFiles!" == "" set cafProgramFiles=%ProgramFiles%/VMware/VMware CAF/pme
if "!cafProgramData!" == "" set cafProgramData=%ProgramData%/VMware/VMware CAF/pme
if "!brokerAddr!" == "" set brokerAddr=#brokerAddr#

set cafProgramFiles=%cafProgramFiles:\=/%
set cafProgramData=%cafProgramData:\=/%

set libDir=!cafProgramFiles!/bin
set binDir=!cafProgramFiles!/bin
set inputDir=!cafProgramData!/data/input
set outputDir=!cafProgramData!/data/output

set providersDir=!inputDir!/providers
set invokersDir=!inputDir!/invokers
set amqpBrokerDir=!inputDir!/persistence/protocol/amqpBroker_default

set logDir=!outputDir!/log

set configDir=!cafProgramData!/config
set installDir=!cafProgramData!/install
set scriptDir=!cafProgramData!/scripts

if not exist "!amqpBrokerDir!" mkdir "!amqpBrokerDir!"
echo | set /p dummyName="amqp:#amqpUsername#:#amqpPassword#@!brokerAddr!:5672/reactiveRequestAmqpQueueId" > "!amqpBrokerDir!/uri_amqp.txt"
echo | set /p dummyName="tunnel:agentId1:bogus@localhost:6672/reactiveRequestAmqpQueueId" > "!amqpBrokerDir!/uri_tunnel.txt"

pushd "!thisDir!"
call:setupCafenvConfig
popd

goto:eof

:setupCafenvConfig
   set cafenvConfigFile=!configDir!/cafenv-appconfig

   call::replaceString "!cafenvConfigFile!" "@libDir@" "!libDir!"
   call::replaceString "!cafenvConfigFile!" "@binDir@" "!binDir!"
   call::replaceString "!cafenvConfigFile!" "@configDir@" "!configDir!"
   call::replaceString "!cafenvConfigFile!" "@inputDir@" "!inputDir!"
   call::replaceString "!cafenvConfigFile!" "@outputDir@" "!outputDir!"
   call::replaceString "!cafenvConfigFile!" "@logDir@" "!logDir!"
   call::replaceString "!cafenvConfigFile!" "@invokersDir@" "!invokersDir!"
   call::replaceString "!cafenvConfigFile!" "@providersDir@" "!providersDir!"
goto:eof

:replaceString
   set numArgs=0
   for %%x in (%*) do set /A numArgs+=1
   if not %numArgs% == 3 (
      echo "usage: %0 Filename SearchText ReplaceText"
      exit /b 1
   )

   setlocal EnableDelayedExpansion

   :: Changing directory because "rename" (see below) cannot
   :: "rename files across drives or to move files to a different directory location".
   cd %~dp1
   set inFile=%~nx1
   set searchText=%~2
   set replaceText=%~3
   set tmpFileRepl=test_out.txt

   for %%A IN ("%tmpFileRepl%") DO del %%A 2>nul
   for /f "tokens=*" %%- in (%inFile%) do (
      set str=%%-&&call :NEXT
   )

   del "%inFile%"
   rename "%tmpFileRepl%" "%inFile%"
   goto:eof

   :NEXT
      set str=!str:%searchText%=%replaceText%!
      echo !str!>> "%tmpFileRepl%"
   goto:eof
goto:eof
