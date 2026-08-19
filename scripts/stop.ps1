# scripts/stop.ps1
# Stops the Jenkins Remoting cluster

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

Write-Host "Stopping Jenkins Remoting Cluster..." -ForegroundColor Yellow
docker compose down
Write-Host "Jenkins Remoting Cluster stopped." -ForegroundColor Green
