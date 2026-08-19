# scripts/init-secrets.ps1
param(
    [string]$SecretsDir = "$PSScriptRoot/../secrets",
    [string]$EnvFile = "$PSScriptRoot/../.env"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -Path $SecretsDir)) {
    Write-Host "Creating secrets directory at $SecretsDir..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $SecretsDir -Force | Out-Null
}

$PrivateKeyPath = Join-Path $SecretsDir "id_ed25519"
$PublicKeyPath = Join-Path $SecretsDir "id_ed25519.pub"

if (-not (Test-Path -Path $PrivateKeyPath)) {
    Write-Host "Generating new ED25519 SSH key pair for Jenkins Remoting..." -ForegroundColor Yellow
    ssh-keygen -t ed25519 -f $PrivateKeyPath -N '""' -C "jenkins-remoting-key"
    Write-Host "SSH Key pair generated at $SecretsDir" -ForegroundColor Green
} else {
    Write-Host "SSH Key pair already exists at $SecretsDir" -ForegroundColor Green
}

# Update .env with the public key
$pubKey = (Get-Content -Path $PublicKeyPath -Raw).Trim()
$envContent = @"
# Jenkins Admin Credentials
JENKINS_ADMIN_ID=admin
JENKINS_ADMIN_PASSWORD=admin123
JENKINS_URL=http://localhost:8080/
JENKINS_AGENT_SSH_PUBKEY=$pubKey
"@

[System.IO.File]::WriteAllText($EnvFile, $envContent, [System.Text.Encoding]::UTF8)
Write-Host "Updated $EnvFile with public key." -ForegroundColor Green
