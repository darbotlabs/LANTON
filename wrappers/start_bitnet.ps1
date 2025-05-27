#!/usr/bin/env pwsh
# filepath: d:\0GH_PROD\Darbot_Labs\darbot-LANton\wrappers\start_bitnet.ps1
#
# BitNet Service Wrapper
# Reserves port and launches bitnet.exe or Python BitNet with the assigned port

param (
    [string]$LanHubUrl = "http://localhost:7071"
)

# Ensure LanHub is running
try {
    $null = Invoke-RestMethod -Uri "$LanHubUrl/ports" -Method Get -TimeoutSec 2
}
catch {
    Write-Error "Unable to connect to LANton Hub at $LanHubUrl. Please ensure it's running."
    exit 1
}

# Reserve a port for bitnet
$body = @{
    name = "bitnet"
    desiredPort = 8000
} | ConvertTo-Json

try {
    $portResponse = Invoke-RestMethod -Uri "$LanHubUrl/reserve" -Method Post -Body $body -ContentType "application/json"
    $port = $portResponse.port
    Write-Host "Reserved port $port for BitNet"
}
catch {
    Write-Error "Failed to reserve port for BitNet: $_"
    exit 1
}

# Check if bitnet.exe exists, otherwise try Python version
$bitnetExePath = Join-Path -Path $PSScriptRoot -ChildPath "..\bin\bitnet.exe"
if (Test-Path $bitnetExePath) {
    Write-Host "Using native BitNet executable"
    $process = Start-Process -FilePath $bitnetExePath -ArgumentList "--port", $port -PassThru -NoNewWindow
}
else {
    Write-Host "Looking for Python BitNet implementation"
    $bitnetPyPath = Join-Path -Path $PSScriptRoot -ChildPath "..\lib\bitnet\server.py"
    if (Test-Path $bitnetPyPath) {
        $process = Start-Process -FilePath "python" -ArgumentList $bitnetPyPath, "--port", $port -PassThru -NoNewWindow
    }
    else {
        Write-Error "Neither BitNet executable nor Python implementation found"
        # Release the port since we're not using it
        $null = Invoke-RestMethod -Uri "$LanHubUrl/release/bitnet" -Method Post
        exit 1
    }
}

# Register running service with its PID
$registerBody = @{
    name = "bitnet"
    port = $port
    pid = $process.Id
} | ConvertTo-Json

try {
    $null = Invoke-RestMethod -Uri "$LanHubUrl/register" -Method Post -Body $registerBody -ContentType "application/json"
    Write-Host "BitNet registered with PID $($process.Id) on port $port"
}
catch {
    Write-Error "Failed to register BitNet with LANton Hub: $_"
}

# Stream stdout to LANton WebSocket would go here, but that requires the WebSocket implementation

Write-Host "BitNet is running. Press Ctrl+C to stop."

try {
    # Wait for the process to exit or for user to press Ctrl+C
    $process.WaitForExit()
}
finally {
    # Release the port when the process exits
    if (-not $process.HasExited) {
        $process.Kill()
    }
    
    try {
        $null = Invoke-RestMethod -Uri "$LanHubUrl/release/bitnet" -Method Post
        Write-Host "Port released for BitNet"
    }
    catch {
        Write-Error "Failed to release port for BitNet: $_"
    }
}
