@echo off
REM PowerCA Mobile - Reverse Sync (Supabase -> Desktop)
REM Syncs mobile-created records from Supabase Cloud to Desktop PostgreSQL
REM Schedule: Every hour

echo ============================================================
echo PowerCA Mobile - Reverse Sync (Supabase -> Desktop)
echo Started: %date% %time%
echo ============================================================

cd /d "D:\PowerCA Mobile"

REM Create logs directory if not exists
if not exist "logs" mkdir logs

REM Set log file with timestamp
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set LOGFILE=logs\reverse-sync_%TIMESTAMP%.log

echo Running reverse sync...
echo Log file: %LOGFILE%

REM Run reverse sync with logging
node sync/production/reverse-sync-engine.js >> "%LOGFILE%" 2>&1

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo [OK] Reverse sync completed successfully
    echo [OK] Reverse sync completed at %time% >> "%LOGFILE%"
) else (
    echo [ERROR] Reverse sync failed with error code %ERRORLEVEL%
    echo [ERROR] Reverse sync failed at %time% >> "%LOGFILE%"

    REM Optional: Send email notification on failure
    REM powershell -File scripts/send-error-notification.ps1 -LogFile "%LOGFILE%"
)

echo ============================================================
echo Finished: %date% %time%
echo ============================================================

exit /b %ERRORLEVEL%
