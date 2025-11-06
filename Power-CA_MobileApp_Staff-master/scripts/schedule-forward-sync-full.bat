@echo off
REM PowerCA Mobile - Forward Sync (Full Mode)
REM Syncs all data from Desktop PostgreSQL to Supabase Cloud
REM Schedule: Daily at 2:00 AM

echo ============================================================
echo PowerCA Mobile - Forward Sync (Full Mode)
echo Started: %date% %time%
echo ============================================================

cd /d "D:\PowerCA Mobile"

REM Create logs directory if not exists
if not exist "logs" mkdir logs

REM Set log file with timestamp
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set LOGFILE=logs\forward-sync-full_%TIMESTAMP%.log

echo Running full sync...
echo Log file: %LOGFILE%

REM Run full sync with logging
node sync/production/runner-staging.js --mode=full >> "%LOGFILE%" 2>&1

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo [OK] Forward sync completed successfully
    echo [OK] Full sync completed at %time% >> "%LOGFILE%"
) else (
    echo [ERROR] Forward sync failed with error code %ERRORLEVEL%
    echo [ERROR] Full sync failed at %time% >> "%LOGFILE%"

    REM Optional: Send email notification on failure
    REM powershell -File scripts/send-error-notification.ps1 -LogFile "%LOGFILE%"
)

echo ============================================================
echo Finished: %date% %time%
echo ============================================================

exit /b %ERRORLEVEL%
