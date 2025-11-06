@echo off
REM ============================================================
REM PowerCA Mobile - Incremental Forward Sync (One-Click)
REM Desktop PostgreSQL → Supabase Cloud
REM ============================================================

echo.
echo ============================================================
echo  PowerCA Mobile - INCREMENTAL FORWARD SYNC
echo  Desktop PostgreSQL -^> Supabase Cloud
echo ============================================================
echo.
echo  Mode: INCREMENTAL SYNC (only changed records)
echo  Safety: STAGING TABLE PATTERN (production data protected)
echo  Time: ~30-60 seconds (much faster than full sync)
echo.
echo  Note: Mobile-only PK tables will auto-force FULL mode
echo        (jobshead, jobtasks, taskchecklist, workdiary)
echo.
echo ============================================================
echo.

REM Change to project directory
cd /d "D:\PowerCA Mobile"

REM Check if node is available
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Node.js not found in PATH!
    echo Please install Node.js or add it to your PATH environment variable.
    pause
    exit /b 1
)

REM Check if sync engine exists
if not exist "sync\production\runner-staging.js" (
    echo ERROR: Sync engine not found!
    echo Expected path: sync\production\runner-staging.js
    pause
    exit /b 1
)

REM Run incremental forward sync
echo Starting incremental forward sync...
echo.
node sync\production\runner-staging.js --mode=incremental

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================================
    echo  ✓ INCREMENTAL SYNC COMPLETED SUCCESSFULLY!
    echo ============================================================
    echo.
) else (
    echo.
    echo ============================================================
    echo  ✗ SYNC FAILED - Check error messages above
    echo ============================================================
    echo.
)

pause
