sc config wuauserv start= disabled
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t reg_dword /d 1 /f
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=yes
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CrashControl" /v AutoReboot /t REG_DWORD /d 0 /f
if not exist "%SYSTEMDRIVE%\CrashDumps" ( mkdir "%SYSTEMDRIVE%\CrashDumps" ) else ( echo "%SYSTEMDRIVE%\CrashDumps" folder already exist )
echo yes|cacls "%SYSTEMDRIVE%\CrashDumps" /grant Everyone:F
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps" /v DumpFolder /t REG_EXPAND_SZ /d "%SYSTEMDRIVE%\CrashDumps" /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps" /v DumpCount /t REG_DWORD /d 20 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps" /v DumpType /t REG_DWORD /d 2 /f

