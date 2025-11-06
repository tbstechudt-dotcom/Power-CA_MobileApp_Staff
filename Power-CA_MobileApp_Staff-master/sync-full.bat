@echo off
REM ============================================================
REM PowerCA Mobile - Full Forward Sync (One-Click)
REM Desktop PostgreSQL → Supabase Cloud
REM ============================================================

echo.
echo ============================================================
echo  PowerCA Mobile - FULL FORWARD SYNC
echo  Desktop PostgreSQL -^> Supabase Cloud
echo ============================================================
echo.
echo  Mode: FULL SYNC (all records)
echo  Safety: STAGING TABLE PATTERN (production data protected)
echo  Time: ~2-3 minutes for all tables
echo.
echo ============================================================
echo.

REM Change to project directory
cd /d "%~dp0"

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

REM Run full forward sync
echo Starting full forward sync...
echo.
node sync\production\runner-staging.js --mode=full

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================================
    echo  ✓ FULL SYNC COMPLETED SUCCESSFULLY!
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
