#!/usr/bin/env pwsh
# filepath: d:\0GH_PROD\Darbot_Labs\darbot-LANton\wrappers\start_omniparser.ps1
#
# OmniParser Service Wrapper
# Reserves port and launches local_agent.py with the assigned port

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

# Reserve a port for omniparser
$body = @{
    name = "omniparser"
    desiredPort = 8800
} | ConvertTo-Json

try {
    $portResponse = Invoke-RestMethod -Uri "$LanHubUrl/reserve" -Method Post -Body $body -ContentType "application/json"
    $port = $portResponse.port
    Write-Host "Reserved port $port for OmniParser"
}
catch {
    Write-Error "Failed to reserve port for OmniParser: $_"
    exit 1
}

# Look for the local_agent.py script
$agentPath = Join-Path -Path $PSScriptRoot -ChildPath "..\lib\omniparser\local_agent.py"
if (Test-Path $agentPath) {
    # Set environment variable for port - the omniparser might use this instead of CLI args
    $env:OMNIPARSER_PORT = $port
    
    # Start the Python agent with port specified both as arg and env var for compatibility
    $process = Start-Process -FilePath "python" -ArgumentList $agentPath, "--port", $port -PassThru
}
else {
    Write-Error "OmniParser agent script not found at expected location: $agentPath"
    # Release the port since we're not using it
    $null = Invoke-RestMethod -Uri "$LanHubUrl/release/omniparser" -Method Post
    exit 1
}

# Register running service with its PID
$registerBody = @{
    name = "omniparser"
    port = $port
    pid = $process.Id
} | ConvertTo-Json

try {
    $null = Invoke-RestMethod -Uri "$LanHubUrl/register" -Method Post -Body $registerBody -ContentType "application/json"
    Write-Host "OmniParser registered with PID $($process.Id) on port $port"
}
catch {
    Write-Error "Failed to register OmniParser with LANton Hub: $_"
}

# Stream stdout to LANton WebSocket would go here, but that requires the WebSocket implementation

Write-Host "OmniParser is running. Press Ctrl+C to stop."

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
        $null = Invoke-RestMethod -Uri "$LanHubUrl/release/omniparser" -Method Post
        Write-Host "Port released for OmniParser"
    }
    catch {
        Write-Error "Failed to release port for OmniParser: $_"
    }
}
