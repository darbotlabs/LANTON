using System.Text.Json;
using Microsoft.AspNetCore.Http.Json;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using LanHub; // Add this for SysinternalsService

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls("http://*:7071"); // Listen on all interfaces with port 7071

// Add services
builder.Services.Configure<JsonOptions>(options =>
{
    options.SerializerOptions.WriteIndented = true;
});

// Register HttpClient
builder.Services.AddHttpClient("SysinternalsClient", client =>
{
    client.DefaultRequestHeaders.Add("User-Agent", "LanHub/1.0");
    client.Timeout = TimeSpan.FromSeconds(30);
});

// Register SysinternalsService
builder.Services.AddSingleton<SysinternalsService>();
builder.Services.AddLogging();

var app = builder.Build();

// In-memory storage for port assignments
var portRegistry = new Dictionary<string, (int Port, int? Pid)>();

// Initialize from lan_ports.json
string jsonPath = Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "lan_ports.json");
string historyPath = Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "history.csv");

// Ensure history.csv exists with header if it doesn't
if (!File.Exists(historyPath) || new FileInfo(historyPath).Length == 0)
{
    File.WriteAllText(historyPath, "Timestamp,ServiceName,Port,Action,PID\n");
}

try
{
    string jsonContent = File.ReadAllText(jsonPath);
    var defaultPorts = JsonSerializer.Deserialize<Dictionary<string, int>>(jsonContent);
    
    if (defaultPorts != null)
    {
        foreach (var entry in defaultPorts)
        {
            portRegistry[entry.Key] = (entry.Value, null); // No PID assigned yet
        }
    }
}
catch (Exception ex)
{
    Console.WriteLine($"Error loading lan_ports.json: {ex.Message}");
}

// Function to log port allocations to history.csv
void LogPortAllocation(string serviceName, int port, string action, int? pid = null)
{
    try
    {
        string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
        string pidValue = pid.HasValue ? pid.Value.ToString() : "N/A";
        string logEntry = $"{timestamp},{serviceName},{port},{action},{pidValue}\n";
        
        File.AppendAllText(historyPath, logEntry);
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Error logging to history.csv: {ex.Message}");
    }
}

// API Endpoints
app.MapGet("/", () => Results.Redirect("/index.html"));

// GET /ports - Return current port allocations
app.MapGet("/ports", () =>
{
    var result = portRegistry.ToDictionary(
        entry => entry.Key,
        entry => new 
        { 
            Port = entry.Value.Port,
            Pid = entry.Value.Pid,
            Status = entry.Value.Pid.HasValue ? "RUNNING" : "AVAILABLE"
        }
    );
    return result;
});

// POST /reserve - Reserve a port for a service
app.MapPost("/reserve", async (HttpRequest request) =>
{
    var json = await JsonSerializer.DeserializeAsync<JsonElement>(request.Body);
    string name = json.GetProperty("name").GetString() ?? "";
    int desiredPort = json.GetProperty("desiredPort").GetInt32();

    if (string.IsNullOrEmpty(name))
        return Results.BadRequest("Service name is required");

    // Check if port is already in use by another service
    var existingService = portRegistry.FirstOrDefault(p => p.Value.Port == desiredPort && p.Key != name);
    if (existingService.Key != null && existingService.Value.Pid.HasValue)
    {
        // Port is in use by another service, find next available port
        int nextPort = 1024;
        var usedPorts = portRegistry.Values.Select(v => v.Port).ToHashSet();
        while (usedPorts.Contains(nextPort)) nextPort++;
        
        portRegistry[name] = (nextPort, null);
        LogPortAllocation(name, nextPort, "RESERVE_ALTERNATIVE", null);
        return Results.Ok(new { name, port = nextPort, message = $"Desired port {desiredPort} in use, assigned {nextPort} instead" });
    }

    // Port is available or already assigned to this service
    portRegistry[name] = (desiredPort, null);
    LogPortAllocation(name, desiredPort, "RESERVE", null);
    return Results.Ok(new { name, port = desiredPort });
});

