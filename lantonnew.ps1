#!/usr/bin/env pwsh
# filepath: d:\0GH_PROD\Darbot_Labs\darbot-LANton\lanton.ps1.new
#
# LANton CLI - Command Line Interface for LANton services
#
# Usage:
#   lanton start all        - Start all services
#   lanton start <service>  - Start specific service
#   lanton stop all         - Stop all services
#   lanton stop <service>   - Stop specific service
#   lanton logs <service>   - Show logs for specific service
#   lanton watch ports      - Watch port allocation in real-time

param(
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "logs", "watch", "status")]
    [string]$Command,
    
    [Parameter(Position=1)]
    [string]$Target,
    
    [Parameter(Position=2, ValueFromRemainingArguments=$true)]
    [string[]]$AdditionalArgs,
    
    [string]$LanHubUrl = "http://localhost:7071"
)

# Function to check if LanHub is running
function Test-LanHubRunning {
    try {
        $null = Invoke-RestMethod -Uri "$LanHubUrl/ports" -Method Get -TimeoutSec 2
        return $true
    }
    catch {
        return $false
    }
}

# Function to start LanHub if not running
function Start-LanHub {
    if (-not (Test-LanHubRunning)) {
        Write-Host "Starting LanHub..."
        $lanhubPath = Join-Path $PSScriptRoot "LanHub"
        Start-Process -FilePath "dotnet" -ArgumentList "run", "--project", $lanhubPath -NoNewWindow
        
        # Wait for LanHub to become available
        $retries = 0
        $maxRetries = 10
        while (-not (Test-LanHubRunning) -and $retries -lt $maxRetries) {
            Start-Sleep -Seconds 1
            $retries++
            Write-Host "Waiting for LanHub to start... ($retries/$maxRetries)"
        }
        
        if (-not (Test-LanHubRunning)) {
            Write-Error "Failed to start LanHub after $maxRetries attempts."
            exit 1
        }
        
        Write-Host "LanHub started successfully."
    }
}

# Function to get all services
function Get-Services {
    try {
        return Invoke-RestMethod -Uri "$LanHubUrl/ports" -Method Get
    }
    catch {
        Write-Error ("Failed to get services from LanHub: " + $_.Exception.Message)
        exit 1
    }
}

# Function to start a service
function Start-ServiceWrapper {
    param(
        [string]$ServiceName
    )
    
    $wrapperPath = Join-Path $PSScriptRoot "wrappers\start_$($ServiceName.ToLower()).ps1"
    
    if (Test-Path $wrapperPath) {
        Write-Host "Starting $ServiceName..."
        & $wrapperPath -LanHubUrl $LanHubUrl
    }
    else {
        Write-Error "No wrapper script found for service: $ServiceName"
    }
}

# Function to stop a service
function Stop-LantonService {
    param(
        [string]$ServiceName
    )
    
    $services = Get-Services
    
    if ($services.$ServiceName -and $services.$ServiceName.Pid) {
        $processPid = $services.$ServiceName.Pid
        Write-Host "Stopping $ServiceName (PID: $processPid)..."
        
        try {
            Stop-Process -Id $processPid -ErrorAction SilentlyContinue
            $null = Invoke-RestMethod -Uri "$LanHubUrl/release/$ServiceName" -Method Post
            Write-Host "$ServiceName stopped."
        }
        catch {
            Write-Error ("Failed to stop $ServiceName: " + $_.Exception.Message)
        }
    }
    else {
        Write-Host "$ServiceName is not running."
    }
}

# Function to show service logs (simplified for now)
function Show-Logs {
    param(
        [string]$ServiceName
    )
    
    Write-Host "Showing logs for $ServiceName (simulated)..."
    Write-Host "[$(Get-Date)] $ServiceName started"
    Write-Host "[$(Get-Date)] $ServiceName listening for connections"
    
    # In a real implementation, this would tail logs from a file or service
}

