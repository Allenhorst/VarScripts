@echo off
set PATH=%CAF_BIN_DIR%;%CAF_LIB_DIR%;%PATH%
call "%CAF_BIN_DIR%\InstallProvider.exe" %*
exit 0