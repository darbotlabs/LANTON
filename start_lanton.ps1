# Start LANton from the main directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir
Write-Host "Starting LANton from the project root..."

# Navigate to LanHub directory and run the startup script
Set-Location -Path ".\LanHub"
& .\start_lanton.ps1
