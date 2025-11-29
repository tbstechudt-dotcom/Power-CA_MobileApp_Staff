@echo off
REM PowerCA Mobile - Deployment Package Creator
REM This script creates a ready-to-deploy package for client installation

echo.
echo ========================================================
echo   PowerCA Mobile - Deployment Package Creator
echo ========================================================
echo.

REM Set variables
set SOURCE_DIR=d:\PowerCA Mobile
set DEPLOY_DIR=%SOURCE_DIR%\PowerCA-Sync-Installer
set OUTPUT_ZIP=%SOURCE_DIR%\PowerCA-Sync-Installer.zip

REM Step 1: Clean up old package
echo [1/7] Cleaning up old deployment package...
if exist "%DEPLOY_DIR%" (
    rmdir /S /Q "%DEPLOY_DIR%"
)
if exist "%OUTPUT_ZIP%" (
    del /Q "%OUTPUT_ZIP%"
)
echo [OK] Cleanup complete
echo.

REM Step 2: Create deployment directory
echo [2/7] Creating deployment directory...
mkdir "%DEPLOY_DIR%"
echo [OK] Directory created: %DEPLOY_DIR%
echo.

REM Step 3: Copy sync engine files
echo [3/7] Copying sync engine files...
xcopy /E /I /Y "%SOURCE_DIR%\sync" "%DEPLOY_DIR%\sync"
echo [OK] Sync engine copied
echo.

REM Step 4: Copy node_modules
echo [4/7] Copying node_modules (this may take a while)...
xcopy /E /I /Y "%SOURCE_DIR%\node_modules" "%DEPLOY_DIR%\node_modules"
echo [OK] Dependencies copied
echo.

REM Step 5: Copy package files
echo [5/7] Copying package configuration...
copy /Y "%SOURCE_DIR%\package.json" "%DEPLOY_DIR%\"
copy /Y "%SOURCE_DIR%\package-lock.json" "%DEPLOY_DIR%\"
echo [OK] Package files copied
echo.

REM Step 6: Create .env template
echo [6/7] Creating .env template...
(
echo # ============================================
echo # PowerCA Sync Service Configuration
echo # ============================================
echo.
echo # CLIENT'S DESKTOP DATABASE ^(Fill this in^)
echo # -----------------------------------------
echo DESKTOP_DB_HOST=localhost
echo DESKTOP_DB_PORT=5433
echo DESKTOP_DB_NAME=enterprise_db
echo DESKTOP_DB_USER=postgres
echo DESKTOP_DB_PASSWORD=___FILL_THIS_IN___
echo.
echo # SUPABASE CLOUD ^(Pre-configured by PowerCA^)
echo # -------------------------------------------
echo SUPABASE_DB_HOST=db.jacqfogzgzvbjeizljqf.supabase.co
echo SUPABASE_DB_PORT=5432
echo SUPABASE_DB_NAME=postgres
echo SUPABASE_DB_USER=postgres
echo SUPABASE_DB_PASSWORD=Powerca@2025
echo.
echo # DO NOT MODIFY BELOW
echo SUPABASE_URL=https://jacqfogzgzvbjeizljqf.supabase.co
echo SUPABASE_ANON_KEY=your_anon_key_here
) > "%DEPLOY_DIR%\.env"
echo [OK] .env template created
echo.

