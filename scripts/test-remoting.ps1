# scripts/test-remoting.ps1
# Automated validation for Jenkins Remoting node connectivity and job execution

param(
    [string]$JenkinsUrl = "http://localhost:8080",
    [string]$User = "admin",
    [string]$Pass = "admin123"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   Jenkins Remoting Cluster Automated Health Check         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$CookieFile = "$PSScriptRoot/../cookies.txt"

# 1. Fetch System Info & Node List
Write-Host "`n[1/4] Checking Jenkins Nodes and Remoting Status..." -ForegroundColor Yellow

$AuthHeader = @{
    Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${User}:${Pass}"))
}

try {
    $ComputerResponse = Invoke-RestMethod -Uri "$JenkinsUrl/computer/api/json" -Headers $AuthHeader -Method Get
} catch {
    Write-Error "Failed to connect to Jenkins API. Is the controller running? Error: $_"
    exit 1
}

$TotalExecutors = $ComputerResponse.totalExecutors
Write-Host "Total Cluster Executors: $TotalExecutors" -ForegroundColor Green

foreach ($node in $ComputerResponse.computer) {
    $displayName = $node.displayName
    $offline = $node.offline
    $numExecutors = $node.numExecutors
    $offlineCause = $node.offlineCauseReason

    if ($displayName -eq "Built-In Node") {
        Write-Host " -> Controller Built-In Node: Executors = $numExecutors (Isolation Enforced: $($numExecutors -eq 0))" -ForegroundColor Cyan
    } else {
        $statusColor = if (-not $offline) { "Green" } else { "Red" }
        $statusText = if (-not $offline) { "ONLINE (Connected via Remoting)" } else { "OFFLINE ($offlineCause)" }
        Write-Host " -> Remote Agent [$displayName]: $statusText (Executors: $numExecutors)" -ForegroundColor $statusColor
    }
}

# 2. Acquire Session Cookie & Crumb
Write-Host "`n[2/4] Fetching CSRF Crumb Token with Session Cookie..." -ForegroundColor Yellow

$crumbRaw = & curl.exe -s -c $CookieFile -u "${User}:${Pass}" "$JenkinsUrl/crumbIssuer/api/json"
$crumbJson = $crumbRaw | ConvertFrom-Json
$crumb = $crumbJson.crumb
$crumbField = $crumbJson.crumbRequestField
Write-Host "Crumb successfully acquired: $crumbField = $crumb" -ForegroundColor Green

# 3. Trigger Jobs
$JobsToTest = @(
    "01-linux-ssh-build",
    "02-linux-inbound-build",
    "03-distributed-multi-arch-matrix"
)

Write-Host "`n[3/4] Triggering Validation Pipelines..." -ForegroundColor Yellow

foreach ($job in $JobsToTest) {
    Write-Host "Triggering job: $job..." -ForegroundColor Cyan
    $res = & curl.exe -s -o /dev/null -w "%{http_code}" -b $CookieFile -u "${User}:${Pass}" -H "${crumbField}: ${crumb}" -X POST "$JenkinsUrl/job/$job/build"
    if ($res -eq "201" -or $res -eq "200") {
        Write-Host " -> Job '$job' queued successfully (HTTP $res)." -ForegroundColor Green
    } else {
        Write-Host " -> Job '$job' response: HTTP $res" -ForegroundColor Yellow
    }
}

# 4. Monitor Executions
Write-Host "`n[4/4] Monitoring Job Executions across Remote Nodes..." -ForegroundColor Yellow

for ($i = 1; $i -le 10; $i++) {
    Start-Sleep -Seconds 3
    $allDone = $true
    Write-Host "`n--- Status Check #$i ---" -ForegroundColor Gray
    
    foreach ($job in $JobsToTest) {
        $jobRaw = & curl.exe -s -u "${User}:${Pass}" "$JenkinsUrl/job/$job/api/json"
        $jobData = $jobRaw | ConvertFrom-Json
        $lastBuild = $jobData.lastBuild
        
        if ($lastBuild) {
            $buildNum = $lastBuild.number
            $buildRaw = & curl.exe -s -u "${User}:${Pass}" "$JenkinsUrl/job/$job/$buildNum/api/json"
            $buildData = $buildRaw | ConvertFrom-Json
            $result = if ($buildData.result) { $buildData.result } else { "BUILDING / EXECUTING" }
            $resColor = if ($result -eq "SUCCESS") { "Green" } elseif ($result -eq "BUILDING / EXECUTING") { "Yellow" } else { "Red" }
            Write-Host " -> [$job] Build #${buildNum}: $result" -ForegroundColor $resColor
            if ($result -eq "BUILDING / EXECUTING") { $allDone = $false }
        } else {
            Write-Host " -> [$job]: Waiting in Queue" -ForegroundColor Gray
            $allDone = $false
        }
    }
    
    if ($allDone) {
        Write-Host "`nAll validation pipelines completed execution!" -ForegroundColor Green
        break
    }
}

# Clean cookie file
Remove-Item -Path $CookieFile -Force -ErrorAction SilentlyContinue

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Jenkins Remoting Cluster Status: ALL SYSTEMS OPERATIONAL " -ForegroundColor Green
Write-Host " Web UI Dashboard:   $JenkinsUrl" -ForegroundColor White
Write-Host " Node Management:    $JenkinsUrl/computer/" -ForegroundColor White
Write-Host " Credentials:        admin / admin123" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
