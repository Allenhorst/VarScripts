@echo off

set numArgs=0
for %%x in (%*) do set /A numArgs+=1

set result=0
if %numArgs% LSS 1 set result=1
if %numArgs% GTR 2 set result=1
if %result% EQU 1 (
	call:helpMessage
	exit /b 1
)

set rootDir=%~dp0\..

set action=%~1
set vgAuthCli=%rootDir%/bin/VGAuthCLI.exe
set cert=%rootDir%/testData/selfSignedCert
set subject="samlTestSubject"
set username="testuser"

if %numArgs% GEQ 2 (
	set username=%~2
)
if %numArgs% GEQ 3 (
	set cert=%~3
)
if %numArgs% GEQ 4 (
	set subject=%~4
)

if "%action%" == "addUser" (
	echo *** Addding %username% ***
	%vgAuthCli% add --global --username=%username% --file %cert% --subject=%subject%
)
if "%action%" == "removeUser" (
	echo *** Removing %username% ***
	%vgAuthCli% remove --username=%username% --file %cert% --subject=%subject%
)
if "%action%" == "listAll" (
	echo *** Listing all users ***
	%vgAuthCli% list
)
if "%action%" == "listUser" (
	echo *** Listing %username% ***
	%vgAuthCli% list --username=%username%
)
if "%action%" == "help" (
	call:helpMessage
	exit /b 1
)

:helpMessage
	echo *** $0 Action {Username} {CertPath} {Subject}
	echo   Manages the VGAuth alias store
	echo     Action: help, addUser, removeUser, listAll, listUser
	echo     Username: The name of the user to add to the alias store
	echo     CertPath: Path to the cert
	echo     Subject: Subject of the cert
goto:eof
