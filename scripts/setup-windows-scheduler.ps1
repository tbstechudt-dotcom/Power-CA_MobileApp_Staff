# PowerCA Mobile - Windows Task Scheduler Setup
# Creates scheduled tasks for forward and reverse sync
#
# Run this script as Administrator:
#   powershell -ExecutionPolicy Bypass -File scripts/setup-windows-scheduler.ps1

param(
    [string]$User = $env:USERNAME
)

Write-Host "============================================================"
Write-Host "PowerCA Mobile - Windows Task Scheduler Setup"
Write-Host "============================================================"
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[ERROR] This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Set working directory
$WorkingDir = "D:\PowerCA Mobile"

Write-Host "[INFO] Setting up scheduled tasks for user: $User"
Write-Host "[INFO] Working directory: $WorkingDir"
Write-Host ""

# Task 1: Forward Sync (Full) - Daily at 2:00 AM
Write-Host "[INFO] Creating Task 1: Forward Sync (Full) - Daily at 2:00 AM..."
$action1 = New-ScheduledTaskAction -Execute "$WorkingDir\scripts\schedule-forward-sync-full.bat" -WorkingDirectory $WorkingDir
$trigger1 = New-ScheduledTaskTrigger -Daily -At 2:00AM
$settings1 = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal1 = New-ScheduledTaskPrincipal -UserId $User -LogonType S4U -RunLevel Highest

try {
    Register-ScheduledTask -TaskName "PowerCA_ForwardSync_Full" `
        -Action $action1 `
        -Trigger $trigger1 `
        -Settings $settings1 `
        -Principal $principal1 `
        -Description "PowerCA Mobile - Full forward sync (Desktop -> Supabase) - Runs daily at 2:00 AM" `
        -Force
    Write-Host "[OK] Task 'PowerCA_ForwardSync_Full' created successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create task 'PowerCA_ForwardSync_Full': $_" -ForegroundColor Red
}
Write-Host ""

# Task 2: Forward Sync (Incremental) - Every 4 hours during business hours
Write-Host "[INFO] Creating Task 2: Forward Sync (Incremental) - Every 4 hours..."
$action2 = New-ScheduledTaskAction -Execute "$WorkingDir\scripts\schedule-forward-sync-incremental.bat" -WorkingDirectory $WorkingDir

# Create 4 triggers for 8 AM, 12 PM, 4 PM, 8 PM
$trigger2a = New-ScheduledTaskTrigger -Daily -At 8:00AM
$trigger2b = New-ScheduledTaskTrigger -Daily -At 12:00PM
$trigger2c = New-ScheduledTaskTrigger -Daily -At 4:00PM
$trigger2d = New-ScheduledTaskTrigger -Daily -At 8:00PM
$triggers2 = @($trigger2a, $trigger2b, $trigger2c, $trigger2d)

$settings2 = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal2 = New-ScheduledTaskPrincipal -UserId $User -LogonType S4U -RunLevel Highest

try {
    Register-ScheduledTask -TaskName "PowerCA_ForwardSync_Incremental" `
        -Action $action2 `
        -Trigger $triggers2 `
        -Settings $settings2 `
        -Principal $principal2 `
        -Description "PowerCA Mobile - Incremental forward sync (Desktop -> Supabase) - Runs every 4 hours at 8 AM, 12 PM, 4 PM, 8 PM" `
        -Force
    Write-Host "[OK] Task 'PowerCA_ForwardSync_Incremental' created successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create task 'PowerCA_ForwardSync_Incremental': $_" -ForegroundColor Red
}
Write-Host ""

# Task 3: Reverse Sync - Every hour
Write-Host "[INFO] Creating Task 3: Reverse Sync - Every hour..."
$action3 = New-ScheduledTaskAction -Execute "$WorkingDir\scripts\schedule-reverse-sync.bat" -WorkingDirectory $WorkingDir

# Create trigger for every hour
$trigger3 = New-ScheduledTaskTrigger -Daily -At 12:00AM
$trigger3.Repetition = (New-ScheduledTaskTrigger -Once -At 12:00AM -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 1)).Repetition

$settings3 = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal3 = New-ScheduledTaskPrincipal -UserId $User -LogonType S4U -RunLevel Highest

try {
    Register-ScheduledTask -TaskName "PowerCA_ReverseSync_Hourly" `
        -Action $action3 `
        -Trigger $trigger3 `
        -Settings $settings3 `
        -Principal $principal3 `
        -Description "PowerCA Mobile - Reverse sync (Supabase -> Desktop) - Runs every hour" `
        -Force
    Write-Host "[OK] Task 'PowerCA_ReverseSync_Hourly' created successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create task 'PowerCA_ReverseSync_Hourly': $_" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "============================================================"
Write-Host "[SUCCESS] Scheduled Tasks Setup Complete!"
Write-Host "============================================================"
Write-Host ""
Write-Host "Created Tasks:"
Write-Host "  1. PowerCA_ForwardSync_Full       - Daily at 2:00 AM"
Write-Host "  2. PowerCA_ForwardSync_Incremental - 8 AM, 12 PM, 4 PM, 8 PM"
Write-Host "  3. PowerCA_ReverseSync_Hourly      - Every hour"
Write-Host ""
Write-Host "To view tasks:"
Write-Host "  taskschd.msc"
Write-Host ""
Write-Host "To test a task manually:"
Write-Host "  schtasks /Run /TN 'PowerCA_ReverseSync_Hourly'"
Write-Host ""
Write-Host "To disable a task:"
Write-Host "  schtasks /Change /TN 'PowerCA_ForwardSync_Full' /DISABLE"
Write-Host ""
Write-Host "Logs will be saved to: $WorkingDir\logs\"
Write-Host ""
