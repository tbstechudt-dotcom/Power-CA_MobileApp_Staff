@echo off
REM ============================================================
REM PowerCA Mobile - Post-Sync Insert to Parent Tables
REM Inserts mobile data (workdiary, learequest) to parent tables
REM Schedule: After reverse sync (e.g., 6:00 PM)
REM ============================================================

cd /d "D:\PowerCA Mobile"

REM Create logs directory if not exists
if not exist "logs" mkdir logs

REM Set log file with timestamp
set TIMESTAMP=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set LOGFILE=logs\post-sync-to-parent_%TIMESTAMP%.log

echo ============================================================ >> "%LOGFILE%"
echo PowerCA Mobile - Post-Sync Insert to Parent Tables >> "%LOGFILE%"
echo Started: %date% %time% >> "%LOGFILE%"
echo ============================================================ >> "%LOGFILE%"
echo. >> "%LOGFILE%"

REM Run post-sync insert to parent
node sync/post-sync-insert-to-parent.js >> "%LOGFILE%" 2>&1

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo. >> "%LOGFILE%"
    echo [OK] Post-sync insert to parent completed at %time% >> "%LOGFILE%"
    echo ============================================================ >> "%LOGFILE%"
) else (
    echo. >> "%LOGFILE%"
    echo [ERROR] Post-sync insert to parent failed with error code %ERRORLEVEL% at %time% >> "%LOGFILE%"
    echo ============================================================ >> "%LOGFILE%"
)

exit /b %ERRORLEVEL%
