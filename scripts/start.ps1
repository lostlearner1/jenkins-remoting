# scripts/start.ps1
# Starts the Jenkins Remoting infrastructure

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Starting Jenkins Remoting Infrastructure Setup...       " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Initialize Secrets
Write-Host "`n[1/3] Initializing SSH Credentials..." -ForegroundColor Yellow
& "$PSScriptRoot/init-secrets.ps1"

# 2. Build and Start Containers
Write-Host "`n[2/3] Building & Starting Docker Containers..." -ForegroundColor Yellow
Set-Location $RootDir
docker compose up -d --build

# 3. Wait for Controller Health
Write-Host "`n[3/3] Waiting for Jenkins Controller to initialize..." -ForegroundColor Yellow
$JenkinsUrl = "http://localhost:8080"
$MaxAttempts = 30
$Attempt = 0
$Ready = $false

while ($Attempt -lt $MaxAttempts) {
    $Attempt++
    try {
        $Response = Invoke-WebRequest -Uri "$JenkinsUrl/login" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($Response.StatusCode -eq 200) {
            $Ready = $true
            break
        }
    } catch {
        # Keep waiting
    }
    Write-Host "Waiting for Jenkins Web UI... (attempt $Attempt/$MaxAttempts)" -ForegroundColor Gray
    Start-Sleep -Seconds 4
}

if ($Ready) {
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host " Jenkins Remoting Cluster is UP and RUNNING! " -ForegroundColor Green
    Write-Host " URL:      $JenkinsUrl" -ForegroundColor Green
    Write-Host " User:     admin" -ForegroundColor Green
    Write-Host " Password: admin123" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "Run .\scripts\test-remoting.ps1 to verify node connections." -ForegroundColor Cyan
} else {
    Write-Host "`n[WARNING] Jenkins took longer than expected to start." -ForegroundColor Yellow
    Write-Host "Check container logs with: docker compose logs -f" -ForegroundColor Yellow
}
