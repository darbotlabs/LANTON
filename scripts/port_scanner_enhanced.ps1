#
# Enhanced Port Scanner for LANton
# Scans for used ports on the system and provides detailed reports

param (
    [int]$MinPort = 1024,
    [int]$MaxPort = 65535,
    [string]$OutputFormat = "console" # Options: console, json, csv
)

# Get all TCP connections (both listening and established)
function Get-AllTcpConnections {
    Write-Host "Scanning for active TCP connections..."
    
    # Get listening ports
    $listeningPorts = Get-NetTCPConnection -State Listen | Where-Object {$_.LocalPort -ge $MinPort -and $_.LocalPort -le $MaxPort}
    
    # Get established connections
    $establishedPorts = Get-NetTCPConnection -State Established | Where-Object {$_.LocalPort -ge $MinPort -and $_.LocalPort -le $MaxPort}
    
    return @{
        Listening = $listeningPorts
        Established = $establishedPorts
    }
}

# Get all UDP listeners
function Get-UdpListeners {
    Write-Host "Scanning for UDP listeners..."
    return Get-NetUDPEndpoint | Where-Object {$_.LocalPort -ge $MinPort -and $_.LocalPort -le $MaxPort}
}

# Get process details for a PID
function Get-ProcessDetails {
    param (
        [int]$ProcessId
    )
    
    try {
        $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($process) {
            return @{
                Name = $process.Name
                Path = $process.Path
                CommandLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId").CommandLine
                StartTime = $process.StartTime
                CPU = $process.CPU
                WorkingSet = $process.WorkingSet64
                Company = $process.Company
            }
        }
    }
    catch {
        # Process might have terminated
        return $null
    }
    
    return $null
}

# Get LANton registered services from the API
function Get-LantonServices {
    try {
        $services = Invoke-RestMethod -Uri "http://localhost:7071/ports" -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue
        return $services
    }
    catch {
        Write-Host "Could not connect to LANton Hub on port 7071. Is it running?"
        return $null
    }
}

# Generate full port scan report
function Get-PortScanReport {
    $allConnections = Get-AllTcpConnections
    $listeningPorts = $allConnections.Listening
    $establishedPorts = $allConnections.Established
    $udpListeners = Get-UdpListeners
    
    $lantonServices = Get-LantonServices
    
    $report = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        TcpListening = @()
        TcpEstablished = @()
        UdpListening = @()
        LantonRegistered = @()
        Summary = @{
            TotalTcpListening = $listeningPorts.Count
            TotalTcpEstablished = $establishedPorts.Count
            TotalUdpListening = $udpListeners.Count
            TotalLantonRegistered = if ($lantonServices) { $lantonServices.PSObject.Properties.Count } else { 0 }
        }
    }
    
    # Process listening TCP ports
    foreach ($port in $listeningPorts) {
        $processInfo = Get-ProcessDetails -ProcessId $port.OwningProcess
        
        $entry = @{
            Protocol = "TCP"
            LocalAddress = $port.LocalAddress
            LocalPort = $port.LocalPort
            RemoteAddress = $port.RemoteAddress
            RemotePort = $port.RemotePort
            State = $port.State
            ProcessId = $port.OwningProcess
            ProcessName = if ($processInfo) { $processInfo.Name } else { "Unknown" }
            ProcessPath = if ($processInfo) { $processInfo.Path } else { "Unknown" }
            CommandLine = if ($processInfo) { $processInfo.CommandLine } else { "Unknown" }
            IsLantonManaged = $false
        }
        
        # Check if this port is managed by LANton
        if ($lantonServices) {
            foreach ($service in $lantonServices.PSObject.Properties) {
                if ($service.Value.Port -eq $port.LocalPort) {
                    $entry.IsLantonManaged = $true
                    $entry.LantonServiceName = $service.Name
                    break
                }
            }
        }
        
        $report.TcpListening += $entry
    }
    
    # Process established TCP connections
    foreach ($port in $establishedPorts) {
        $processInfo = Get-ProcessDetails -ProcessId $port.OwningProcess
        
        $entry = @{
            Protocol = "TCP"
            LocalAddress = $port.LocalAddress
            LocalPort = $port.LocalPort
            RemoteAddress = $port.RemoteAddress
            RemotePort = $port.RemotePort
            State = $port.State
            ProcessId = $port.OwningProcess
            ProcessName = if ($processInfo) { $processInfo.Name } else { "Unknown" }
        }
        
        $report.TcpEstablished += $entry
    }
    
    # Process UDP listeners
    foreach ($port in $udpListeners) {
        $processInfo = Get-ProcessDetails -ProcessId $port.OwningProcess
        
        $entry = @{
            Protocol = "UDP"
            LocalAddress = $port.LocalAddress
            LocalPort = $port.LocalPort
            ProcessId = $port.OwningProcess
            ProcessName = if ($processInfo) { $processInfo.Name } else { "Unknown" }
        }
        
        $report.UdpListening += $entry
    }
    
    # Add LANton registered services
    if ($lantonServices) {
        foreach ($service in $lantonServices.PSObject.Properties) {
            $entry = @{
                Name = $service.Name
                Port = $service.Value.Port
                Pid = $service.Value.Pid
                Status = $service.Value.Status
            }
            
            $report.LantonRegistered += $entry
        }
    }
    
    return $report
}

