# Start the LANton server and open the web UI
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir
Write-Host "Starting LANton server from $scriptDir..."

# Set the environment variables to specify paths and options
$env:ASPNETCORE_WEBROOT = "$scriptDir\wwwroot"
$env:ASPNETCORE_CONTENTROOT = $scriptDir
$env:DOTNET_WATCH_RESTART_ON_RUDE_EDIT = 1

# Kill any existing processes on port 7071
$processes = Get-NetTCPConnection -LocalPort 7071 -ErrorAction SilentlyContinue | 
    ForEach-Object { Get-Process -Id $_.OwningProcess }
if ($processes) {
    $processes | Stop-Process -Force
    Write-Host "Killed processes using port 7071"
}

# Start the server with the correct working directory
$process = Start-Process -PassThru -FilePath "dotnet" `
    -ArgumentList "bin/Debug/net8.0/LanHub.dll", "--urls=http://localhost:7071" `
    -WorkingDirectory $scriptDir

Write-Host "Waiting for server to initialize... (PID: $($process.Id))"
Start-Sleep -Seconds 5  # Wait for server to initialize
Start-Process "http://localhost:7071/"
