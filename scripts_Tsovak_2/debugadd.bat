:: Script-InstallRemoteDebugger
ECHO OFF
cls
ECHO Mounting remote folder...

net use V: "\\fs-msk\distributives"  /user:paragon\saakyan nDds4fq7 /y

timeout /T 20

:: Determin processor architecture
SET bit=x86
IF EXIST "%SystemDrive%\Program Files (x86)" (
SET bit=x64
)
:: Remote Debugging Tools
ECHO Remote Debugging Tools Installing...
rem Sleeping for 5 sec...
timeout /T 6
cmd /c "V:\microsoft-visual-studio-10.0\en_visual_studio_2010_premium_x86_dvd_509357\Remote Debugger\rdbgsetup_%bit%.exe" /q
ECHO Configure Remote Debugging Tools Service...
ECHO Adding user Debugger...
net user Debugger Qwerty123 /add /EXPIRES:NEVER /y
net user Debugger /passwordchg:no /y
WMIC USERACCOUNT WHERE "Name='Debugger'" SET PasswordExpires=FALSE
net localgroup Administrators Debugger /add /y
"C:\RKTools\Program Files\Windows Resource Kits\Tools\ntrights.exe" -u Debugger +r SeServiceLogonRight
ECHO Configure service...
sc config msvsmon100 start= auto obj= .\Debugger password= Qwerty123

:: Adding new firewall policies
IF %PROCESSOR_ARCHITECTURE%==AMD64 (
	netsh firewall add allowedprogram name = "MSVSMON_PRG_x86" program = "C:\Program Files\Microsoft Visual Studio 10.0\Common7\IDE\Remote Debugger\x86\msvsmon.exe" mode = Enable profile = ALL scope = ALL
	netsh firewall add allowedprogram name = "MSVSMON_PRG_x64" program = "C:\Program Files\Microsoft Visual Studio 10.0\Common7\IDE\Remote Debugger\x64\msvsmon.exe" mode = Enable profile = ALL scope = ALL
) else (
	netsh firewall add allowedprogram name = "MSVSMON_PRG_x86" program = "C:\Program Files\Microsoft Visual Studio 10.0\Common7\IDE\Remote Debugger\x86\msvsmon.exe" mode = Enable profile = ALL scope = ALL
)
netsh firewall add portopening name = "MSVSMON_PRG_135" protocol = TCP port = 135 mode = ENABLE scope = ALL profile = ALL
netsh firewall add portopening name = "MSVSMON_PRG_137" protocol = UDP port = 137 mode = ENABLE scope = ALL profile = ALL
netsh firewall add portopening name = "MSVSMON_PRG_138" protocol = UDP port = 138 mode = ENABLE scope = ALL profile = ALL
netsh firewall add portopening name = "MSVSMON_PRG_139" protocol = TCP port = 139 mode = ENABLE scope = ALL profile = ALL
netsh firewall add portopening name = "MSVSMON_PRG_445" protocol = TCP port = 445 mode = ENABLE scope = ALL profile = ALL
netsh firewall add portopening name = "MSVSMON_PRG_500" protocol = UDP port = 500 mode = ENABLE scope = ALL profile = ALL
netsh firewall add portopening name = "MSVSMON_PRG_4500" protocol = UDP port = 4500 mode = ENABLE scope = ALL profile = ALL
netsh firewall add portopening name = "MSVSMON_PRG_80" protocol = TCP port = 80 mode = ENABLE scope = ALL profile = ALL
::
ECHO Ok. Unmounting...
net use V: /DELETE /y
ECHO Exiting
exit 0