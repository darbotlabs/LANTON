#!/usr/bin/env pwsh
# filepath: d:\0GH_PROD\Darbot_Labs\darbot-LANton\wrappers\start_flask_gui.ps1
#
# Flask GUI Service Wrapper
# Reserves port and launches darbot_server.py with the assigned port

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

# Reserve a port for flask-gui
$body = @{
    name = "flask-gui"
    desiredPort = 5000
} | ConvertTo-Json

try {
    $portResponse = Invoke-RestMethod -Uri "$LanHubUrl/reserve" -Method Post -Body $body -ContentType "application/json"
    $port = $portResponse.port
    Write-Host "Reserved port $port for Flask GUI"
}
catch {
    Write-Error "Failed to reserve port for Flask GUI: $_"
    exit 1
}

# Look for the darbot_server.py script
$serverPath = Join-Path -Path $PSScriptRoot -ChildPath "..\lib\flask-gui\darbot_server.py"
if (Test-Path $serverPath) {
    # Set environment variable for port - Flask uses FLASK_RUN_PORT
    $env:FLASK_RUN_PORT = $port
    $env:FLASK_APP = $serverPath
    
    # Start the Flask server
    $process = Start-Process -FilePath "python" -ArgumentList "-m", "flask", "run", "--port", $port -PassThru
}
else {
    Write-Error "Flask GUI server script not found at expected location: $serverPath"
    # Release the port since we're not using it
    $null = Invoke-RestMethod -Uri "$LanHubUrl/release/flask-gui" -Method Post
    exit 1
}

# Register running service with its PID
$registerBody = @{
    name = "flask-gui"
    port = $port
    pid = $process.Id
} | ConvertTo-Json

try {
    $null = Invoke-RestMethod -Uri "$LanHubUrl/register" -Method Post -Body $registerBody -ContentType "application/json"
    Write-Host "Flask GUI registered with PID $($process.Id) on port $port"
}
catch {
    Write-Error "Failed to register Flask GUI with LANton Hub: $_"
}

# Stream stdout to LANton WebSocket would go here, but that requires the WebSocket implementation

Write-Host "Flask GUI is running. Press Ctrl+C to stop."

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
        $null = Invoke-RestMethod -Uri "$LanHubUrl/release/flask-gui" -Method Post
        Write-Host "Port released for Flask GUI"
    }
    catch {
        Write-Error "Failed to release port for Flask GUI: $_"
    }
}
