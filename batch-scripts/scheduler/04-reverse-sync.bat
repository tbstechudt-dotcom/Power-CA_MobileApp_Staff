@echo off
REM ============================================================
REM PowerCA Mobile - Reverse Sync
REM Supabase Cloud -> Desktop PostgreSQL
REM Schedule: Daily at 5:30 PM (end of business day)
REM ============================================================

cd /d "D:\PowerCA Mobile"

REM Create logs directory if not exists
if not exist "logs" mkdir logs

REM Set log file with timestamp
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set LOGFILE=logs\reverse-sync_%TIMESTAMP%.log

echo ============================================================ >> "%LOGFILE%"
echo PowerCA Mobile - Reverse Sync (Supabase -> Desktop) >> "%LOGFILE%"
echo Started: %date% %time% >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"
echo. >> "%LOGFILE%"

REM Run reverse sync with logging
node sync/production/reverse-sync-engine.js >> "%LOGFILE%" 2>&1

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo. >> "%LOGFILE%"
    echo [OK] Reverse sync completed successfully at %time% >> "%LOGFILE%"
    echo ============================================================ >> "%LOGFILE%"
) else (
    echo. >> "%LOGFILE%"
    echo [ERROR] Reverse sync failed with error code %ERRORLEVEL% at %time% >> "%LOGFILE%"
    echo ============================================================ >> "%LOGFILE%"
)

exit /b %ERRORLEVEL%
