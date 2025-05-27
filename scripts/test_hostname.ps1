#
# LANton Hostname Test Script
# This script tests if the LANton hub is accessible via the custom hostname

param (
    [string]$Hostname = "lanton",
    [int]$Port = 7071
)

Write-Host "Testing connection to LANton via custom hostname..." -ForegroundColor Cyan
Write-Host "URL: http://$Hostname`:$Port" -ForegroundColor Yellow
Write-Host ""

try {
    $response = Invoke-WebRequest -Uri "http://$Hostname`:$Port" -Method GET -TimeoutSec 5
    
    if ($response.StatusCode -eq 200) {
        Write-Host "SUCCESS: Connected to LANton via custom hostname!" -ForegroundColor Green
        Write-Host "Status Code: $($response.StatusCode)"
        Write-Host "Content Length: $($response.Content.Length) bytes"
    } else {
        Write-Host "WARNING: Received unexpected status code $($response.StatusCode)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "ERROR: Failed to connect to LANton via custom hostname" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    
    Write-Host "`nAttempting to connect via localhost instead..." -ForegroundColor Cyan
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$Port" -Method GET -TimeoutSec 5
        
        if ($response.StatusCode -eq 200) {
            Write-Host "SUCCESS: Connected to LANton via localhost!" -ForegroundColor Green
            Write-Host "The LANton server is running, but the custom hostname might not be configured properly."
            Write-Host "Try running: .\lanton.ps1 hostname $Hostname (with administrator privileges)"
        }
    }
    catch {
        Write-Host "ERROR: Failed to connect via localhost as well" -ForegroundColor Red
        Write-Host "Is the LANton Hub running? Start it with: .\lanton.ps1 start all"
    }
}

Write-Host "`nIf you've set up the hostname correctly, you should be able to access LANton at:" -ForegroundColor Cyan
Write-Host "http://$Hostname`:$Port" -ForegroundColor Yellow
