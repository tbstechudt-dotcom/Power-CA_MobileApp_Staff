@echo off
REM PowerCA Sync Scheduler - Setup Script
REM This script installs all dependencies needed for the automated sync scheduler

echo.
echo ========================================================
echo   PowerCA Sync Scheduler - Automated Setup
echo ========================================================
echo.

echo [1/4] Installing Node.js dependencies...
cd ..\..
call npm install node-cron winston nodemailer node-windows --save
if errorlevel 1 (
    echo.
    echo ERROR: Failed to install dependencies
    echo Please make sure you have Node.js installed and try again.
    pause
    exit /b 1
)

echo.
echo [2/4] Creating logs directory...
cd sync\scheduler
if not exist logs mkdir logs

echo.
echo [3/4] Verifying configuration...
if not exist clients-config.js (
    echo ERROR: clients-config.js not found!
    echo Please make sure the configuration file exists.
    pause
    exit /b 1
)

echo.
echo [4/4] Testing scheduler (dry run)...
node sync-scheduler.js --help 2>nul
if errorlevel 1 (
    echo.
    echo WARNING: Could not verify scheduler executable
    echo This might be normal on first setup.
)

echo.
echo ========================================================
echo   Setup Complete!
echo ========================================================
echo.
echo Next steps:
echo   1. Configure your 6 clients in clients-config.js
echo   2. Test the scheduler: node sync-scheduler.js
echo   3. Install as service: install-service.bat
echo.
pause
