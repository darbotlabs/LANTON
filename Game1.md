## 🛠️ Level 1 – “Port Census”  
1. Write **`scripts/port_scan.ps1`** that lists all LISTENING ports ≥1024 and maps PIDs → executable.  
2. Add a **JSON manifest** `lan_ports.json` listing default wishes:  
   ```json
   { "lan-ui": 7070, "bitnet": 8000, "omniparser": 8800, "flask-gui": 5000 }
   ```  
3. Script prints ✅ free / ❌ taken and suggests next available port.  

### 🚦 Validation Round 1  
```powershell
pwsh -f scripts/port_scan.ps1 | findstr "lan-ui"
```
Expect `lan-ui 7070 ✅` (or alternative free suggestion).  

---

## 🧩 Level 2 – “Central Config Service (.NET 9 Minimal API)”  
1. Create **`LanHub/Program.cs`** (.NET 9) exposing:  
   - `GET /ports`  → current allocations  
   - `POST /reserve` `{ name, desiredPort }` → returns assigned port  
   - `POST /release/{name}`  
2. Use in-memory dictionary; later can persist to `lan_ports.json`.  

### 🚦 Validation Round 2  
```bash
dotnet run --project LanHub &
curl http://localhost:7071/ports   # 7071 temporary dev port
```
Expect JSON with manifest keys.

---

## 🔗 Level 3 – “P-Link Wrappers”  
1. For each service: BitNet (`bitnet.exe` or python), OmniParser (`local_agent.py`), Flask GUI (darbot_server.py), create **PowerShell** wrappers in `wrappers/*.ps1`.  
2. Each wrapper:  
   - Calls `/reserve` to get a port  
   - Launches service with that port (use `--port` or environment variable)  
   - Streams stdout → LANton websocket channel.  

### 🚦 Validation Round 3  
```powershell
.\wrappers\start_bitnet.ps1
curl http://localhost:7071/ports | findstr bitnet
```
Should show assigned port and PID.

---

## 🖥️ Level 4 – “LANton Web UI”  
Tech: plain **HTML + Alpine.js**.  
1. New file **`web/index.html`** served by LanHub at `/`.  
2. Pages/Tabs:  
   - **Dashboard** (service cards, status dots identical to darbot_management.html but live)  
   - **Ports** (real-time table)  
   - **Logs** (websocket tail)  
   - **Commands** (MCP console)  
3. Dark-retro palette reuse: copy CSS vars from `darbot_management.html`.  

### 🚦 Validation Round 4  
Open `http://localhost:7071` → *Dashboard loads, shows at least LanHub running*.  

---

## 🧪 Level 5 – “Integration Patch-Ups”  
1. Patch darbot_management.html → replace manual `bitnetApiPortInput` default with call to LanHub:  
   ```js
   fetch('/ports').then(r=>r.json()).then(p=>bitnetApiPortInput.value=p.bitnet);
   ```  
2. Patch `Games/code.html` endpoint discovery list to start with `LANHub /ports`.  

### 🚦 Validation Round 5  
Run LANton, then open dashboard & Tetris game – confirm both hit same BitNet port (no clashes).  

---

## ⚙️ Level 6 – “CLI Convenience”  
1. Add **global tool** entry-point `lanton.ps1` (PowerShell) with commands:  
   - `lanton start all` / `lanton stop bitnet` / `lanton logs omniparser` / `lanton watch ports`  
2. Under the hood it calls LanHub API.  

### 🚦 Validation Round 6  
```powershell
lanton start all
lanton watch ports | Select-String "bitnet.*RUNNING"
```
Expect running services listed.

---

## 📦 Level 7 – “Packaging & Docs”  
1. Update **README** with install instructions (dotnet build & pwsh requirements).  
2. Add VS Code *DevContainer* or *launch.json* for F5 experience.  

### 🚦 Validation Round 7  
`npm run lint-docs` (or markdown-lint) returns 0 warnings.  

---

## 🏆 Epilogue – “Victory Banner”  
When all 7 Validation Rounds pass **first try**, print:  

```
🎉 LANton is operational – unified ports, dashboards & CLI ready!
