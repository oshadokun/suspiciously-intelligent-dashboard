#Requires -Version 5.1
<#
.SYNOPSIS
    Starts a local HTTP server for the Suspiciously Intelligent dashboard.

.DESCRIPTION
    Serves the project directory over http://localhost so that dashboard.html
    can fetch /scans/latest/ JSON files automatically.

    Why this is needed:
    Browsers block fetch() calls to other local files when a page is opened
    via file://. Opening dashboard.html through this server (http://localhost)
    removes that restriction while keeping everything fully offline.

.PARAMETER Port
    TCP port to listen on. Default: 8765.

.PARAMETER NoBrowser
    Start the server without opening the browser automatically.

.EXAMPLE
    .\serve.ps1                       # serve and open browser
    .\serve.ps1 -Port 9000            # custom port
    .\serve.ps1 -NoBrowser            # serve only, no browser launch
#>

param(
    [int]$Port      = 8765,
    [switch]$NoBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

$MimeTypes = @{
    '.html' = 'text/html; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.md'   = 'text/plain; charset=utf-8'
    '.txt'  = 'text/plain; charset=utf-8'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.ico'  = 'image/x-icon'
    '.svg'  = 'image/svg+xml'
}

function Get-MimeType([string]$Path) {
    $ext = [IO.Path]::GetExtension($Path).ToLower()
    if ($MimeTypes.ContainsKey($ext)) { return $MimeTypes[$ext] }
    return 'application/octet-stream'
}

# -- Port availability check ---------------------------------------------------

try {
    $test = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    $test.Start(); $test.Stop()
} catch {
    Write-Host ""
    Write-Host "  ERROR: Port $Port is already in use." -ForegroundColor Red
    Write-Host "  Try:  .\serve.ps1 -Port 9000" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# -- Start listener ------------------------------------------------------------

$BaseUrl  = "http://localhost:$Port/"
$DashUrl  = "${BaseUrl}dashboard.html"
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($BaseUrl)

try {
    $listener.Start()
} catch [System.Net.HttpListenerException] {
    Write-Host ""
    Write-Host "  ERROR: Could not bind to port $Port." -ForegroundColor Red
    if ($_.Exception.ErrorCode -eq 5) {
        Write-Host "  Access denied. Try running as Administrator, or use a port > 1024." -ForegroundColor Yellow
    } else {
        Write-Host "  $_" -ForegroundColor Yellow
    }
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "  Suspiciously Intelligent - local server" -ForegroundColor Cyan
Write-Host "  ------------------------------------------------------" -ForegroundColor Cyan
Write-Host "  Root    : $Root" -ForegroundColor White
Write-Host "  URL     : $DashUrl" -ForegroundColor Green
Write-Host "  Ctrl+C  : stop server" -ForegroundColor Gray
Write-Host ""

if (-not $NoBrowser) {
    Start-Process "explorer.exe" $DashUrl
    Write-Host "  Browser opened at $DashUrl" -ForegroundColor DarkGreen
    Write-Host ""
}

$reqCount = 0

function Serve-Request($ctx) {
    $req      = $ctx.Request
    $resp     = $ctx.Response
    $urlPath  = $req.Url.LocalPath.TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($urlPath)) { $urlPath = 'dashboard.html' }

    # Block path traversal
    $resolved = [IO.Path]::GetFullPath((Join-Path $Root $urlPath))
    if (-not $resolved.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        $resp.StatusCode = 403
        try { $resp.Close() } catch {}
        Write-Host "  403  /$urlPath  (blocked)" -ForegroundColor Red
        return
    }

    if (Test-Path $resolved -PathType Leaf) {
        try {
            $bytes = [IO.File]::ReadAllBytes($resolved)
            $resp.ContentType     = Get-MimeType $resolved
            $resp.ContentLength64 = $bytes.Length
            $resp.StatusCode      = 200
            $resp.OutputStream.Write($bytes, 0, $bytes.Length)
            $script:reqCount++
            Write-Host "  200  /$urlPath" -ForegroundColor DarkGray
        } catch {
            $resp.StatusCode = 500
            Write-Host "  500  /$urlPath  ($_)" -ForegroundColor Red
        }
    } else {
        $resp.StatusCode = 404
        Write-Host "  404  /$urlPath" -ForegroundColor Yellow
    }

    try { $resp.OutputStream.Close() } catch {}
    try { $resp.Close() } catch {}
}

# Register a SIGTERM/Ctrl+C cleanup so the port is released cleanly
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { $listener.Stop() }

try {
    while ($listener.IsListening) {
        # GetContext() blocks until a request arrives or the listener is stopped
        $ctx = $listener.GetContext()
        Serve-Request $ctx
    }
} catch [System.Net.HttpListenerException] {
    # Thrown when listener.Stop() is called - normal shutdown path
} catch {
    Write-Host "  Server error: $_" -ForegroundColor Red
} finally {
    try { $listener.Stop() } catch {}
    Write-Host ""
    Write-Host "  Server stopped. $reqCount request(s) served." -ForegroundColor Gray
    Write-Host ""
}
