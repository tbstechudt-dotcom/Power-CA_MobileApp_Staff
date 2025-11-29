@echo off
REM PowerCA Sync Scheduler - Windows Service Installer
REM Run this as Administrator to install the service

echo.
echo ========================================================
echo   PowerCA Sync Scheduler - Service Installation
echo ========================================================
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires administrator privileges.
    echo.
    echo Please right-click this file and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo Running as Administrator... OK
echo.

:menu
echo What would you like to do?
echo.
echo   1. Install service
echo   2. Uninstall service
echo   3. Start service
echo   4. Stop service
echo   5. Restart service
echo   6. Exit
echo.
set /p choice="Enter your choice (1-6): "

if "%choice%"=="1" goto install
if "%choice%"=="2" goto uninstall
if "%choice%"=="3" goto start
if "%choice%"=="4" goto stop
if "%choice%"=="5" goto restart
if "%choice%"=="6" goto exit
echo Invalid choice. Please try again.
echo.
goto menu

:install
echo.
echo Installing PowerCA Sync Scheduler as Windows Service...
node install-service.js install
echo.
echo Service installed!
echo.
echo IMPORTANT: Configure auto-start by running this command:
echo   sc config "PowerCA Sync Scheduler" start=auto
echo.
pause
goto menu

:uninstall
echo.
echo Uninstalling PowerCA Sync Scheduler service...
node install-service.js uninstall
echo.
pause
goto menu

:start
echo.
echo Starting PowerCA Sync Scheduler service...
node install-service.js start
echo.
echo Service started! Syncs are now running automatically.
echo Check logs at: logs\combined.log
echo.
pause
goto menu

:stop
echo.
echo Stopping PowerCA Sync Scheduler service...
node install-service.js stop
echo.
pause
goto menu

:restart
echo.
echo Restarting PowerCA Sync Scheduler service...
node install-service.js restart
echo.
pause
goto menu

:exit
echo.
echo Goodbye!
echo.
exit /b 0
