:: install-rvmsetup
::
:: Script to install the rvmSetup service from windows explorer.
:: Usage: Right click on this script and select "Run as Administrator".
::

@echo off
setlocal

:: ----------------------------
:: Check for Administrator privileges
:: ----------------------------
net session >nul 2>&1
if %errorLevel% == 0 goto install
echo This script must be run as Administrator.
goto end

:: ----------------------------
:: Install the service.
:: ----------------------------
:install
"%~dp0rvmSetup" -i

:: ----------------------------
:: Check that it's installed.
:: ----------------------------
sc query rvmSetup > NUL
if errorlevel 1060 goto missing
echo Service installed successfully.
goto end

:missing
echo Error installing service.

:end

:: ----------------------------
:: Pause to show the result.
:: ----------------------------
timeout 5
