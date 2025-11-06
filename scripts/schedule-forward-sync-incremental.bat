@echo off
REM PowerCA Mobile - Forward Sync (Incremental Mode)
REM Syncs only changed records from Desktop PostgreSQL to Supabase Cloud
REM Schedule: Every 4 hours during business hours (8 AM, 12 PM, 4 PM, 8 PM)

echo ============================================================
echo PowerCA Mobile - Forward Sync (Incremental Mode)
echo Started: %date% %time%
echo ============================================================

cd /d "D:\PowerCA Mobile"

REM Create logs directory if not exists
if not exist "logs" mkdir logs

REM Set log file with timestamp
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set LOGFILE=logs\forward-sync-incremental_%TIMESTAMP%.log

echo Running incremental sync...
echo Log file: %LOGFILE%
echo Note: Mobile-PK tables (jobshead, jobtasks, taskchecklist, workdiary) will auto-run in FULL mode

REM Run incremental sync with logging
node sync/production/runner-staging.js --mode=incremental >> "%LOGFILE%" 2>&1

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo [OK] Incremental sync completed successfully
    echo [OK] Incremental sync completed at %time% >> "%LOGFILE%"
) else (
    echo [ERROR] Incremental sync failed with error code %ERRORLEVEL%
    echo [ERROR] Incremental sync failed at %time% >> "%LOGFILE%"

    REM Optional: Send email notification on failure
    REM powershell -File scripts/send-error-notification.ps1 -LogFile "%LOGFILE%"
)

echo ============================================================
echo Finished: %date% %time%
echo ============================================================

exit /b %ERRORLEVEL%
