#!/usr/bin/env pwsh
# filepath: g:\Github\old\darbot-LANton\lanton_fixed.ps1
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
#   lanton status           - Show status of all services
#   lanton hostname <name>  - Configure custom hostname for LANton (requires admin)
#   lanton scan ports       - Scan all ports on the local machine
#   lanton history          - View port allocation history

param(
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "logs", "watch", "status", "hostname", "scan", "history")]
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
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    if (-not (Test-LanHubRunning)) {
        if ($PSCmdlet.ShouldProcess("LanHub", "Start")) {
            Write-Information "Starting LanHub..."
            $lanhubPath = Join-Path $PSScriptRoot "LanHub"
            Start-Process -FilePath "dotnet" -ArgumentList "run", "--project", $lanhubPath -NoNewWindow
            
            # Wait for LanHub to become available
            $retries = 0
            $maxRetries = 10
            while (-not (Test-LanHubRunning) -and $retries -lt $maxRetries) {
                Start-Sleep -Seconds 1
                $retries++
                Write-Information "Waiting for LanHub to start... ($retries/$maxRetries)"
            }
            
            if (-not (Test-LanHubRunning)) {
                Write-Error "Failed to start LanHub after $maxRetries attempts."
                exit 1
            }
            
            Write-Information "LanHub started successfully."
        }
    }
}

# Function to get all services
function Get-LantonService {
    try {
        return Invoke-RestMethod -Uri "$LanHubUrl/ports" -Method Get
    } catch {
        Write-Error ("Failed to get services from LanHub: " + $_.Exception.Message)
        exit 1
    }
}

# Function to start a service
function Start-ServiceWrapper {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string]$ServiceName
    )
    
    $wrapperPath = Join-Path $PSScriptRoot "wrappers\start_$($ServiceName.ToLower()).ps1"
    
    if (Test-Path $wrapperPath) {
        if ($PSCmdlet.ShouldProcess($ServiceName, "Start service")) {
            Write-Information "Starting $ServiceName..."
            & $wrapperPath -LanHubUrl $LanHubUrl
        }
    }
    else {
        Write-Error "No wrapper script found for service: $ServiceName"
    }
}

# Function to stop a service
function Stop-LantonService {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string]$ServiceName
    )
    
    $services = Get-LantonService
    
    if ($services.$ServiceName -and $services.$ServiceName.Pid) {
        $processPid = $services.$ServiceName.Pid
        if ($PSCmdlet.ShouldProcess("$ServiceName (PID: $processPid)", "Stop service")) {
            Write-Information "Stopping $ServiceName (PID: $processPid)..."
            try {
                Stop-Process -Id $processPid -ErrorAction SilentlyContinue
                $null = Invoke-RestMethod -Uri "$LanHubUrl/release/$ServiceName" -Method Post
                Write-Information "$ServiceName stopped."
            }
            catch {
                Write-Error ("Failed to stop ${ServiceName}: " + $_.Exception.Message)
            }
        }
    }
    else {
        Write-Information "$ServiceName is not running."
    }
}

# Function to show service log (simplified for now)
function Show-Log {
    param(
        [string]$ServiceName
    )
    
    Write-Information "Showing logs for $ServiceName (simulated)..."
    Write-Information "[$(Get-Date)] $ServiceName started"
    Write-Information "[$(Get-Date)] $ServiceName listening for connections"
    
    # In a real implementation, this would tail logs from a file or service
}

