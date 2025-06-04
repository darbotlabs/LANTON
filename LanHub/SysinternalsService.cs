using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace LanHub
{
    public class SysinternalsService
    {
        private readonly string _sysinternalsPath;
        private readonly ILogger<SysinternalsService> _logger;
        private readonly HttpClient _httpClient;

        // List of Sysinternals tools we'll use
        public static readonly Dictionary<string, string> Tools = new()
        {
            { "PsList", "pslist.exe" },
            { "TCPView", "Tcpview.exe" },
            { "ProcessExplorer", "procexp.exe" },
            { "Handle", "handle.exe" },
            { "ListDLLs", "listdlls.exe" },
            { "PsInfo", "psinfo.exe" }
        };

        public SysinternalsService(ILogger<SysinternalsService> logger, IHttpClientFactory httpClientFactory)
        {
            _logger = logger;
            _httpClient = httpClientFactory.CreateClient("SysinternalsClient");
            
            // Create a directory for Sysinternals tools
            _sysinternalsPath = Path.Combine(Path.GetTempPath(), "LanHubSysinternals");
            Directory.CreateDirectory(_sysinternalsPath);
            
            _logger.LogInformation($"Sysinternals service initialized with path: {_sysinternalsPath}");
        }

        /// <summary>
        /// Downloads a Sysinternals tool if it doesn't exist locally
        /// </summary>
        public async Task<string> EnsureToolAvailableAsync(string toolName)
        {
            if (!Tools.TryGetValue(toolName, out var executableName))
            {
                throw new ArgumentException($"Unknown Sysinternals tool: {toolName}", nameof(toolName));
            }

            var localPath = Path.Combine(_sysinternalsPath, executableName);
            
            // Check if tool exists and is not older than 30 days
            bool shouldDownload = !File.Exists(localPath) || 
                                  File.GetLastWriteTime(localPath) < DateTime.Now.AddDays(-30);

            if (shouldDownload)
            {
                _logger.LogInformation($"Downloading {toolName} from Sysinternals Live...");
                
                try
                {
                    // Download from Sysinternals Live
                    var liveUrl = $"https://live.sysinternals.com/{executableName}";
                    var response = await _httpClient.GetAsync(liveUrl);
                    response.EnsureSuccessStatusCode();
                    
                    await using var stream = await response.Content.ReadAsStreamAsync();
                    await using var fileStream = new FileStream(localPath, FileMode.Create, FileAccess.Write, FileShare.None);
                    await stream.CopyToAsync(fileStream);
                    
                    _logger.LogInformation($"Successfully downloaded {toolName} to {localPath}");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Failed to download {toolName} from Sysinternals Live");
                    throw;
                }
            }
            
            return localPath;
        }

        /// <summary>
        /// Executes a Sysinternals tool with the specified arguments and returns the output
        /// </summary>
        public async Task<string> ExecuteToolAsync(string toolName, string arguments, bool acceptEula = true)
        {
            try
            {
                var toolPath = await EnsureToolAvailableAsync(toolName);
                
                var args = acceptEula ? $"/accepteula {arguments}" : arguments;
                
                var startInfo = new ProcessStartInfo
                {
                    FileName = toolPath,
                    Arguments = args,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                };

                _logger.LogInformation($"Executing {toolName} with arguments: {args}");
                
                using var process = new Process { StartInfo = startInfo };
                process.Start();
                
                var output = await process.StandardOutput.ReadToEndAsync();
                var error = await process.StandardError.ReadToEndAsync();
                
                await process.WaitForExitAsync();
                
                if (process.ExitCode != 0)
                {
                    _logger.LogWarning($"{toolName} exited with code {process.ExitCode}. Error: {error}");
                }
                
                return string.IsNullOrEmpty(error) ? output : $"ERROR: {error}\n\n{output}";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error executing {toolName}");
                return $"Error executing {toolName}: {ex.Message}";
            }
        }

        /// <summary>
        /// Gets a list of running processes using PsList
        /// </summary>
        public async Task<JsonDocument> GetProcessListAsync()
        {
            try
            {
                // Use PsList to get process information in CSV format
                var output = await ExecuteToolAsync("PsList", "-x -c");
                
                // Parse the text output into a JSON structure
                var lines = output.Split('\n')
                    .Select(line => line.Trim())
                    .Where(line => !string.IsNullOrWhiteSpace(line))
                    .ToList();

                // Find header line and process lines
                int headerIndex = lines.FindIndex(line => line.StartsWith("Process") && line.Contains("PID"));
                if (headerIndex < 0)
                {
                    return JsonDocument.Parse("[]"); // No valid data
                }
                
                var headerLine = lines[headerIndex];
                var headerParts = SplitPsListLine(headerLine);
                
                var result = new List<Dictionary<string, string>>();
                
                // Process each data line
                for (int i = headerIndex + 1; i < lines.Count; i++)
                {
                    if (string.IsNullOrWhiteSpace(lines[i]) || lines[i].StartsWith("---"))
                        continue;
                    
                    var parts = SplitPsListLine(lines[i]);
                    if (parts.Count != headerParts.Count)
                        continue; // Skip malformed lines
                    
                    var processInfo = new Dictionary<string, string>();
                    for (int j = 0; j < headerParts.Count && j < parts.Count; j++)
                    {
                        processInfo[headerParts[j]] = parts[j];
                    }
                    result.Add(processInfo);
                }
                
                var jsonString = JsonSerializer.Serialize(result);
                return JsonDocument.Parse(jsonString);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting process list");
                return JsonDocument.Parse("[]");
            }
        }

        /// <summary>
        /// Gets network connection information using TCPView data
        /// </summary>
        public async Task<JsonDocument> GetNetworkConnectionsAsync()
        {
            try
            {
                // TCPView doesn't have a command-line output format, so we use netstat as an alternative
                var output = await ExecuteToolAsync("Handle", "-a -nobanner");
                
                // Also get TCPView output for what we can
                var netstatOutput = ExecutePowerShellCommand("netstat -ano | ConvertTo-Json");
                
                // Combine and parse the outputs
                var connections = ParseNetworkConnections(netstatOutput);
                var jsonString = JsonSerializer.Serialize(connections);
                return JsonDocument.Parse(jsonString);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting network connections");
                return JsonDocument.Parse("[]");
            }
        }

        /// <summary>
        /// Gets system information using PsInfo
        /// </summary>
        public async Task<JsonDocument> GetSystemInfoAsync()
        {
            try
            {
                var output = await ExecuteToolAsync("PsInfo", "-d");
                var sysInfo = ParsePsInfoOutput(output);
                var jsonString = JsonSerializer.Serialize(sysInfo);
                return JsonDocument.Parse(jsonString);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting system information");
                return JsonDocument.Parse("{}");
            }
        }

        /// <summary>
        /// Gets detailed information about a specific process using ListDLLs
        /// </summary>
        public async Task<JsonDocument> GetProcessDetailsAsync(int pid)
        {
            try
            {
                var output = await ExecuteToolAsync("ListDLLs", $"{pid}");
                var processInfo = ParseListDllsOutput(output, pid);
                var jsonString = JsonSerializer.Serialize(processInfo);
                return JsonDocument.Parse(jsonString);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error getting details for process {pid}");
                return JsonDocument.Parse("{}");
            }
        }

        #region Parsing Helper Methods

        private List<string> SplitPsListLine(string line)
        {
            return line.Split(' ', StringSplitOptions.RemoveEmptyEntries).ToList();
        }

        private Dictionary<string, object> ParsePsInfoOutput(string output)
        {
            var result = new Dictionary<string, object>();
            var currentSection = "";
            
            foreach (var line in output.Split('\n'))
            {
                var trimmedLine = line.Trim();
                if (string.IsNullOrEmpty(trimmedLine))
                    continue;
                
                // Check if this is a section header
                if (trimmedLine.EndsWith(":") && !trimmedLine.Contains(":") && !trimmedLine.Contains("\\"))
                {
                    currentSection = trimmedLine.TrimEnd(':');
                    result[currentSection] = new Dictionary<string, string>();
                    continue;
                }
                
                // Try to parse key-value pair
                var parts = trimmedLine.Split(new[] { ':' }, 2);
                if (parts.Length == 2)
                {
                    var key = parts[0].Trim();
                    var value = parts[1].Trim();
                    
                    if (string.IsNullOrEmpty(currentSection))
                    {
                        result[key] = value;
                    }
                    else if (result[currentSection] is Dictionary<string, string> dict)
                    {
                        dict[key] = value;
                    }
                }
                else if (!string.IsNullOrEmpty(currentSection) && result[currentSection] is Dictionary<string, string> dict)
                {
                    // Add as a continuation of previous value
                    var lastKey = dict.Keys.LastOrDefault();
                    if (lastKey != null)
                    {
                        dict[lastKey] += " " + trimmedLine;
                    }
                }
            }
            
            return result;
        }

        private List<Dictionary<string, string>> ParseNetworkConnections(string netstatOutput)
        {
            var connections = new List<Dictionary<string, string>>();
            
            try
            {
                // Try to parse JSON if netstatOutput is in JSON format
                var jsonDoc = JsonDocument.Parse(netstatOutput);
                foreach (var element in jsonDoc.RootElement.EnumerateArray())
                {
                    var conn = new Dictionary<string, string>();
                    foreach (var property in element.EnumerateObject())
                    {
                        conn[property.Name] = property.Value.ToString();
                    }
                    connections.Add(conn);
                }
            }
            catch
            {
                // Fallback to text parsing for plain text netstat output
                var lines = netstatOutput.Split('\n');
                bool parsingData = false;
                
                foreach (var line in lines)
                {
                    if (string.IsNullOrWhiteSpace(line)) continue;
                    
                    if (line.Contains("Proto") && line.Contains("Local Address") && line.Contains("Foreign Address"))
                    {
                        parsingData = true;
                        continue;
                    }
                    
                    if (parsingData)
                    {
                        var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                        if (parts.Length >= 5)
                        {
                            connections.Add(new Dictionary<string, string>
                            {
                                ["Protocol"] = parts[0],
                                ["LocalAddress"] = parts[1],
                                ["ForeignAddress"] = parts[2],
                                ["State"] = parts[3],
                                ["PID"] = parts[4]
                            });
                        }
                    }
                }
            }
            
            return connections;
        }

        private Dictionary<string, object> ParseListDllsOutput(string output, int pid)
        {
            var result = new Dictionary<string, object>
            {
                ["PID"] = pid,
                ["DLLs"] = new List<Dictionary<string, string>>()
            };
            
            var lines = output.Split('\n');
            string? currentProcess = null;
            
            foreach (var line in lines)
            {
                if (string.IsNullOrWhiteSpace(line))
                    continue;
                
                if (line.StartsWith("ListDLLs") || line.StartsWith("Command line:") || line.StartsWith("Base") || line.StartsWith("---"))
                    continue;
                
                if (line.Contains(".exe"))
                {
                    currentProcess = line.Trim();
                    result["ProcessName"] = currentProcess;
                    continue;
                }
                
                // Parse DLL lines
                var parts = line.Trim().Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length >= 2 && currentProcess != null)
                {
                    var dllList = (List<Dictionary<string, string>>)result["DLLs"];
                    dllList.Add(new Dictionary<string, string>
                    {
                        ["Base"] = parts[0],
                        ["Size"] = parts.Length > 1 ? parts[1] : "",
                        ["Path"] = parts.Length > 2 ? string.Join(" ", parts.Skip(2)) : ""
                    });
                }
            }
            
            return result;
        }

        private string ExecutePowerShellCommand(string command)
        {
            try
            {
                var startInfo = new ProcessStartInfo
                {
                    FileName = "pwsh.exe",
                    Arguments = $"-Command \"{command}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                };                    using var process = Process.Start(startInfo);
                    if (process == null)
                    {
                        return "Failed to start PowerShell process";
                    }

                    string output = process.StandardOutput.ReadToEnd() ?? string.Empty;
                string error = process.StandardError.ReadToEnd();
                process.WaitForExit();

                if (!string.IsNullOrEmpty(error))
                {
                    return $"Error: {error}\n{output}";
                }

                return output;
            }
            catch (Exception ex)
            {
                return $"Error executing command: {ex.Message}";
            }
        }
        #endregion
    }
}
