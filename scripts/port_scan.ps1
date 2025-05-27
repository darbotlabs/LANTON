# Get all listening TCP ports >= 1024
$ports = Get-NetTCPConnection -State Listen | Where-Object {$_.LocalPort -ge 1024}

# Load the JSON manifest
$scriptPath = $PSScriptRoot
$manifestPath = Join-Path -Path $scriptPath -ChildPath "..\lan_ports.json" # Assuming script is in scripts/ and manifest is at root
$manifest = Get-Content $manifestPath | ConvertFrom-Json

Write-Host "Port Scan Results:"
Write-Host "------------------"

foreach ($serviceName in $manifest.PSObject.Properties.Name) {
    $desiredPort = $manifest.$serviceName
    $portInfo = $ports | Where-Object {$_.LocalPort -eq $desiredPort}

    if ($portInfo) {
        $process = Get-Process -Id $portInfo.OwningProcess -ErrorAction SilentlyContinue
        $executable = if ($process) { $process.Path } else { "N/A" }
        Write-Host "$serviceName $desiredPort ❌ Taken (PID: $($portInfo.OwningProcess), Executable: $executable)"
    } else {
        Write-Host "$serviceName $desiredPort ✅ Free"
    }
}

# Suggest next available port (simple suggestion)
$usedPorts = $ports.LocalPort
$nextAvailable = 1024
while ($usedPorts -contains $nextAvailable) {
    $nextAvailable++
}
Write-Host "------------------"
Write-Host "Next available general port suggestion (>=1024): $nextAvailable"