# Function to watch port in real-time
function Watch-Port {
    Write-Information "Watching port allocations. Press Ctrl+C to stop."
    Write-Information ""
    
    try {
        while ($true) {
            Clear-Host
            $services = Get-LantonService
            
            Write-Information "LANton Port Allocations - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            Write-Information "--------------------------------------------------------------"
            
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
        Write-Information "Stopped watching ports."
    }
}

# Function to scan all ports on the local machine
function Invoke-PortScan {
    param (
        [string]$OutputFormat = "console"
    )
    
    $scriptPath = Join-Path $PSScriptRoot "scripts\port_scanner_enhanced.ps1"
    if (Test-Path $scriptPath) {
        & $scriptPath -OutputFormat $OutputFormat
    }
    else {
        Write-Error "Port scanner script not found at $scriptPath"
    }
}

# Function to view port history
function Show-PortHistory {
    $historyPath = Join-Path $PSScriptRoot "history.csv"
    if (Test-Path $historyPath) {
        $history = Import-Csv -Path $historyPath
        
        Write-Information "LANton Port Allocation History:" 
        Write-Information "-------------------------------"
        
        if ($history.Count -eq 0) {
            Write-Information "No port allocation history found."
            return
        }
        
        $history | Format-Table -Property Timestamp, ServiceName, Port, Action, PID -AutoSize
    }
    else {
        Write-Information "No port allocation history found at $historyPath"
    }
}

# Function to set hostname in hosts file
function Set-LantonHostname {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Hostname
    )

    $hostsPath = "$env:windir\System32\drivers\etc\hosts"
    $localIP = "127.0.0.1"
    $hostEntry = "$localIP    $Hostname"

    # Check if we have admin rights
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Error "This command requires administrator rights. Please run PowerShell as Administrator."
        return
    }

    # Read the current hosts file
    $hostsContent = Get-Content -Path $hostsPath

    # Check if the hostname already exists
    $existingEntry = $hostsContent | Where-Object { $_ -match "^\s*\d+\.\d+\.\d+\.\d+\s+$Hostname\s*$" }
    
    if ($existingEntry) {
        Write-Information "Hostname '$Hostname' is already defined in hosts file."
    }
    else {
        # Add the new hostname entry
        if ($PSCmdlet.ShouldProcess("hosts file", "Add hostname entry for $Hostname")) {
            Add-Content -Path $hostsPath -Value "`r`n$hostEntry"
            Write-Information "Hostname '$Hostname' added to hosts file. You can now access LANton at http://$Hostname`:7071"
        }
    }
}

# Main execution
if (-not $Command) {
    Write-Output "LANton CLI - Command Line Interface for LANton services"
    Write-Output ""
    Write-Output "Usage:"
    Write-Output "  lanton start all        - Start all services"
    Write-Output "  lanton start <service>  - Start specific service"
    Write-Output "  lanton stop all         - Stop all services"
    Write-Output "  lanton stop <service>   - Stop specific service"
    Write-Output "  lanton logs <service>   - Show logs for specific service"
    Write-Output "  lanton watch ports      - Watch port allocation in real-time"
    Write-Output "  lanton status           - Show status of all services"
    Write-Output "  lanton hostname <name>  - Configure custom hostname for LANton (requires admin)"
    Write-Output "  lanton scan ports       - Scan all ports on the local machine"
    Write-Output "  lanton history          - View port allocation history"
    Write-Output ""
    Write-Output "Examples:"
    Write-Output "  lanton start all        - Start all LANton services"
    Write-Output "  lanton hostname lanton  - Make LANton accessible via http://lanton:7071"
    Write-Output "  lanton scan ports       - Show what ports are in use on this machine"
    exit 0
}

# Handle the hostname command separately since it doesn't need LanHub running
if ($Command -eq "hostname") {
    if (-not $Target) {
        Write-Error "Please specify a hostname. Usage: lanton hostname <name>"
    }
    else {
        Set-LantonHostname -Hostname $Target
    }
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
            
            $services = Get-LantonService
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
            $services = Get-LantonService
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
            Show-Log -ServiceName $Target
        }
        else {
            Write-Error "Please specify a service"
        }
    }
    
    "watch" {
        if ($Target -eq "ports") {
            Watch-Port
        }
        else {
            Write-Error "Only 'ports' can be watched"
        }
    }
    
    "status" {
        if (Test-LanHubRunning) {
            $services = Get-LantonService
            Write-Output "LANton Services Status:"
            Write-Output "-------------------------"
            
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
            Write-Output "LanHub is not running. Start it with: lanton start lanhub"
        }
    }

    "scan" {
        if ($Target -eq "ports") {
            Invoke-PortScan
        }
        else {
            Write-Error "Only 'ports' can be scanned"
        }
    }

    "history" {
        Show-PortHistory
    }
}
