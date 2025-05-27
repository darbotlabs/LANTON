# LANton Integration Guide

This guide explains how to integrate your Darbot service with LANton for port management and dashboard integration.

## Port Management

LANton acts as a central broker for port allocation, ensuring services don't conflict with each other. Here's how to integrate:

### 1. Reserve a Port

Before starting your service, request a port from LANton:

```powershell
# PowerShell Example
$response = Invoke-RestMethod -Method Post -Uri "http://localhost:7071/reserve" -Body (@{
    name = "your-service-name";
    desiredPort = 8080;  # Your preferred port
} | ConvertTo-Json) -ContentType "application/json"

# The port to use is in $response.port
$port = $response.port
```

```python
# Python Example
import requests
import json

response = requests.post(
    "http://localhost:7071/reserve", 
    json={"name": "your-service-name", "desiredPort": 8080}
)
port = response.json()["port"]
```

### 2. Register Your Running Service

After your service starts, register its PID with LANton:

```powershell
# PowerShell Example
$process = Get-Process -Id $PID  # Or however you track your process
Invoke-RestMethod -Method Post -Uri "http://localhost:7071/register" -Body (@{
    name = "your-service-name";
    port = $port;
    pid = $process.Id;
} | ConvertTo-Json) -ContentType "application/json"
```

```python
# Python Example
import os
import requests

pid = os.getpid()
requests.post(
    "http://localhost:7071/register", 
    json={"name": "your-service-name", "port": port, "pid": pid}
)
```

### 3. Release Port on Shutdown

When your service stops, inform LANton:

```powershell
# PowerShell Example
Invoke-RestMethod -Method Post -Uri "http://localhost:7071/release/your-service-name" 
```

```python
# Python Example
requests.post("http://localhost:7071/release/your-service-name")
```

## Dashboard UI Card Integration

To display your service on the LANton dashboard, include the following metadata in your registration:

```powershell
# PowerShell Example with UI metadata
$uiMetadata = @{
    name = "your-service-name";
    port = $port;
    pid = $process.Id;
    ui = @{
        displayName = "Your Service"; 
        description = "Brief description of what your service does";
        icon = "terminal";  # icon identifier
        color = "#00aa55";  # accent color
        endpoints = @(
            @{
                path = "/";
                name = "Dashboard";
                description = "Main service dashboard"
            },
            @{
                path = "/api/docs";
                name = "API Docs";
                description = "API documentation"
            }
        )
    }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Method Post -Uri "http://localhost:7071/register" -Body $uiMetadata -ContentType "application/json"
```

```python
# Python Example with UI metadata
ui_metadata = {
    "name": "your-service-name",
    "port": port,
    "pid": pid,
    "ui": {
        "displayName": "Your Service",
        "description": "Brief description of what your service does",
        "icon": "terminal",
        "color": "#00aa55",
        "endpoints": [
            {
                "path": "/",
                "name": "Dashboard",
                "description": "Main service dashboard"
            },
            {
                "path": "/api/docs",
                "name": "API Docs",
                "description": "API documentation"
            }
        ]
    }
}

requests.post("http://localhost:7071/register", json=ui_metadata)
```

## Service Wrapper Template

For best integration, create a wrapper script in the `wrappers/` directory:

```powershell
# wrappers/start_yourservice.ps1
param (
    [string]$LanHubUrl = "http://localhost:7071"
)

# Reserve a port
$response = Invoke-RestMethod -Method Post -Uri "$LanHubUrl/reserve" -Body (@{
    name = "your-service-name";
    desiredPort = 8080;
} | ConvertTo-Json) -ContentType "application/json"

$port = $response.port
Write-Host "Starting your-service on port $port..."

# Start your service (example)
$process = Start-Process -FilePath "path\to\your\service.exe" -ArgumentList "--port $port" -PassThru

# Register with LANton
$uiMetadata = @{
    name = "your-service-name";
    port = $port;
    pid = $process.Id;
    ui = @{
        displayName = "Your Service"; 
        description = "A cool Darbot service";
        icon = "terminal";
        color = "#00aa55";
        endpoints = @(
            @{
                path = "/";
                name = "Dashboard";
                description = "Main dashboard"
            }
        )
    }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Method Post -Uri "$LanHubUrl/register" -Body $uiMetadata -ContentType "application/json"
Write-Host "Service registered with LANton"
```

## API Endpoints Reference

### Port Management

| Endpoint | Method | Description | Request Body | Response |
|----------|--------|-------------|--------------|----------|
| `/ports` | GET | List all registered services and their ports | - | JSON object with service details |
| `/reserve` | POST | Reserve a port for a service | `{name, desiredPort}` | `{name, port, [message]}` |
| `/register` | POST | Register a running service | `{name, port, pid, [ui]}` | `{name, port, pid}` |
| `/release/{name}` | POST | Release a service's port | - | `{name, message}` |

### System Information

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/system-info` | GET | Get system information (hostname, IP, MAC) |

### PowerShell Execution

| Endpoint | Method | Description | Request Body | Response |
|----------|--------|-------------|--------------|----------|
| `/powershell/execute` | POST | Execute PowerShell commands | `{command}` | Command output |

## Best Practices

1. **Always reserve a port** before starting your service
2. **Always register your service** immediately after starting
3. **Always release your port** when shutting down
4. **Provide rich UI metadata** for better dashboard integration
5. **Use the wrapper script pattern** for consistent integration