// POST /release/{name} - Release a port for a service
app.MapPost("/release/{name}", (string name) =>
{
    if (!portRegistry.ContainsKey(name))
        return Results.NotFound($"Service '{name}' not found");

    var (port, pid) = portRegistry[name];
    portRegistry[name] = (port, null); // Keep the port but clear the PID
    LogPortAllocation(name, port, "RELEASE", pid);
    return Results.Ok(new { name, message = $"Port for {name} released" });
});

// POST /register - Register a running service with its PID
app.MapPost("/register", async (HttpRequest request) =>
{
    var json = await JsonSerializer.DeserializeAsync<JsonElement>(request.Body);
    string name = json.GetProperty("name").GetString() ?? "";
    int port = json.GetProperty("port").GetInt32();
    int pid = json.GetProperty("pid").GetInt32();

    if (string.IsNullOrEmpty(name))
        return Results.BadRequest("Service name is required");

    if (!portRegistry.ContainsKey(name))
        portRegistry[name] = (port, pid);
    else
    {
        var (existingPort, _) = portRegistry[name];
        portRegistry[name] = (existingPort, pid);
    }
    
    LogPortAllocation(name, port, "REGISTER", pid);
    return Results.Ok(new { name, port, pid });
});

// Save port registry to lan_ports.json when application stops
app.Lifetime.ApplicationStopping.Register(() =>
{
    try
    {
        var defaultPorts = portRegistry.ToDictionary(
            entry => entry.Key,
            entry => entry.Value.Port
        );
        
        string jsonContent = JsonSerializer.Serialize(defaultPorts, new JsonSerializerOptions 
        { 
            WriteIndented = true 
        });
        
        File.WriteAllText(jsonPath, jsonContent);
        Console.WriteLine("Port registry saved to lan_ports.json");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Error saving lan_ports.json: {ex.Message}");
    }
});

// Add StaticFiles middleware to serve web content
app.UseStaticFiles();

// Get network information for the UI to display
string GetLocalIpAddress()
{
    var result = new System.Text.StringBuilder();
    string hostName = Dns.GetHostName();
    result.AppendLine($"System Name: {hostName}");
    
    // Get IP addresses
    var hostEntry = Dns.GetHostEntry(hostName);
    var ipAddresses = hostEntry.AddressList
        .Where(ip => ip.AddressFamily == AddressFamily.InterNetwork)
        .Select(ip => ip.ToString())
        .ToList();
    
    result.AppendLine($"IP Address(es): {string.Join(", ", ipAddresses)}");
    
    // Get MAC addresses
    var networkInterfaces = NetworkInterface.GetAllNetworkInterfaces()
        .Where(ni => ni.OperationalStatus == OperationalStatus.Up && 
               (ni.NetworkInterfaceType == NetworkInterfaceType.Ethernet || 
                ni.NetworkInterfaceType == NetworkInterfaceType.Wireless80211))
        .ToList();
    
    foreach (var ni in networkInterfaces)
    {
        var physicalAddress = ni.GetPhysicalAddress().ToString();
        if (!string.IsNullOrEmpty(physicalAddress))
        {
            var formattedMac = string.Join(":", Enumerable.Range(0, 6)
                .Select(i => physicalAddress.Substring(i * 2, 2)));
            result.AppendLine($"MAC Address ({ni.Name}): {formattedMac}");
        }
    }
    
    return result.ToString();
}

// Add endpoint to get system information
app.MapGet("/system-info", () => GetLocalIpAddress());

