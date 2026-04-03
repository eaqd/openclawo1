<#
.SYNOPSIS
    OpenClaw Sandbox - One-command Windows launcher.
.EXAMPLE
    .\start.ps1                    # Start everything
    .\start.ps1 -Stop              # Stop all services
    .\start.ps1 -Status            # Show what's running
    .\start.ps1 -Pull deepseek-r1  # Pull a specific model
    .\start.ps1 -Gateway           # Also start the openclaw gateway
    powershell -File start.ps1     # Run from cmd.exe
#>
[CmdletBinding(DefaultParameterSetName = 'Start')]
param(
    [Parameter(ParameterSetName = 'Stop')]  [switch]$Stop,
    [Parameter(ParameterSetName = 'Status')][switch]$Status,
    [Parameter(ParameterSetName = 'Pull')]  [string]$Pull,
    [Parameter(ParameterSetName = 'Start')] [switch]$Gateway
)

$ErrorActionPreference = 'Stop'
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition
$PidDir       = Join-Path $env:TEMP 'openclaw'
$WebPort      = 3000
$OllamaUrl    = 'http://localhost:11434'
$DefaultModel = 'qwen3.5:0.8b'

if (-not (Test-Path $PidDir)) { New-Item -ItemType Directory -Path $PidDir -Force | Out-Null }

# ── Helpers ────────────────────────────────────────────────
function Show-Banner {
    Write-Host ''
    Write-Host '  +====================================================+' -ForegroundColor Cyan
    Write-Host '  |   ' -ForegroundColor Cyan -NoNewline
    Write-Host 'OpenClaw Sandbox' -ForegroundColor Green -NoNewline
    Write-Host '  --  AI on your machine       ' -NoNewline
    Write-Host '|' -ForegroundColor Cyan
    Write-Host '  |       Free . Local . Private                       |' -ForegroundColor Cyan
    Write-Host '  +====================================================+' -ForegroundColor Cyan
    Write-Host ''
}

function Write-Ok   ($msg) { Write-Host '  [OK]  ' -ForegroundColor Green  -NoNewline; Write-Host $msg }
function Write-Warn ($msg) { Write-Host '  [!!]  ' -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Info ($msg) { Write-Host '  [..]  ' -ForegroundColor Blue   -NoNewline; Write-Host $msg }
function Write-Err  ($msg) { Write-Host '  [XX]  ' -ForegroundColor Red    -NoNewline; Write-Host $msg }

function Test-Endpoint ([string]$Url) {
    try { $null = Invoke-RestMethod -Uri $Url -TimeoutSec 3 -ErrorAction Stop; $true }
    catch { $false }
}
function Save-Pid ([string]$Name, [int]$Id) {
    Set-Content -Path (Join-Path $PidDir "$Name.pid") -Value $Id
}
function Stop-NamedService ([string]$Name) {
    $f = Join-Path $PidDir "$Name.pid"
    if (Test-Path $f) {
        $id = Get-Content $f -ErrorAction SilentlyContinue
        if ($id) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
        Remove-Item $f -Force -ErrorAction SilentlyContinue
    }
}

# ── Prerequisites ──────────────────────────────────────────
function Assert-Ollama {
    try {
        $ver = & ollama --version 2>&1
        Write-Ok "Ollama installed  ($ver)"
    } catch {
        Write-Err 'Ollama is not installed or not on PATH.'
        Write-Host '         Download: https://ollama.com/download/windows' -ForegroundColor Yellow
        exit 1
    }
    if (Test-Endpoint "$OllamaUrl/api/tags") {
        Write-Ok 'Ollama server is running.'; return
    }
    Write-Info 'Ollama not responding -- attempting to start...'
    try {
        $proc = Start-Process ollama -ArgumentList 'serve' -PassThru -WindowStyle Hidden
        Save-Pid 'ollama' $proc.Id
        for ($i = 0; $i -lt 15; $i++) {
            Start-Sleep -Seconds 1
            if (Test-Endpoint "$OllamaUrl/api/tags") { Write-Ok 'Ollama server started.'; return }
        }
        Write-Err 'Ollama did not become ready within 15 seconds.'; exit 1
    } catch { Write-Err "Failed to start Ollama: $_"; exit 1 }
}

function Assert-Models {
    try { $resp = Invoke-RestMethod -Uri "$OllamaUrl/api/tags" -TimeoutSec 5 }
    catch { Write-Err 'Cannot reach Ollama API.'; return }

    $models = @($resp.models)
    if ($models.Count -gt 0) {
        Write-Ok "Models installed: $(($models | ForEach-Object { $_.name }) -join ', ')"
        return
    }
    Write-Warn 'No models installed.'
    Write-Host "         Recommended for 8 GB RAM: $DefaultModel" -ForegroundColor Yellow
    $ans = Read-Host "         Pull $DefaultModel now? [Y/n]"
    if ($ans -eq '' -or $ans -match '^[Yy]') { Invoke-PullModel $DefaultModel }
    else { Write-Warn 'Skipped. Run:  .\start.ps1 -Pull <model>' }
}

function Invoke-PullModel ([string]$Model) {
    Write-Info "Pulling $Model (this may take a few minutes)..."
    try {
        & ollama pull $Model
        if ($LASTEXITCODE -eq 0) { Write-Ok "$Model pulled successfully." }
        else { Write-Err "ollama pull exited with code $LASTEXITCODE" }
    } catch { Write-Err "Failed to pull model: $_" }
}

# ── Services ───────────────────────────────────────────────
function Start-WebDashboard {
    $webDir = Join-Path $ScriptDir 'web'
    if (-not (Test-Path (Join-Path $webDir 'index.html'))) {
        Write-Warn 'web/index.html not found -- skipping dashboard.'; return
    }
    if (Test-Endpoint "http://localhost:$WebPort") {
        Write-Ok "Dashboard already serving on :$WebPort"; return
    }
    # Try Python first
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
    if ($py) {
        Write-Info "Starting dashboard via Python on :$WebPort..."
        $proc = Start-Process $py.Source `
            -ArgumentList "-m http.server $WebPort --directory `"$webDir`"" `
            -PassThru -WindowStyle Hidden
        Save-Pid 'webserver' $proc.Id
        Start-Sleep -Seconds 1
        if (Test-Endpoint "http://localhost:$WebPort") {
            Write-Ok "Dashboard ready at http://localhost:$WebPort"; return
        }
    }
    # Fallback: npx serve (Node.js)
    $npx = Get-Command npx -ErrorAction SilentlyContinue
    if ($npx) {
        Write-Info "Starting dashboard via npx serve on :$WebPort..."
        $proc = Start-Process $npx.Source `
            -ArgumentList "serve `"$webDir`" -l $WebPort -s" `
            -PassThru -WindowStyle Hidden
        Save-Pid 'webserver' $proc.Id
        Start-Sleep -Seconds 2
        if (Test-Endpoint "http://localhost:$WebPort") {
            Write-Ok "Dashboard ready at http://localhost:$WebPort"; return
        }
    }
    Write-Err 'Neither Python nor Node.js found -- cannot serve dashboard.'
    Write-Host '         Install Python: https://python.org' -ForegroundColor Yellow
}

function Start-GatewayService {
    if (Test-Endpoint 'http://localhost:18789/health') {
        Write-Ok 'Gateway already running on :18789'; return
    }
    $cmd = Get-Command openclaw -ErrorAction SilentlyContinue
    if (-not $cmd) { Write-Warn 'openclaw CLI not found -- skipping gateway.'; return }
    Write-Info 'Starting OpenClaw gateway on :18789...'
    $proc = Start-Process openclaw `
        -ArgumentList 'gateway run --bind loopback --port 18789' `
        -PassThru -WindowStyle Hidden
    Save-Pid 'gateway' $proc.Id
    Start-Sleep -Seconds 2
    if (Test-Endpoint 'http://localhost:18789/health') { Write-Ok 'Gateway running on :18789' }
    else { Write-Warn 'Gateway may still be starting -- check back shortly.' }
}

# ── Stop / Status ──────────────────────────────────────────
function Stop-AllServices {
    Write-Info 'Stopping OpenClaw services...'
    'webserver', 'gateway', 'ollama' | ForEach-Object { Stop-NamedService $_ }
    Get-Process -Name python*, node -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match "http\.server $WebPort|serve.*$WebPort" } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Ok 'All services stopped.'
}

