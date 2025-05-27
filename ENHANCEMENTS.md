# LANton Enhancements

## Completed Enhancements
1. **Port Changed**: 7071 → 6969 (nice)
2. **PowerShell Terminal Added**: New tab next to Commands tab
3. **System Info Display**: Shows system information below LANton header
4. **Custom Hostname**: Added 'lanton hostname' command for network access

## Files Modified
- **Program.cs**: 
  - Updated port to 6969
  - Added system information collection (IP, MAC, hostname)
  - Added /system-info endpoint 
  - Added PowerShell command execution endpoint

- **lanton.ps1**: 
  - Updated port to 6969
  - Added hostname command to configure local hostname
  - Improved help documentation

- **Wrapper Scripts**:
  - Updated port references in all service wrapper scripts

- **index.html**:
  - Added PowerShell tab
  - Added system info display section
  - Added PowerShell terminal UI and functionality

## How to Use

### PowerShell Terminal
The PowerShell terminal can be accessed in the LANton web interface by clicking on the "PowerShell" tab.
You can use it to run PowerShell commands directly from the web interface.

### System Information Display
The system information is automatically displayed below the LANton header and shows:
- System name
- IP addresses
- MAC addresses

### Custom Hostname
To make LANton accessible via a custom hostname on your local network:

```powershell
# Run with admin privileges
.\lanton.ps1 hostname lanton
```

This will allow you to access LANton at http://lanton:6969 from any device on your network.