# Function to watch ports in real-time
function Watch-Ports {
    Write-Host "Watching port allocations. Press Ctrl+C to stop."
    Write-Host ""
    
    try {
        while ($true) {
            Clear-Host
            $services = Get-Services
            
            Write-Host "LANton Port Allocations - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            Write-Host "--------------------------------------------------------------"
            
            foreach ($service in $services.PSObject.Properties) {
                $name = $service.Name
                $port = $service.Value.Port
                $processPid = $service.Value.Pid
                $status = $service.Value.Status
                
                if ($status -eq "RUNNING") {
                    $statusColor = "Green"
                }
                else {
                    $statusColor = "Red"
                }
                
                Write-Host "$name".PadRight(15) -NoNewline
                Write-Host "Port: $port".PadRight(15) -NoNewline
                Write-Host "PID: $(if ($processPid) { $processPid } else { 'N/A' })".PadRight(15) -NoNewline
                Write-Host "Status: " -NoNewline
                Write-Host $status -ForegroundColor $statusColor
            }
            
            Start-Sleep -Seconds 2
        }
    }
    catch {
        # Handle Ctrl+C
        Write-Host "Stopped watching ports."
    }
}

# Main execution
if (-not $Command) {
    Write-Host "LANton CLI - Command Line Interface for LANton services"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  lanton start all        - Start all services"
    Write-Host "  lanton start <service>  - Start specific service"
    Write-Host "  lanton stop all         - Stop all services"
    Write-Host "  lanton stop <service>   - Stop specific service"
    Write-Host "  lanton logs <service>   - Show logs for specific service"
    Write-Host "  lanton watch ports      - Watch port allocation in real-time"
    Write-Host "  lanton status           - Show status of all services"
    exit 0
}

# Ensure LanHub is running before executing commands (except for 'status' which should work anyway)
if ($Command -ne "status") {
    Start-LanHub
}

# Handle commands
switch ($Command) {
    "start" {
        if ($Target -eq "all") {
            Start-LanHub
            
            $services = Get-Services
            foreach ($service in $services.PSObject.Properties) {
                if ($service.Name -ne "lan-ui") {  # Skip UI service
                    Start-ServiceWrapper -ServiceName $service.Name
                }
            }
        }
        elseif ($Target) {
            Start-ServiceWrapper -ServiceName $Target
        }
        else {
            Write-Error "Please specify a service or 'all'"
        }
    }
    
    "stop" {
        if ($Target -eq "all") {
            $services = Get-Services
            foreach ($service in $services.PSObject.Properties) {
                if ($service.Value.Pid) {
                    Stop-LantonService -ServiceName $service.Name
                }
            }
        }
        elseif ($Target) {
            Stop-LantonService -ServiceName $Target
        }
        else {
            Write-Error "Please specify a service or 'all'"
        }
    }
    
    "logs" {
        if ($Target) {
            Show-Logs -ServiceName $Target
        }
        else {
            Write-Error "Please specify a service"
        }
    }
    
    "watch" {
        if ($Target -eq "ports") {
            Watch-Ports
        }
        else {
            Write-Error "Only 'ports' can be watched"
        }
    }
    
    "status" {
        if (Test-LanHubRunning) {
            $services = Get-Services
            Write-Host "LANton Services Status:"
            Write-Host "-------------------------"
            
            foreach ($service in $services.PSObject.Properties) {
                $name = $service.Name
                $port = $service.Value.Port
                $processPid = $service.Value.Pid
                $status = $service.Value.Status
                
                if ($status -eq "RUNNING") {
                    $statusColor = "Green"
                }
                else {
                    $statusColor = "Red"
                }
                
                Write-Host "$name".PadRight(15) -NoNewline
                Write-Host "Port: $port".PadRight(15) -NoNewline
                Write-Host "PID: $(if ($processPid) { $processPid } else { 'N/A' })".PadRight(15) -NoNewline
                Write-Host "Status: " -NoNewline
                Write-Host $status -ForegroundColor $statusColor
            }
        }
        else {
            Write-Host "LanHub is not running. Start it with: lanton start lanhub"
        }
    }
}
