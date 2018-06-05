@echo off

if "%~1" == "help" (
   call :helpMessage %~1
)

set processName=CommAmqpListener
set processPath=%ProgramFiles%\VMware\VMware CAF\PME\bin\%processName%.exe
set serviceName=VMwareCAFCommAmqpListener

FOR /f "delims=" %%x in ('tasklist ^| findstr "%processName%"') do set processProc=%%x
if not "%processProc%" == "" (
   echo Process already running - %processName%
   exit /B 1
)

set startType=%~1
if "%startType%" == "" (
   echo net start %serviceName%
   net start %serviceName%
) else if "%startType%" == "service" (
   echo net start %serviceName%
   net start %serviceName%
) else if "%startType%" == "background" (
   echo %processPath%
   %processPath%
) else if "%startType%" == "foreground" (
   echo %processPath% -n
   %processPath% -n
)

goto:eof

:helpMessage
echo *** %0 %1
echo   Starts AMQP Communication
echo     startType: How to start AMQP Communication (service, background, foreground) [default: service]
exit /B 0
