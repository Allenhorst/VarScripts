@echo off

set rootDir=%~dp0\..

echo *** Removing the user from the alias store
%rootDir%\scripts\vgAuth removeUser

echo *** Stopping the service
net stop "VMVGAuth"

echo *** Removing the OS user
net user testuser /delete
