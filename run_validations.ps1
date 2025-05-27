#!/usr/bin/env pwsh

Write-Host "LANton Game Validation Script" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

# Track if all rounds pass
$allRoundsPassed = $true

# Level 1 Validation
Write-Host "🚦 Validation Round 1 - Port Census" -ForegroundColor Yellow
$result = pwsh -f scripts/port_scan.ps1 | Select-String -Pattern "lan-ui"
Write-Host $result
if ($result -match "lan-ui.*Free") {
    Write-Host "✅ Round 1 Passed!" -ForegroundColor Green
} else {
    Write-Host "❌ Round 1 Failed!" -ForegroundColor Red
    $allRoundsPassed = $false
}
Write-Host ""

# Level 2 Validation
Write-Host "🚦 Validation Round 2 - Central Config Service" -ForegroundColor Yellow
# Check if LanHub is running
$isLanHubRunning = $false
try {
    $null = Invoke-RestMethod -Uri "http://localhost:7071/ports" -Method Get -TimeoutSec 2
    $isLanHubRunning = $true
    Write-Host "LanHub is already running"
} catch {
    Write-Host "Starting LanHub..."
    $process = Start-Process -FilePath "dotnet" -ArgumentList "run", "--project", "LanHub" -PassThru -NoNewWindow
      # Wait for LanHub to start
    Start-Sleep -Seconds 10
}

try {
    $result = Invoke-RestMethod -Uri "http://localhost:7071/ports" -Method Get    $resultJson = $result | ConvertTo-Json
    Write-Host $resultJson
    
    # Check if the manifest keys are present - response structure might vary
    if (($result | ConvertTo-Json) -match "lan-ui" -and 
        ($result | ConvertTo-Json) -match "bitnet" -and 
        ($result | ConvertTo-Json) -match "omniparser" -and 
        ($result | ConvertTo-Json) -match "flask-gui") {
        Write-Host "✅ Round 2 Passed!" -ForegroundColor Green
    } else {
        Write-Host "❌ Round 2 Failed! Missing expected keys in the response." -ForegroundColor Red
        $allRoundsPassed = $false
    }
} catch {
    Write-Host "❌ Round 2 Failed! Could not connect to LanHub." -ForegroundColor Red
    $allRoundsPassed = $false
}
Write-Host ""

# Level 3 Validation
Write-Host "🚦 Validation Round 3 - P-Link Wrappers" -ForegroundColor Yellow
Write-Host "Starting BitNet wrapper..."
$process = Start-Process -FilePath "pwsh" -ArgumentList "-File", "wrappers\start_bitnet.ps1" -PassThru -NoNewWindow

# Give it a moment to start
Start-Sleep -Seconds 3

try {
    $response = Invoke-RestMethod -Uri "http://localhost:7071/ports" -Method Get
    $responseJson = $response | ConvertTo-Json
    Write-Host $responseJson
    
    if ($responseJson -match "bitnet" -and $responseJson -match "pid") {
        Write-Host "✅ Round 3 Passed!" -ForegroundColor Green
    } else {
        Write-Host "❌ Round 3 Failed! BitNet wrapper not reporting correctly." -ForegroundColor Red
        $allRoundsPassed = $false
    }
} catch {
    Write-Host "❌ Round 3 Failed! Could not get port information." -ForegroundColor Red
    $allRoundsPassed = $false
}
Write-Host ""

# Level 4 Validation would be manual, checking the web UI
Write-Host "🚦 Validation Round 4 - LANton Web UI" -ForegroundColor Yellow
Write-Host "Please manually open http://localhost:7071 to check if Dashboard loads." -ForegroundColor Yellow
Write-Host "(Press any key to continue after checking...)"
$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Level 5 Validation - Check if patches are applied
Write-Host "🚦 Validation Round 5 - Integration Patch-Ups" -ForegroundColor Yellow
$managementPatched = Select-String -Path "mock\darbot_management.html" -Pattern "fetch\('\/ports'\).then\(r=>r\.json\(\)\)"
$gamesCodePatched = Select-String -Path "mock\Games\code.html" -Pattern "LANHub Ports.*7071\/ports"

if ($managementPatched -and $gamesCodePatched) {
    Write-Host "✅ Round 5 Passed! Integration patches applied." -ForegroundColor Green
} else {
    Write-Host "❌ Round 5 Failed! Patches not properly applied." -ForegroundColor Red
    $allRoundsPassed = $false
}
Write-Host ""

# Level 6 Validation - CLI Convenience
Write-Host "🚦 Validation Round 6 - CLI Convenience" -ForegroundColor Yellow

# First, stop any running services to prevent port conflicts
Write-Host "Stopping any running services first..."
& .\lanton.ps1 stop all

Start-Sleep -Seconds 2

Write-Host "Running 'lanton start all'..."
& .\lanton.ps1 start all

Start-Sleep -Seconds 3

$result = & .\lanton.ps1 watch ports
Write-Host $result

if ($result -match "bitnet" -and $result -match "RUNNING") {
    Write-Host "✅ Round 6 Passed!" -ForegroundColor Green
} else {
    Write-Host "❌ Round 6 Failed! CLI not working correctly." -ForegroundColor Red
    $allRoundsPassed = $false
}
Write-Host ""

# Level 7 Validation - Packaging & Docs
Write-Host "🚦 Validation Round 7 - Packaging & Docs" -ForegroundColor Yellow
$hasLaunchJson = Test-Path -Path ".vscode\launch.json"
$hasDevContainer = Test-Path -Path ".devcontainer\devcontainer.json"

if ($hasLaunchJson -and $hasDevContainer) {
    Write-Host "✅ Round 7 Passed! VS Code configuration present." -ForegroundColor Green
      # Run markdown lint if npm is available
    try {
        npm --version | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Running markdown lint..."
            npm install -g markdownlint-cli
            markdownlint README.md
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Markdown lint passed!" -ForegroundColor Green
            } else {
                Write-Host "Markdown lint found issues." -ForegroundColor Yellow
                $allRoundsPassed = $false
            }
        }
    } catch {
        Write-Host "npm not available, skipping markdown lint." -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Round 7 Failed! Missing VS Code configuration files." -ForegroundColor Red
    $allRoundsPassed = $false
}
Write-Host ""

# Epilogue - Victory Banner
if ($allRoundsPassed) {
    Write-Host @"

🎉 LANton is operational – unified ports, dashboards & CLI ready!

"@ -ForegroundColor Green
} else {
    Write-Host "Some validation rounds failed. Please fix the issues and try again." -ForegroundColor Yellow
}

# Function to clean up processes
function Stop-AllServices {
    Write-Host "Cleaning up processes..." -ForegroundColor Yellow
    try {
        # Stop all services managed by lanton
        & .\lanton.ps1 stop all
        
        # Kill any remaining dotnet processes for LanHub
        Get-Process -Name "dotnet" | Where-Object { $_.CommandLine -match "LanHub" } | Stop-Process -Force -ErrorAction SilentlyContinue
        
        # Wait a moment for processes to terminate
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "Error stopping services: $_" -ForegroundColor Red
    }
}

# Cleanup processes
Stop-AllServices
