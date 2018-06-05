@echo off

set processName=CommAmqpListener

FOR /f "delims=" %%x in ('tasklist ^| findstr "%processName%"') do set processProc=%%x
if "%processProc%" == "" (
   echo|set /p=false
) else (
   echo|set /p=true
)

exit /B 0