function Show-Status {
    Write-Host ''
    Write-Host '  -- OpenClaw Status -----------------------------------------' -ForegroundColor Cyan
    foreach ($svc in @(
        @{ Name = 'Ollama';    Url = "$OllamaUrl/api/tags" },
        @{ Name = 'Dashboard'; Url = "http://localhost:$WebPort" },
        @{ Name = 'Gateway';   Url = 'http://localhost:18789/health' }
    )) {
        $up = Test-Endpoint $svc.Url
        Write-Host "    $($svc.Name.PadRight(12))" -NoNewline
        if ($up) { Write-Host 'RUNNING' -ForegroundColor Green -NoNewline; Write-Host "  $($svc.Url)" }
        else     { Write-Host 'STOPPED' -ForegroundColor DarkGray }
    }
    Write-Host ''
    Write-Host '    Dashboard : ' -NoNewline; Write-Host "http://localhost:$WebPort" -ForegroundColor Cyan
    Write-Host '    Stop      : ' -NoNewline; Write-Host '.\start.ps1 -Stop' -ForegroundColor Yellow
    Write-Host '    Status    : ' -NoNewline; Write-Host '.\start.ps1 -Status' -ForegroundColor Yellow
    Write-Host ''
}

# ── Main ───────────────────────────────────────────────────
if ($Stop)   { Show-Banner; Stop-AllServices; exit 0 }
if ($Status) { Show-Banner; Show-Status; exit 0 }
if ($Pull)   { Show-Banner; Assert-Ollama; Invoke-PullModel $Pull; exit 0 }

Show-Banner
$env:OLLAMA_API_KEY = 'ollama-local'
$env:OLLAMA_ORIGINS = '*'
Assert-Ollama
Assert-Models
Start-WebDashboard
if ($Gateway) { Start-GatewayService }

Write-Host ''
Write-Host '  Opening browser...' -ForegroundColor Cyan
Start-Process "http://localhost:$WebPort"
Show-Status
Write-Host '  Press Ctrl+C to stop.' -ForegroundColor Yellow
Write-Host ''

# Keep alive so child processes stay attached
try { while ($true) { Start-Sleep -Seconds 60 } }
finally { Stop-AllServices }
