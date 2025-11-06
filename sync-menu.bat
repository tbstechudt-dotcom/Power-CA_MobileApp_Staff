@echo off
REM ============================================================
REM PowerCA Mobile - Sync Menu (One-Click)
REM Choose sync type interactively
REM ============================================================

:MENU
cls
echo.
echo ============================================================
echo  PowerCA Mobile - SYNC MENU
echo ============================================================
echo.
echo  Choose sync operation:
echo.
echo  [1] Full Forward Sync       (Desktop -^> Supabase, all records)
echo  [2] Incremental Forward Sync (Desktop -^> Supabase, changed only)
echo  [3] Reverse Sync            (Supabase -^> Desktop, mobile data)
echo.
echo  [0] Exit
echo.
echo ============================================================
echo.

set /p choice="Enter your choice (0-3): "

if "%choice%"=="1" goto FULL_SYNC
if "%choice%"=="2" goto INCREMENTAL_SYNC
if "%choice%"=="3" goto REVERSE_SYNC
if "%choice%"=="0" goto EXIT
echo.
echo Invalid choice! Please enter 0, 1, 2, or 3.
timeout /t 2 >nul
goto MENU

:FULL_SYNC
cls
echo.
echo ============================================================
echo  FULL FORWARD SYNC
echo  Desktop PostgreSQL -^> Supabase Cloud
echo ============================================================
echo.
echo  Mode: FULL SYNC (all records)
echo  Safety: STAGING TABLE PATTERN (production data protected)
echo  Time: ~2-3 minutes for all tables
echo.
echo ============================================================
echo.

cd /d "%~dp0"
node sync\production\runner-staging.js --mode=full

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✓ FULL SYNC COMPLETED SUCCESSFULLY!
) else (
    echo.
    echo ✗ SYNC FAILED - Check error messages above
)
echo.
pause
goto MENU

:INCREMENTAL_SYNC
cls
echo.
echo ============================================================
echo  INCREMENTAL FORWARD SYNC
echo  Desktop PostgreSQL -^> Supabase Cloud
echo ============================================================
echo.
echo  Mode: INCREMENTAL SYNC (only changed records)
echo  Safety: STAGING TABLE PATTERN (production data protected)
echo  Time: ~30-60 seconds
echo.
echo  Note: Mobile-only PK tables will auto-force FULL mode
echo.
echo ============================================================
echo.

cd /d "%~dp0"
node sync\production\runner-staging.js --mode=incremental

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✓ INCREMENTAL SYNC COMPLETED SUCCESSFULLY!
) else (
    echo.
    echo ✗ SYNC FAILED - Check error messages above
)
echo.
pause
goto MENU

:REVERSE_SYNC
cls
echo.
echo ============================================================
echo  REVERSE SYNC
echo  Supabase Cloud -^> Desktop PostgreSQL
echo ============================================================
echo.
echo  Mode: INCREMENTAL INSERT-ONLY (new mobile records)
echo  Direction: Mobile data back to desktop
echo  Time: ~5-10 minutes
echo.
echo ============================================================
echo.

cd /d "%~dp0"
node sync\production\reverse-sync-engine.js

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✓ REVERSE SYNC COMPLETED SUCCESSFULLY!
) else (
    echo.
    echo ✗ SYNC FAILED - Check error messages above
)
echo.
pause
goto MENU

:EXIT
echo.
echo Exiting...
exit /b 0
