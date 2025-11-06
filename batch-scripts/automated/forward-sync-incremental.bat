@echo off
REM ============================================================
REM PowerCA Mobile - Automated Forward Sync (Incremental Mode)
REM Desktop PostgreSQL -> Supabase Cloud
REM Schedule: 2x daily - 12:00 PM and 5:00 PM
REM ============================================================

cd /d "D:\PowerCA Mobile"

REM Create logs directory if not exists
if not exist "logs" mkdir logs

REM Set log file with timestamp
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set LOGFILE=logs\forward-sync-incremental_%TIMESTAMP%.log

echo ============================================================ >> "%LOGFILE%"
echo PowerCA Mobile - Forward Sync (Incremental Mode) >> "%LOGFILE%"
echo Started: %date% %time% >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"
echo. >> "%LOGFILE%"
echo Note: Mobile-PK tables (jobshead, jobtasks, taskchecklist, workdiary) >> "%LOGFILE%"
echo       will automatically run in FULL mode to prevent data loss >> "%LOGFILE%"
echo. >> "%LOGFILE%"

REM Run incremental sync with logging
node sync/production/runner-staging.js --mode=incremental >> "%LOGFILE%" 2>&1

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo. >> "%LOGFILE%"
    echo [OK] Incremental sync completed successfully at %time% >> "%LOGFILE%"
    echo ============================================================ >> "%LOGFILE%"
) else (
    echo. >> "%LOGFILE%"
    echo [ERROR] Incremental sync failed with error code %ERRORLEVEL% at %time% >> "%LOGFILE%"
    echo ============================================================ >> "%LOGFILE%"
)

exit /b %ERRORLEVEL%