REM Step 7: Create INSTALL.txt
echo [7/7] Creating installation instructions...
(
echo +===============================================================+
echo ^|      PowerCA Mobile - Sync Service Installation              ^|
echo +===============================================================+
echo.
echo IMPORTANT: Read all steps before proceeding.
echo.
echo ---------------------------------------------------------------
echo STEP 1: Install Node.js ^(If not already installed^)
echo ---------------------------------------------------------------
echo.
echo 1. Download Node.js 18 LTS from: https://nodejs.org/
echo    Direct link: https://nodejs.org/dist/v18.20.0/node-v18.20.0-x64.msi
echo.
echo 2. Run installer with default settings
echo.
echo 3. Verify installation:
echo    - Open Command Prompt
echo    - Run: node --version
echo    - Should show: v18.x.x
echo.
echo ---------------------------------------------------------------
echo STEP 2: Copy Files to Installation Directory
echo ---------------------------------------------------------------
echo.
echo 1. Copy this entire folder to: C:\PowerCA-Sync\
echo.
echo 2. Verify folder structure:
echo    C:\PowerCA-Sync\
echo    +- sync\
echo    +- node_modules\
echo    +- .env
echo    +- package.json
echo.
echo ---------------------------------------------------------------
echo STEP 3: Configure Database Connection
echo ---------------------------------------------------------------
echo.
echo 1. Open: C:\PowerCA-Sync\.env
echo.
echo 2. Fill in your PostgreSQL password:
echo    DESKTOP_DB_PASSWORD=your_postgres_password
echo.
echo 3. Verify Desktop DB connection settings
echo.
echo 4. Save and close
echo.
echo ---------------------------------------------------------------
echo STEP 4: Test Sync ^(Before Installing Service^)
echo ---------------------------------------------------------------
echo.
echo 1. Open Command Prompt
echo.
echo 2. Navigate to installation:
echo    cd C:\PowerCA-Sync
echo.
echo 3. Run test sync:
echo    node sync\full-sync.js --mode=incremental
echo.
echo 4. Should see:
echo    [OK] Connected to Desktop PostgreSQL
echo    [OK] Connected to Supabase Cloud
echo    [OK] Syncing tables...
echo.
echo 5. If errors, check:
echo    - Desktop PostgreSQL is running
echo    - Password in .env is correct
echo    - Internet connection is working
echo.
echo ---------------------------------------------------------------
echo STEP 5: Install Windows Service
echo ---------------------------------------------------------------
echo.
echo 1. Open Command Prompt AS ADMINISTRATOR
echo.
echo 2. Navigate to scheduler:
echo    cd C:\PowerCA-Sync\sync\scheduler
echo.
echo 3. Run installer:
echo    install-service.bat
echo.
echo 4. Select option 1 ^(Install service^)
echo.
echo 5. Configure auto-start:
echo    sc config "PowerCA Sync Scheduler" start=auto
echo.
echo 6. Start service ^(option 3 in install-service.bat^)
echo.
echo ---------------------------------------------------------------
echo STEP 6: Verify Service is Running
echo ---------------------------------------------------------------
echo.
echo 1. Open Services: services.msc
echo.
echo 2. Find "PowerCA Sync Scheduler"
echo.
echo 3. Verify:
echo    - Status: Running
echo    - Startup Type: Automatic
echo.
echo 4. Check logs:
echo    C:\PowerCA-Sync\sync\scheduler\logs\combined.log
echo.
echo ---------------------------------------------------------------
echo SYNC SCHEDULE
echo ---------------------------------------------------------------
echo.
echo The service will automatically sync:
echo - DAILY: Incremental sync at 2:00 AM
echo - WEEKLY: Full sync on Sunday at 3:00 AM
echo.
echo No manual intervention required!
echo.
echo ---------------------------------------------------------------
echo SUPPORT
echo ---------------------------------------------------------------
echo.
echo Contact: support@powerca.com
echo Website: https://powerca.com/support
echo.
echo ---------------------------------------------------------------
) > "%DEPLOY_DIR%\INSTALL.txt"
echo [OK] Installation instructions created
echo.

REM Success message
echo ========================================================
echo   [SUCCESS] Deployment package created!
echo ========================================================
echo.
echo Package location: %DEPLOY_DIR%
echo.
echo Next steps:
echo   1. Edit sync\scheduler\clients-config.js (set client's org_id)
echo   2. Review .env template
echo   3. Zip the package: PowerCA-Sync-Installer.zip
echo   4. Send to client for installation
echo.
echo To create ZIP file, run:
echo   powershell Compress-Archive -Path "%DEPLOY_DIR%" -DestinationPath "%OUTPUT_ZIP%"
echo.
pause
