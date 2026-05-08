#Requires -Version 5.1
<#
.SYNOPSIS
    One-click launcher - starts the dashboard server and opens it in your default browser.

.DESCRIPTION
    1. Checks whether the server is already responding on port 8765.
    2. If not, starts serve.ps1 as a background job in this session.
    3. Waits until the server returns HTTP 200.
    4. Opens http://localhost:8765/dashboard.html via cmd /c start (bypasses VS Code Simple Browser).

.EXAMPLE
    .\start_dashboard.ps1
#>

$ErrorActionPreference = 'Stop'
$Port    = 8765
$BaseUrl = "http://localhost:$Port"
$DashUrl = "$BaseUrl/dashboard.html"
$Root    = $PSScriptRoot
$JobName = "SI_Dashboard"

function Test-ServerUp {
    try {
        $null = Invoke-WebRequest -Uri $BaseUrl -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        return $true
    } catch { return $false }
}

Write-Host ""
Write-Host "  Suspiciously Intelligent - Dashboard Launcher" -ForegroundColor Cyan
Write-Host "  ----------------------------------------------" -ForegroundColor Cyan
Write-Host ""

# -- Step 1: Check if already running -----------------------------------------

if (Test-ServerUp) {
    Write-Host "  [OK] Server already running on port $Port" -ForegroundColor Green
} else {
    # Clean up any stopped previous job
    Get-Job -Name $JobName -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue

    Write-Host "  [..] Starting server..." -ForegroundColor White

    $null = Start-Job -Name $JobName -ScriptBlock {
        param($p)
        Set-Location $p
        & "$p\serve.ps1" -NoBrowser
    } -ArgumentList $Root

    # -- Step 2: Wait until HTTP 200 -------------------------------------------

    $timeoutSec = 10
    $pollMs     = 300
    $elapsed    = 0

    while ($elapsed -lt ($timeoutSec * 1000)) {
        if (Test-ServerUp) { break }
        Start-Sleep -Milliseconds $pollMs
        $elapsed += $pollMs
    }

    if (-not (Test-ServerUp)) {
        Write-Host ""
        Write-Host "  [ERROR] Server did not respond within $timeoutSec seconds." -ForegroundColor Red
        Write-Host ""
        Write-Host "  Server output:" -ForegroundColor Yellow
        Receive-Job -Name $JobName -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" }
        Write-Host ""
        Write-Host "  Try running .\serve.ps1 directly to see the full error." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    Write-Host "  [OK] Server running at $BaseUrl" -ForegroundColor Green
}

# -- Step 3: Open in default external browser ----------------------------------
# cmd /c start invokes the OS shell URL handler - bypasses VS Code Simple Browser.

Write-Host "  [..] Opening $DashUrl ..." -ForegroundColor White
& cmd /c start "" $DashUrl

Write-Host "  [OK] Dashboard opened." -ForegroundColor Green
Write-Host ""
Write-Host "  Server runs in the background of this terminal session." -ForegroundColor DarkGray
Write-Host "  To stop it: .\stop_dashboard.ps1" -ForegroundColor DarkGray
Write-Host ""
