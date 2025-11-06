@echo off
REM ============================================================
REM PowerCA Mobile - Reverse Sync (One-Click)
REM Supabase Cloud → Desktop PostgreSQL
REM ============================================================

echo.
echo ============================================================
echo  PowerCA Mobile - REVERSE SYNC
echo  Supabase Cloud -^> Desktop PostgreSQL
echo ============================================================
echo.
echo  Mode: INCREMENTAL INSERT-ONLY (metadata-based tracking)
echo  Direction: Mobile data back to desktop
echo  Time: ~1-2 minutes (incremental with metadata)
echo.
echo  This syncs mobile-created records back to desktop
echo  database for backup and reporting purposes.
echo.
echo  Note: Run scripts\create-reverse-sync-metadata-table.js
echo        ONCE before first reverse sync for metadata tracking.
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

REM Check if reverse sync engine exists
if not exist "sync\production\reverse-sync-engine.js" (
    echo ERROR: Reverse sync engine not found!
    echo Expected path: sync\production\reverse-sync-engine.js
    pause
    exit /b 1
)

REM Run reverse sync
echo Starting reverse sync...
echo.
node sync\production\reverse-sync-engine.js

REM Check exit code
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================================
    echo  ✓ REVERSE SYNC COMPLETED SUCCESSFULLY!
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
