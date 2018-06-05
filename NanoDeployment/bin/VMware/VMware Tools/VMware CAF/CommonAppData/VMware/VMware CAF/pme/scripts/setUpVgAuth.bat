@echo off

set rootDir=%~dp0\..

echo *** Adding the OS user
net user testuser /add

echo *** Unregistering and re-registering the service to make sure it's registered correctly
net stop "VMVGAuth"
"%rootDir%\bin\VGAuthService.exe" -u
"%rootDir%\bin\VGAuthService.exe" -r

echo *** Starting the service and give it a second to start
net start "VMVGAuth"
ping 1.1.1.1 -n 1 -w 1000 >nul

echo *** Adding the user to the alias store
"%rootDir%\scripts\vgAuth" addUser