// GET /scan-ports - Scan all ports on the local machine
app.MapGet("/scan-ports", async () => {
    try {
        // Create a process to run the enhanced port scanner script
        var startInfo = new System.Diagnostics.ProcessStartInfo
        {
            FileName = "pwsh.exe",
            Arguments = $"-File \"{Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "scripts", "port_scanner_enhanced.ps1")}\" -OutputFormat json",
            RedirectStandardOutput = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        var process = new System.Diagnostics.Process { StartInfo = startInfo };
        process.Start();
        string output = await process.StandardOutput.ReadToEndAsync();
        await process.WaitForExitAsync();

        if (process.ExitCode == 0) {
            // Try to parse the JSON from the script output
            try {
                // Find the start of the JSON in case there's PowerShell output before it
                int jsonStart = output.IndexOf('{');
                if (jsonStart >= 0) {
                    output = output.Substring(jsonStart);
                }
                
                // Parse and return the JSON
                using var document = JsonDocument.Parse(output);
                return Results.Ok(document.RootElement);
            }
            catch (JsonException ex) {
                return Results.BadRequest($"Failed to parse port scan results: {ex.Message}");
            }
        }        else {
            return Results.BadRequest("Port scan failed");
        }
    }
    catch (Exception ex) {
        return Results.Problem($"Error during port scan: {ex.Message}", statusCode: 500);
    }
});

// Add endpoint for PowerShell command execution
app.MapPost("/powershell/execute", async (HttpRequest request) => {
    using var reader = new StreamReader(request.Body);
    var requestBody = await reader.ReadToEndAsync();
    var json = JsonSerializer.Deserialize<JsonElement>(requestBody);

    if (!json.TryGetProperty("command", out var commandElement))
    {
        return Results.Json(new { stdout = "", stderr = "No command provided", exitCode = 1 });
    }

    string command = commandElement.GetString() ?? string.Empty;
    if (string.IsNullOrWhiteSpace(command))
    {
        return Results.Json(new { stdout = "", stderr = "Empty command provided", exitCode = 1 });
    }

    // Execute the PowerShell command and return structured output
    try
    {
        var startInfo = new System.Diagnostics.ProcessStartInfo
        {
            FileName = "pwsh.exe",
            Arguments = $"-Command \"{command}\"",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var process = System.Diagnostics.Process.Start(startInfo);
        if (process == null)
        {
            return Results.Json(new { stdout = "", stderr = "Failed to start PowerShell process", exitCode = 1 });
        }

        string output = process.StandardOutput.ReadToEnd();
        string error = process.StandardError.ReadToEnd();
        process.WaitForExit();
        int exitCode = process.ExitCode;

        return Results.Json(new { stdout = output, stderr = error, exitCode });
    }
    catch (Exception ex)
    {
        return Results.Json(new { stdout = "", stderr = $"Error executing command: {ex.Message}", exitCode = 1 });
    }
});

// Add endpoints for Sysinternals tools
app.MapGet("/sysinternals/processes", async (SysinternalsService sysinternalsService) => {
    try {
        var processes = await sysinternalsService.GetProcessListAsync();
        return Results.Ok(processes);
    }
    catch (Exception ex) {
        return Results.Problem($"Failed to get processes: {ex.Message}", statusCode: 500);
    }
});

app.MapGet("/sysinternals/network", async (SysinternalsService sysinternalsService) => {
    try {
        var connections = await sysinternalsService.GetNetworkConnectionsAsync();
        return Results.Ok(connections);
    }
    catch (Exception ex) {
        return Results.Problem($"Failed to get network connections: {ex.Message}", statusCode: 500);
    }
});

app.MapGet("/sysinternals/sysinfo", async (SysinternalsService sysinternalsService) => {
    try {
        var sysInfo = await sysinternalsService.GetSystemInfoAsync();
        return Results.Ok(sysInfo);
    }
    catch (Exception ex) {
        return Results.Problem($"Failed to get system information: {ex.Message}", statusCode: 500);
    }
});

app.MapGet("/sysinternals/process/{pid}", async (int pid, SysinternalsService sysinternalsService) => {
    try {
        var processDetails = await sysinternalsService.GetProcessDetailsAsync(pid);
        return Results.Ok(processDetails);
    }
    catch (Exception ex) {
        return Results.Problem($"Failed to get process details: {ex.Message}", statusCode: 500);
    }
});



Console.WriteLine("LANton Hub started at http://localhost:7071");
Console.WriteLine("Available at:");
Console.WriteLine(GetLocalIpAddress());
app.Run();
