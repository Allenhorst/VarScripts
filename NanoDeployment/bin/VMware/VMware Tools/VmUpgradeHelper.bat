@echo off
rem **********************************************************
rem Copyright 2010 VMware, Inc.  All rights reserved. -- VMware Confidential
rem **********************************************************

setlocal
set cmdpath=%~dp0

rem Translate old commands to the functions exported by the plugin.
if "%PROCESSOR_ARCHITECTURE%" == "AMD64" goto :amd64
if "%PROCESSOR_ARCHITEW6432%" == "AMD64" goto :amd64

if "%1%" == "/s" set cmd=_Save@16
if "%1%" == "/r" set cmd=_Restore@16
goto :run

:amd64
if "%1%" == "/s" set cmd=Save
if "%1%" == "/r" set cmd=Restore

:run
if "%cmd%" == "" goto :error

set PATH=%PATH%;%cmdpath%

rem MS says rundll32.exe does not support spaces in the path to the DLL.
rem So cd to the Tools directory since in most cases our path will contain
rem spaces (C:\Program Files\...).
rem See: http://support.microsoft.com/kb/164787
set cwd=%CD%
cd /d "%cmdpath%"

"%SystemRoot%\system32\rundll32.exe" plugins\vmsvc\hwUpgradeHelper.dll,%cmd%
set err=%ERRORLEVEL%

cd /d "%cwd%"
goto :exit

:error
if "%1" == "" (echo No command provided.) else (echo Unrecognized command: %1%)
set err=1

:exit
exit /b %err%

