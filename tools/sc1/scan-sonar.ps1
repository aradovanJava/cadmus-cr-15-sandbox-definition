# CADMUS-CR-15 - SonarQube analysis of cadmus-vulnshop-cr (levels A3/A4)
#
#   powershell -ExecutionPolicy Bypass -File C:\Lab\scan-sonar.ps1 -Token <your-token>
#   ... -WithLinters      also import the bandit and ruff findings as external issues
#
# The token is the Global Analysis Token you generate in SonarQube
# (My Account -> Security). Settings, including the project key, are in
# C:\Lab\sonar-cr15.properties. SonarQube Community Build analyses
# Python with its built-in analyser; results appear at http://localhost:9000.

param(
    [Parameter(Mandatory = $true)][string]$Token,
    [string]$HostUrl = 'http://localhost:9000',
    [switch]$WithLinters
)

# 'Continue': in Windows PowerShell a native tool writing to stderr would
# otherwise abort the script. Exit codes are checked explicitly instead.
$ErrorActionPreference = 'Continue'
$app      = 'C:\Lab\cadmus-vulnshop-cr'
$settings = 'C:\Lab\sonar-cr15.properties'
$scanner  = 'C:\Tools\sonar-scanner\bin\sonar-scanner.bat'
if (-not (Test-Path $scanner)) { throw "SonarScanner not found at $scanner" }
Set-Location $app

$extra = @()
if ($WithLinters) {
    Write-Host "[1/2] bandit + ruff -> lab\out (imported as external issues)" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path 'lab\out' | Out-Null
    & 'C:\Tools\bin\bandit.exe' -r vulnshop -f json -o 'lab\out\bandit-sonar.json' -q 2>$null
    & 'C:\Tools\bin\ruff.exe' check --select S,BLE --no-cache --output-format json -o 'lab\out\ruff-sonar.json' vulnshop 2>$null
    $extra += '-Dsonar.python.bandit.reportPaths=lab/out/bandit-sonar.json'
    $extra += '-Dsonar.python.ruff.reportPaths=lab/out/ruff-sonar.json'
}

Write-Host "[$(if ($WithLinters) {'2/2'} else {'1/1'})] SonarScanner -> $HostUrl (one to two minutes)" -ForegroundColor Cyan
& $scanner "-Dproject.settings=$settings" "-Dsonar.host.url=$HostUrl" "-Dsonar.token=$Token" @extra
if ($LASTEXITCODE -ne 0) { throw "sonar-scanner failed with exit code $LASTEXITCODE" }
Write-Host "`nDone. Open $HostUrl, select the project and read Issues and Security Hotspots." -ForegroundColor Green
