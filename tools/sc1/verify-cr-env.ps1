# CADMUS-CR-15 - sandbox environment check for SC1 (VM1, Windows workstation)
#
#   powershell -ExecutionPolicy Bypass -File C:\Lab\verify-cr-env.ps1
#
# Sandbox counterpart of tools/verify_env.py in cadmus-vulnshop-cr: it also
# knows that SonarQube runs on SQ1 and OWASP ZAP on OWZ1. If anything reports
# MISSING or DOWN, tell your instructor before starting the lab.
#
# How a tool is judged: OK/MISSING is decided only by whether the command can
# be found (Get-Command). The version shown next to it is informational.

$ok = $true
$staleSession = $false
$app  = 'C:\Lab\cadmus-vulnshop-cr'
$venv = Join-Path $app '.venv\Scripts'

# The PATH this window inherited, and the PATH the machine actually has now.
$inheritedPath = $env:Path
$currentPath   = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                 [Environment]::GetEnvironmentVariable('Path', 'User')

function Find-Command([string]$cmd, [string]$path) {
    $saved = $env:Path
    try { $env:Path = $path; Get-Command $cmd -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1 }
    finally { $env:Path = $saved }
}

function Check-Tool([string]$name, [string]$cmd, [string[]]$argList, [switch]$Optional) {
    Write-Host -NoNewline ("{0,-20}" -f $name)
    $c = Find-Command $cmd $currentPath
    if (-not $c) {
        if ($Optional) { Write-Host "not installed (optional)" -ForegroundColor Yellow }
        else { Write-Host "MISSING" -ForegroundColor Red; $script:ok = $false }
        return
    }
    $version = ''
    try {
        $lines = @(& $c.Source @argList 2>&1 | ForEach-Object { "$_" })
        $version = ($lines | Where-Object { $_.Trim() } | Select-Object -First 1)
    } catch { }
    if (Find-Command $cmd $inheritedPath) {
        Write-Host "OK    $version" -ForegroundColor Green
    } else {
        Write-Host "OK    $version   (not visible in this window yet - see below)" -ForegroundColor Yellow
        $script:staleSession = $true
    }
}

function Check-Url([string]$name, [string]$url, [switch]$Optional) {
    Write-Host -NoNewline ("{0,-20}" -f $name)
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
        $body = "$($r.Content)"
        if ($body.Length -gt 60) { $body = "HTTP $($r.StatusCode)" }
        Write-Host "OK    $body" -ForegroundColor Green
    } catch {
        if ($Optional) { Write-Host "DOWN  (optional) $url" -ForegroundColor Yellow }
        else { Write-Host "DOWN  $url" -ForegroundColor Red; $script:ok = $false }
    }
}

Write-Host "`nCADMUS-CR-15 - sandbox environment check (SC1)`n" -ForegroundColor Cyan

Check-Tool "python"           "python"        @('--version')
Write-Host -NoNewline ("{0,-20}" -f "python3")
$p3 = Find-Command 'python3' $currentPath
if ($p3 -and $p3.Source -notmatch 'WindowsApps') { Write-Host "OK    $($p3.Source)" -ForegroundColor Green }
else { Write-Host "MISSING  (would open the Microsoft Store)" -ForegroundColor Red; $ok = $false }
Check-Tool "git"              "git"           @('--version')
Check-Tool "bash (Git Bash)"  "bash"          @('--version')
Check-Tool "node"             "node"          @('--version')
Check-Tool "npm"              "npm"           @('--version')
Check-Tool "snyk"             "snyk"          @('--version')
Check-Tool "sqlmap"           "sqlmap"        @('--version')
Check-Tool "sonar-scanner"    "sonar-scanner" @('--version')
Check-Tool "bandit"           "bandit"        @('--version')
Check-Tool "ruff"             "ruff"          @('--version')
Check-Tool "pip-audit"        "pip-audit"     @('--version')
Check-Tool "cyclonedx-py"     "cyclonedx-py"  @('--version')
Check-Tool "vs code"          "code"          @('--version')
Check-Tool "java"             "java"          @('-version') -Optional
Check-Tool "mvn"              "mvn"           @('-v') -Optional

Write-Host ""
Write-Host -NoNewline ("{0,-20}" -f "application")
if (Test-Path "$app\app.py") { Write-Host "OK    $app" -ForegroundColor Green }
else { Write-Host "MISSING  git clone https://github.com/aradovanJava/cadmus-vulnshop-python-cr.git $app" -ForegroundColor Red; $ok = $false }

Write-Host -NoNewline ("{0,-20}" -f "virtual env (.venv)")
if (Test-Path "$venv\python.exe") {
    $missing = @('pytest', 'python3') | Where-Object { -not (Test-Path "$venv\$_.exe") }
    $py = & "$venv\python.exe" -c "import sys, flask, yaml; from importlib.metadata import version as v; print('python', sys.version.split()[0], 'flask', v('flask'), 'pyyaml', v('pyyaml'), 'requests', v('requests'))" 2>&1
    if (-not $missing -and $LASTEXITCODE -eq 0) { Write-Host "OK    $py  + pytest" -ForegroundColor Green }
    else { Write-Host "INCOMPLETE  missing: $($missing -join ', ')  $py" -ForegroundColor Red; $ok = $false }
} else { Write-Host "MISSING  $venv" -ForegroundColor Red; $ok = $false }

Write-Host -NoNewline ("{0,-20}" -f "python ext. (vscode)")
$ext = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Directory -Filter 'ms-python.python-*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($ext) { Write-Host "OK    $($ext.Name)" -ForegroundColor Green }
else { Write-Host "not installed for this user - VS Code: Extensions" -ForegroundColor Yellow }

Write-Host -NoNewline ("{0,-20}" -f "postman")
if (Test-Path "$env:LOCALAPPDATA\Postman\Postman.exe") { Write-Host "OK" -ForegroundColor Green }
else { Write-Host "not installed for this user (optional)" -ForegroundColor Yellow }

Write-Host -NoNewline ("{0,-20}" -f "N1 lab (optional)")
if (Test-Path 'C:\Lab\owasp2025-lab\app.py') { Write-Host "OK    C:\Lab\owasp2025-lab" -ForegroundColor Green }
else { Write-Host "not present" -ForegroundColor Yellow }

Write-Host ""
Check-Url "sonarqube (SQ1)" "http://localhost:9000/api/system/status"
Check-Url "zap ui (OWZ1)"   "http://owz1:8080/zap/"
Check-Url "vulnshop"        "http://127.0.0.1:8080/shop" -Optional

Write-Host ""
if ($staleSession) {
    Write-Host "Some tools are installed but this window does not see them yet. Run" -ForegroundColor Yellow
    Write-Host "  powershell -ExecutionPolicy Bypass -File C:\Lab\fix-path.ps1" -ForegroundColor Yellow
    Write-Host "or sign out of Windows and back in.`n" -ForegroundColor Yellow
}
if ($ok) { Write-Host "Sandbox ready." -ForegroundColor Green }
else     { Write-Host "Something is missing or down - raise it now." -ForegroundColor Red }
Write-Host "vulnshop is DOWN until you start it (bash tools/run_app.sh) - that is expected.`n"
