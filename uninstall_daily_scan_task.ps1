#Requires -Version 5.1
<#
.SYNOPSIS
    Removes the SuspiciouslyIntelligentDailyScan scheduled task.

.EXAMPLE
    .\uninstall_daily_scan_task.ps1
#>

$ErrorActionPreference = 'Continue'
$TASK_NAME = 'SuspiciouslyIntelligentDailyScan'

Write-Host ""
Write-Host "  Removing scheduled task: $TASK_NAME" -ForegroundColor Cyan
Write-Host ""

$task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue

if ($null -eq $task) {
    Write-Host "  Task '$TASK_NAME' not found -- nothing to remove." -ForegroundColor Yellow
} else {
    try {
        Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false
        Write-Host "  Task removed successfully." -ForegroundColor Green
    } catch {
        Write-Host "  ERROR removing task: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