# Export the report based on requested format
function Export-Report {
    param (
        [object]$Report,
        [string]$Format
    )
    
    switch ($Format.ToLower()) {
        "json" {
            $jsonPath = Join-Path -Path $PSScriptRoot -ChildPath "..\port_scan_report.json"
            $Report | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath -Encoding UTF8
            Write-Host "Report exported to: $jsonPath"
        }
        "csv" {
            $csvPath = Join-Path -Path $PSScriptRoot -ChildPath "..\port_scan_report.csv"
            
            # Convert the report sections to CSV
            $csvRows = @()
            
            foreach ($entry in $Report.TcpListening) {
                $row = [PSCustomObject]@{
                    Timestamp = $Report.Timestamp
                    Protocol = "TCP"
                    State = "LISTENING"
                    LocalAddress = $entry.LocalAddress
                    LocalPort = $entry.LocalPort
                    RemoteAddress = $entry.RemoteAddress
                    RemotePort = $entry.RemotePort
                    ProcessId = $entry.ProcessId
                    ProcessName = $entry.ProcessName
                    IsLantonManaged = $entry.IsLantonManaged
                    LantonServiceName = $entry.LantonServiceName
                }
                $csvRows += $row
            }
            
            $csvRows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host "Report exported to: $csvPath"
        }
        default {
            # Console output (default)
            Write-Host "`nPort Scan Report:" -ForegroundColor Cyan
            Write-Host "Timestamp: $($Report.Timestamp)" -ForegroundColor Yellow
            Write-Host "`nTCP LISTENING PORTS ($($Report.Summary.TotalTcpListening)):" -ForegroundColor Green
            $Report.TcpListening | Format-Table -Property LocalPort, LocalAddress, ProcessId, ProcessName, IsLantonManaged, LantonServiceName -AutoSize
            
            if ($Report.LantonRegistered.Count -gt 0) {
                Write-Host "`nLANTON REGISTERED SERVICES ($($Report.Summary.TotalLantonRegistered)):" -ForegroundColor Magenta
                $Report.LantonRegistered | Format-Table -Property Name, Port, Pid, Status -AutoSize
            }
            
            Write-Host "`nSUMMARY:" -ForegroundColor Cyan
            Write-Host "Total TCP Listening: $($Report.Summary.TotalTcpListening)" -ForegroundColor Yellow
            Write-Host "Total TCP Established: $($Report.Summary.TotalTcpEstablished)" -ForegroundColor Yellow
            Write-Host "Total UDP Listening: $($Report.Summary.TotalUdpListening)" -ForegroundColor Yellow
            Write-Host "Total LANton Registered: $($Report.Summary.TotalLantonRegistered)" -ForegroundColor Yellow
            
            # Suggest next available port range (simple suggestion)
            $usedPorts = $Report.TcpListening.LocalPort + $Report.UdpListening.LocalPort
            $nextAvailable = 1024
            while ($usedPorts -contains $nextAvailable) {
                $nextAvailable++
            }
            Write-Host "`nNext available port suggestion (>=1024): $nextAvailable" -ForegroundColor Green
        }
    }
}

# Main execution
$report = Get-PortScanReport
Export-Report -Report $report -Format $OutputFormat
