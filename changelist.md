# LANton Change Log

## Port Standardization and LAN Connectivity Update (May 11, 2025)

### Port Standardization

Changed the standard port from `6969` to `7071` across all project files for consistency:

1. **Core System Files:**
   - Updated `LanHub/Program.cs` to listen on port 7071 instead of 6969
   - Updated `LanHub/Properties/launchSettings.json` with new port configuration
   - Modified `README.md` to reflect new port information

2. **Startup Scripts:**
   - Updated `LanHub/start_lanton.ps1` with port 7071 references
   - Updated `LanHub/start_lanton.bat` with port 7071 references
   - Modified `start_lanton.ps1` in root directory with port 7071 references
   - Modified `start_lanton.bat` in root directory with port 7071 references

3. **Integration & Wrapper Scripts:**
   - Updated port references in `wrappers/start_bitnet.ps1`
   - Updated port references in `wrappers/start_flask_gui.ps1`
   - Updated port references in `wrappers/start_omniparser.ps1`
   - Updated port references in `lanton.ps1` (including hostname tool messaging)
   - Updated port number in `scripts/test_hostname.ps1`

4. **UI & Mock Integrations:**
   - Applied port lookup patches to `mock/darbot_management.html`
   - Applied endpoint discovery patches to `mock/Games/code.html`

### LAN Connectivity Improvement

Modified the server binding configuration to allow access from other machines on the local network:

1. **Network Interface Binding:**
   - Changed the URL binding in `start_lanton.bat` from `http://localhost:7071` to `http://*:7071`
   - This allows the server to listen on all network interfaces, not just localhost

2. **Hostname Configuration:**
   - Updated `lanton.ps1` hostname configuration to use port 7071 instead of 6969
   - Ensured hostname setup tool provides correct instructions for accessing LANton via custom hostname

### Access Methods

The LANton server can now be accessed through multiple methods:

1. Locally via: `http://localhost:7071`
2. On LAN via machine name: `http://[machine-name]:7071`
3. On LAN via custom hostname: `http://lanton:7071` (requires hostname setup with `lanton.ps1 hostname lanton`)