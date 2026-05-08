#Requires -Version 5.1
<#
.SYNOPSIS
    Stops the Suspiciously Intelligent dashboard server.
    Stops the background job if found, then kills any process still on port 8765.
#>

$ErrorActionPreference = 'Stop'
$Port    = 8765
$JobName = "SI_Dashboard"

Write-Host ""
Write-Host "  Stopping dashboard server..." -ForegroundColor Cyan
Write-Host ""

$stopped = $false

# -- Stop background job if present -------------------------------------------

$job = Get-Job -Name $JobName -ErrorAction SilentlyContinue
if ($job) {
    Write-Host "  [..] Stopping background job '$JobName' (state: $($job.State))..." -ForegroundColor White
    Stop-Job  -Name $JobName -ErrorAction SilentlyContinue
    Remove-Job -Name $JobName -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] Job stopped." -ForegroundColor Green
    $stopped = $true
}

# -- Kill any process still holding the port ----------------------------------

$connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($connections) {
    foreach ($procId in ($connections.OwningProcess | Sort-Object -Unique)) {
        try {
            $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
            if ($proc) {
                Write-Host "  [..] Killing PID $procId ($($proc.ProcessName)) on port $Port..." -ForegroundColor White
                Stop-Process -Id $procId -Force
                Write-Host "  [OK] PID $procId stopped." -ForegroundColor Green
                $stopped = $true
            }
        } catch {
            Write-Host "  [!!] Could not stop PID $procId - $_" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
if ($stopped) {
    Write-Host "  Server stopped." -ForegroundColor Green
} else {
    Write-Host "  Nothing was running." -ForegroundColor Yellow
}
Write-Host ""
