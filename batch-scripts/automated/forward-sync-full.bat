@echo off
REM ============================================================
REM PowerCA Mobile - Automated Forward Sync (Full Mode)
REM Desktop PostgreSQL -> Supabase Cloud
REM Schedule: Daily at 10:00 AM
REM ============================================================

cd /d "D:\PowerCA Mobile"

REM Create logs directory if not exists
if not exist "logs" mkdir logs

REM Set log file with timestamp
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set LOGFILE=logs\forward-sync-full_%TIMESTAMP%.log

echo ============================================================ >> "%LOGFILE%"
echo PowerCA Mobile - Forward Sync (Full Mode) >> "%LOGFILE%"
echo Started: %date% %time% >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"
echo. >> "%LOGFILE%"

REM Run full sync with logging
node sync/production/runner-staging.js --mode=full >> "%LOGFILE%" 2>&1

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo. >> "%LOGFILE%"
    echo [OK] Full sync completed successfully at %time% >> "%LOGFILE%"
    echo ============================================================ >> "%LOGFILE%"
) else (
    echo. >> "%LOGFILE%"
    echo [ERROR] Full sync failed with error code %ERRORLEVEL% at %time% >> "%LOGFILE%"
    echo ============================================================ >> "%LOGFILE%"
)

exit /b %ERRORLEVEL%
