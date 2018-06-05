@echo off

set processName=ManagementAgentHost

FOR /f "delims=" %%x in ('tasklist ^| findstr "%processName%"') do set processProc=%%x
if "%processProc%" == "" (
   echo|set /p=false
) else (
   echo|set /p=true
)
