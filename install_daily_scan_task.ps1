#Requires -Version 5.1
<#
.SYNOPSIS
    Registers the SuspiciouslyIntelligentDailyScan scheduled task.

.DESCRIPTION
    Creates a Windows Task Scheduler task that runs run_daily_scan.ps1
    every day at 6:00 AM using the current user's account.

    Strategy: builds a task XML and imports it via schtasks.exe /xml.
    This handles paths that contain spaces without quoting issues, and
    works without administrator rights for the current user's own tasks.

.EXAMPLE
    .\install_daily_scan_task.ps1
    .\install_daily_scan_task.ps1 -Time "07:30"
    .\install_daily_scan_task.ps1 -WhatIf
#>

param(
    [string]$Time   = '06:00',
    [switch]$WhatIf
)

$ErrorActionPreference = 'Continue'

$TASK_NAME  = 'SuspiciouslyIntelligentDailyScan'
$ScriptPath = Join-Path $PSScriptRoot 'run_daily_scan.ps1'
$WorkDir    = $PSScriptRoot

if (-not (Test-Path $ScriptPath)) {
    Write-Host "ERROR: run_daily_scan.ps1 not found at: $ScriptPath" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  Installing scheduled task: $TASK_NAME" -ForegroundColor Cyan
Write-Host "  Script : $ScriptPath"
Write-Host "  Run at : $Time daily"
Write-Host "  User   : $env:USERDOMAIN\$env:USERNAME"
Write-Host ""

if ($WhatIf) {
    Write-Host "  [WhatIf] Would register task -- no changes made." -ForegroundColor Yellow
    exit 0
}

# Parse the hour and minute from the Time parameter
$timeParts = $Time -split ':'
$hour      = $timeParts[0].PadLeft(2,'0')
$minute    = if ($timeParts.Count -gt 1) { $timeParts[1].PadLeft(2,'0') } else { '00' }

# Build a start boundary for tomorrow at the requested time
$tomorrow     = (Get-Date).AddDays(1).ToString('yyyy-MM-dd')
$startBoundary = "${tomorrow}T${hour}:${minute}:00"

# Escape paths for XML (& < > " are the relevant characters; paths rarely
# contain them, but we escape defensively).
function ConvertTo-XmlString {
    param([string]$s)
    $s = $s -replace '&',  '&amp;'
    $s = $s -replace '<',  '&lt;'
    $s = $s -replace '>',  '&gt;'
    $s = $s -replace '"',  '&quot;'
    return $s
}

$xmlScript  = ConvertTo-XmlString $ScriptPath
$xmlWorkDir = ConvertTo-XmlString $WorkDir

# Build the task XML.
# - LogonType InteractiveToken: runs when the user is logged on (no password needed).
# - The Arguments element uses properly XML-encoded double-quotes around the path.
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Daily AI news scan for the Suspiciously Intelligent editorial dashboard.</Description>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>$startBoundary</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <ExecutionTimeLimit>PT4H</ExecutionTimeLimit>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <RestartOnFailure>
      <Interval>PT30M</Interval>
      <Count>1</Count>
    </RestartOnFailure>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File &quot;$xmlScript&quot;</Arguments>
      <WorkingDirectory>$xmlWorkDir</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@

# Write the XML to a temp file as UTF-16 (required by schtasks /xml).
$TempXml = Join-Path $env:TEMP "si_task_$(Get-Random).xml"
$taskXml | Out-File -FilePath $TempXml -Encoding Unicode -Force

try {
    # Remove existing task if present
    $null = & schtasks.exe /query /tn $TASK_NAME 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Removing existing task..." -ForegroundColor Yellow
        & schtasks.exe /delete /tn $TASK_NAME /f | Out-Null
    }

    # Import from XML
    $output = & schtasks.exe /create /xml $TempXml /tn $TASK_NAME /f 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "  Task registered successfully." -ForegroundColor Green
        Write-Host ""
        Write-Host "  Task name  : $TASK_NAME"
        Write-Host "  First run  : $startBoundary"
        Write-Host "  Repeats    : daily at ${hour}:${minute}"
        Write-Host ""
        Write-Host "  To verify : schtasks /query /tn `"$TASK_NAME`" /v /fo LIST"
        Write-Host "  To test   : .\test_daily_scan.ps1"
        Write-Host "  To remove : .\uninstall_daily_scan_task.ps1"
        Write-Host ""
    } else {
        Write-Host "  ERROR: schtasks returned exit code $exitCode" -ForegroundColor Red
        Write-Host "  Output: $output" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Try running this script from an elevated (Administrator) PowerShell." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Task XML saved at: $TempXml" -ForegroundColor Yellow
        Write-Host "  Manual command:" -ForegroundColor Yellow
        Write-Host "    schtasks /create /xml `"$TempXml`" /tn `"$TASK_NAME`" /f" -ForegroundColor Yellow
        exit 1
    }
} finally {
    if (Test-Path $TempXml) {
        Remove-Item $TempXml -ErrorAction SilentlyContinue
    }
}
