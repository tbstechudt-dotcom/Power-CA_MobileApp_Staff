@echo off
REM ============================================================
REM PowerCA Mobile - Complete Sync Workflow
REM Runs all sync steps in sequence
REM Schedule: For manual runs or daily complete sync
REM ============================================================

cd /d "D:\PowerCA Mobile"

REM Create logs directory if not exists
if not exist "logs" mkdir logs

REM Set log file with timestamp
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set LOGFILE=logs\complete-sync-workflow_%TIMESTAMP%.log

echo ============================================================
echo PowerCA Mobile - Complete Sync Workflow
echo Started: %date% %time%
echo Log file: %LOGFILE%
echo ============================================================

echo ============================================================ >> "%LOGFILE%"
echo PowerCA Mobile - Complete Sync Workflow >> "%LOGFILE%"
echo Started: %date% %time% >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"
echo. >> "%LOGFILE%"

REM Step 1: Pre-sync Desktop Views
echo [1/5] Running pre-sync desktop views...
echo [1/5] Running pre-sync desktop views... >> "%LOGFILE%"
node sync/pre-sync-desktop-views.js >> "%LOGFILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Pre-sync failed, aborting workflow
    echo [ERROR] Pre-sync failed, aborting workflow >> "%LOGFILE%"
    goto :error
)
echo [OK] Pre-sync completed
echo [OK] Pre-sync completed >> "%LOGFILE%"
echo. >> "%LOGFILE%"

REM Step 2: Forward Sync (Full)
echo [2/5] Running forward sync (full mode)...
echo [2/5] Running forward sync (full mode)... >> "%LOGFILE%"
node sync/production/runner-staging.js --mode=full >> "%LOGFILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Forward sync failed, aborting workflow
    echo [ERROR] Forward sync failed, aborting workflow >> "%LOGFILE%"
    goto :error
)
echo [OK] Forward sync completed
echo [OK] Forward sync completed >> "%LOGFILE%"
echo. >> "%LOGFILE%"

REM Step 3: Reverse Sync
echo [3/5] Running reverse sync...
echo [3/5] Running reverse sync... >> "%LOGFILE%"
node sync/production/reverse-sync-engine.js >> "%LOGFILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Reverse sync failed, continuing workflow
    echo [ERROR] Reverse sync failed, continuing workflow >> "%LOGFILE%"
)
echo [OK] Reverse sync completed
echo [OK] Reverse sync completed >> "%LOGFILE%"
echo. >> "%LOGFILE%"

REM Step 4: Post-sync Insert to Parent
echo [4/5] Running post-sync insert to parent...
echo [4/5] Running post-sync insert to parent... >> "%LOGFILE%"
node sync/post-sync-insert-to-parent.js >> "%LOGFILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Post-sync insert failed, continuing workflow
    echo [ERROR] Post-sync insert failed, continuing workflow >> "%LOGFILE%"
)
echo [OK] Post-sync insert completed
echo [OK] Post-sync insert completed >> "%LOGFILE%"
echo. >> "%LOGFILE%"

REM Step 5: Generate Status Report
echo [5/5] Generating sync status report...
echo [5/5] Generating sync status report... >> "%LOGFILE%"
node sync/sync-status-report.js >> "%LOGFILE%" 2>&1
echo [OK] Status report generated
echo [OK] Status report generated >> "%LOGFILE%"
echo. >> "%LOGFILE%"

echo ============================================================
echo Complete Sync Workflow finished successfully!
echo Finished: %date% %time%
echo ============================================================

echo ============================================================ >> "%LOGFILE%"
echo Complete Sync Workflow finished successfully! >> "%LOGFILE%"
echo Finished: %date% %time% >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"

exit /b 0

:error
echo ============================================================
echo Complete Sync Workflow failed!
echo Check log file: %LOGFILE%
echo ============================================================
exit /b 1
