# Supabase CLI Installation Script for Windows
# Run this in PowerShell as Administrator

Write-Host "=================================================="  -ForegroundColor Cyan
Write-Host "  Supabase CLI Installation for Windows"  -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Scoop is installed
Write-Host "[1/3] Checking for Scoop..." -ForegroundColor Yellow
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "✓ Scoop is already installed" -ForegroundColor Green
} else {
    Write-Host "✗ Scoop not found. Installing Scoop..." -ForegroundColor Yellow

    # Set execution policy
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

    # Install Scoop
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

    Write-Host "✓ Scoop installed successfully!" -ForegroundColor Green
}

Write-Host ""
Write-Host "[2/3] Adding Supabase bucket to Scoop..." -ForegroundColor Yellow
try {
    scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
    Write-Host "✓ Supabase bucket added" -ForegroundColor Green
} catch {
    Write-Host "⚠ Bucket may already exist (this is okay)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[3/3] Installing Supabase CLI..." -ForegroundColor Yellow
scoop install supabase

Write-Host ""
Write-Host "=================================================="  -ForegroundColor Cyan
Write-Host "  Installation Complete!"  -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Verify installation
Write-Host "Verifying Supabase CLI installation..." -ForegroundColor Yellow
$version = supabase --version
Write-Host "✓ Supabase CLI $version installed successfully!" -ForegroundColor Green

Write-Host ""
Write-Host "Quick Start Commands:" -ForegroundColor Cyan
Write-Host "  supabase login          - Login to your Supabase account"
Write-Host "  supabase link           - Link to your project"
Write-Host "  supabase db pull        - Pull database schema"
Write-Host "  supabase gen types      - Generate TypeScript types"
Write-Host ""
