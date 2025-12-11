@echo off
REM ============================================================
REM PowerCA Mobile - Uninstall All Scheduled Tasks
REM Removes all PowerCA sync tasks from Task Scheduler
REM Run this script as Administrator
REM ============================================================

echo ============================================================
echo PowerCA Mobile - Task Scheduler Uninstallation
echo ============================================================
echo.
echo This script will remove all PowerCA scheduled tasks.
echo.

REM Check for admin rights
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] This script requires Administrator privileges.
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo Removing scheduled tasks...
echo.

schtasks /delete /tn "PowerCA-PreSyncDesktopViews" /f 2>nul
if %ERRORLEVEL% EQU 0 (echo [OK] Removed PowerCA-PreSyncDesktopViews) else (echo [SKIP] Task not found)

schtasks /delete /tn "PowerCA-ForwardSyncFull" /f 2>nul
if %ERRORLEVEL% EQU 0 (echo [OK] Removed PowerCA-ForwardSyncFull) else (echo [SKIP] Task not found)

schtasks /delete /tn "PowerCA-ForwardSyncIncremental" /f 2>nul
if %ERRORLEVEL% EQU 0 (echo [OK] Removed PowerCA-ForwardSyncIncremental) else (echo [SKIP] Task not found)

schtasks /delete /tn "PowerCA-ReverseSync" /f 2>nul
if %ERRORLEVEL% EQU 0 (echo [OK] Removed PowerCA-ReverseSync) else (echo [SKIP] Task not found)

schtasks /delete /tn "PowerCA-PostSyncToParent" /f 2>nul
if %ERRORLEVEL% EQU 0 (echo [OK] Removed PowerCA-PostSyncToParent) else (echo [SKIP] Task not found)

schtasks /delete /tn "PowerCA-SyncStatusReport" /f 2>nul
if %ERRORLEVEL% EQU 0 (echo [OK] Removed PowerCA-SyncStatusReport) else (echo [SKIP] Task not found)

echo.
echo ============================================================
echo All PowerCA scheduled tasks have been removed.
echo ============================================================

pause
