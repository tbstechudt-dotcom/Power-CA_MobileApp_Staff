@echo off
REM ============================================================
REM PowerCA Mobile - Install All Scheduled Tasks
REM Creates Windows Task Scheduler tasks for all sync processes
REM Run this script as Administrator
REM ============================================================

echo ============================================================
echo PowerCA Mobile - Task Scheduler Installation
echo ============================================================
echo.
echo This script will create the following scheduled tasks:
echo   1. PowerCA-PreSyncDesktopViews   (09:45 AM daily)
echo   2. PowerCA-ForwardSyncFull       (10:00 AM daily)
echo   3. PowerCA-ForwardSyncIncremental (Every 2 hours 8AM-6PM)
echo   4. PowerCA-ReverseSync           (05:30 PM daily)
echo   5. PowerCA-PostSyncToParent      (06:00 PM daily)
echo   6. PowerCA-SyncStatusReport      (07:00 PM daily)
echo.

REM Check for admin rights
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] This script requires Administrator privileges.
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)

set SCRIPT_DIR=%~dp0
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

echo [INFO] Script directory: %SCRIPT_DIR%
echo.

REM Task 1: Pre-Sync Desktop Views (09:45 AM)
echo [1/6] Creating PowerCA-PreSyncDesktopViews task...
schtasks /create /tn "PowerCA-PreSyncDesktopViews" /tr "\"%SCRIPT_DIR%\01-pre-sync-desktop-views.bat\"" /sc daily /st 09:45 /ru SYSTEM /f
if %ERRORLEVEL% EQU 0 (echo [OK] Task created) else (echo [ERROR] Failed to create task)

REM Task 2: Forward Sync Full (10:00 AM)
echo [2/6] Creating PowerCA-ForwardSyncFull task...
schtasks /create /tn "PowerCA-ForwardSyncFull" /tr "\"%SCRIPT_DIR%\02-forward-sync-full.bat\"" /sc daily /st 10:00 /ru SYSTEM /f
if %ERRORLEVEL% EQU 0 (echo [OK] Task created) else (echo [ERROR] Failed to create task)

REM Task 3: Forward Sync Incremental (Every 2 hours during business hours)
echo [3/6] Creating PowerCA-ForwardSyncIncremental task...
schtasks /create /tn "PowerCA-ForwardSyncIncremental" /tr "\"%SCRIPT_DIR%\03-forward-sync-incremental.bat\"" /sc daily /st 12:00 /ri 120 /du 10:00 /ru SYSTEM /f
if %ERRORLEVEL% EQU 0 (echo [OK] Task created) else (echo [ERROR] Failed to create task)

REM Task 4: Reverse Sync (05:30 PM)
echo [4/6] Creating PowerCA-ReverseSync task...
schtasks /create /tn "PowerCA-ReverseSync" /tr "\"%SCRIPT_DIR%\04-reverse-sync.bat\"" /sc daily /st 17:30 /ru SYSTEM /f
if %ERRORLEVEL% EQU 0 (echo [OK] Task created) else (echo [ERROR] Failed to create task)

REM Task 5: Post-Sync to Parent (06:00 PM)
echo [5/6] Creating PowerCA-PostSyncToParent task...
schtasks /create /tn "PowerCA-PostSyncToParent" /tr "\"%SCRIPT_DIR%\05-post-sync-to-parent.bat\"" /sc daily /st 18:00 /ru SYSTEM /f
if %ERRORLEVEL% EQU 0 (echo [OK] Task created) else (echo [ERROR] Failed to create task)

REM Task 6: Sync Status Report (07:00 PM)
echo [6/6] Creating PowerCA-SyncStatusReport task...
schtasks /create /tn "PowerCA-SyncStatusReport" /tr "\"%SCRIPT_DIR%\06-sync-status-report.bat\"" /sc daily /st 19:00 /ru SYSTEM /f
if %ERRORLEVEL% EQU 0 (echo [OK] Task created) else (echo [ERROR] Failed to create task)

echo.
echo ============================================================
echo All scheduled tasks created successfully!
echo.
echo To view tasks: Open Task Scheduler and look for "PowerCA-*"
echo To modify times: Right-click task -> Properties -> Triggers
echo ============================================================

pause
