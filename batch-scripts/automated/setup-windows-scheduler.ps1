# PowerCA Mobile - Windows Task Scheduler Setup
# Creates scheduled tasks for forward and reverse sync
#
# Custom Schedule (Office Hours):
#   - Forward Full: Daily at 10:00 AM
#   - Forward Incremental: 2x daily at 12:00 PM and 5:00 PM
#   - Reverse Sync: Daily at 5:30 PM
#
# Run this script as Administrator:
#   powershell -ExecutionPolicy Bypass -File batch-scripts/automated/setup-windows-scheduler.ps1

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
Write-Host "Custom Schedule (Office Hours):"
Write-Host "  - Forward Full Sync: Daily at 10:00 AM"
Write-Host "  - Forward Incremental Sync: 12:00 PM and 5:00 PM"
Write-Host "  - Reverse Sync: Daily at 5:30 PM"
Write-Host ""

# Task 1: Forward Sync (Full) - Daily at 10:00 AM
Write-Host "[INFO] Creating Task 1: Forward Sync (Full) - Daily at 10:00 AM..."
$action1 = New-ScheduledTaskAction -Execute "$WorkingDir\batch-scripts\automated\forward-sync-full.bat" -WorkingDirectory $WorkingDir
$trigger1 = New-ScheduledTaskTrigger -Daily -At 10:00AM
$settings1 = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal1 = New-ScheduledTaskPrincipal -UserId $User -LogonType S4U -RunLevel Highest

try {
    Register-ScheduledTask -TaskName "PowerCA_ForwardSync_Full" `
        -Action $action1 `
        -Trigger $trigger1 `
        -Settings $settings1 `
        -Principal $principal1 `
        -Description "PowerCA Mobile - Full forward sync (Desktop -> Supabase) - Runs daily at 10:00 AM" `
        -Force
    Write-Host "[OK] Task 'PowerCA_ForwardSync_Full' created successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create task 'PowerCA_ForwardSync_Full': $_" -ForegroundColor Red
}
Write-Host ""

# Task 2: Forward Sync (Incremental) - 12:00 PM and 5:00 PM
Write-Host "[INFO] Creating Task 2: Forward Sync (Incremental) - 12:00 PM and 5:00 PM..."
$action2 = New-ScheduledTaskAction -Execute "$WorkingDir\batch-scripts\automated\forward-sync-incremental.bat" -WorkingDirectory $WorkingDir

# Create 2 triggers for 12:00 PM and 5:00 PM
$trigger2a = New-ScheduledTaskTrigger -Daily -At 12:00PM
$trigger2b = New-ScheduledTaskTrigger -Daily -At 5:00PM
$triggers2 = @($trigger2a, $trigger2b)

$settings2 = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal2 = New-ScheduledTaskPrincipal -UserId $User -LogonType S4U -RunLevel Highest

try {
    Register-ScheduledTask -TaskName "PowerCA_ForwardSync_Incremental" `
        -Action $action2 `
        -Trigger $triggers2 `
        -Settings $settings2 `
        -Principal $principal2 `
        -Description "PowerCA Mobile - Incremental forward sync (Desktop -> Supabase) - Runs at 12:00 PM and 5:00 PM" `
        -Force
    Write-Host "[OK] Task 'PowerCA_ForwardSync_Incremental' created successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create task 'PowerCA_ForwardSync_Incremental': $_" -ForegroundColor Red
}
Write-Host ""

# Task 3: Reverse Sync - Daily at 5:30 PM
Write-Host "[INFO] Creating Task 3: Reverse Sync - Daily at 5:30 PM..."
$action3 = New-ScheduledTaskAction -Execute "$WorkingDir\batch-scripts\automated\reverse-sync.bat" -WorkingDirectory $WorkingDir
$trigger3 = New-ScheduledTaskTrigger -Daily -At 5:30PM
$settings3 = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal3 = New-ScheduledTaskPrincipal -UserId $User -LogonType S4U -RunLevel Highest

try {
    Register-ScheduledTask -TaskName "PowerCA_ReverseSync_Daily" `
        -Action $action3 `
        -Trigger $trigger3 `
        -Settings $settings3 `
        -Principal $principal3 `
        -Description "PowerCA Mobile - Reverse sync (Supabase -> Desktop) - Runs daily at 5:30 PM" `
        -Force
    Write-Host "[OK] Task 'PowerCA_ReverseSync_Daily' created successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create task 'PowerCA_ReverseSync_Daily': $_" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "============================================================"
Write-Host "[SUCCESS] Scheduled Tasks Setup Complete!"
Write-Host "============================================================"
Write-Host ""
Write-Host "Created Tasks:"
Write-Host "  1. PowerCA_ForwardSync_Full       - Daily at 10:00 AM"
Write-Host "  2. PowerCA_ForwardSync_Incremental - 12:00 PM and 5:00 PM"
Write-Host "  3. PowerCA_ReverseSync_Daily       - Daily at 5:30 PM"
Write-Host ""
Write-Host "To view tasks:"
Write-Host "  taskschd.msc"
Write-Host ""
Write-Host "To test a task manually:"
Write-Host "  schtasks /Run /TN 'PowerCA_ReverseSync_Daily'"
Write-Host ""
Write-Host "To disable a task:"
Write-Host "  schtasks /Change /TN 'PowerCA_ForwardSync_Full' /DISABLE"
Write-Host ""
Write-Host "Logs will be saved to: $WorkingDir\logs\"
Write-Host ""
Write-Host "IMPORTANT: System must be ON and running for tasks to execute:"
Write-Host "  - 10:00 AM - Forward Full Sync"
Write-Host "  - 12:00 PM - Forward Incremental Sync"
Write-Host "  - 5:00 PM  - Forward Incremental Sync"
Write-Host "  - 5:30 PM  - Reverse Sync"
Write-Host ""
