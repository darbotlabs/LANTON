# LANton – Local Agent Network Controller

LANton is a lightweight command‑center that unifies every **Darbot** micro‑service running on `127.0.0.1` into a single dashboard, reverse‑proxy, and PowerShell CLI.

## ✨ Why LANton?

* **No more port clashes** – dynamic reservation & release API.
* **One front‑door** – YARP proxy maps `/svc/<name>` → right port.
* **Live traffic metrics** – WebSocket feed & rolling logs.
* **MCP‑style commands** – `lanton start/stop/watch` from any terminal.
* **Gamified build‑plan** – earn XP while contributing!

## 🧰 Prerequisites

| Tool           | Version                            |
| -------------- | ---------------------------------- |
| .NET 9 preview | `dotnet --version ≥ 9.0.0-preview` |
| PowerShell     | 7+                                 |
| Node           | 18+                                |
| Git            | –                                  |

## 🚀 Quick Start

```bash
# clone adjacent to darbot-framework
 git clone https://github.com/darbot-labs/darbot-LANton.git
 cd darbot-LANton

# build & launch (using startup scripts)
 .\start_lanton.ps1    # PowerShell
 start_lanton.bat      # Command Prompt

# access dashboard
#   http://localhost:7071
#   http://lanton:7071 (on local network)
#   http://[machine-name]:7071 (alternate access on LAN)
```

## 🔑 Security

* Bearer token (`LAN_TOKEN`) protects all API endpoints.
* CSRF token for UI mutations.
* Minimal RBAC: **admin** & **viewer** roles.

## 🖥️ Core Components

| Project               | Purpose                                           |
| --------------------- | ------------------------------------------------- |
| `LanHub`              | Port reservation & service registry (Minimal API) |
| `LANton.Api`          | YARP reverse‑proxy + WebSocket traffic stream     |
| `LANton.PortSurveyor` | Async port scanner / lanmap generator             |
| `control-deck/`       | Vite SPA dashboard                                |
| `wrappers/`           | PowerShell service launchers                      |
| `LANtonCli.psm1`      | Unified CLI module                                |

## ⚙️ CLI Cheatsheet

```powershell
lanton start all         # spin up every registered service
lanton stop bitnet       # stop specific service
lanton ports             # current port map
lanton watch traffic     # live bytes in/out per port
lanton network interfaces   # list active network interfaces
lanton network connections  # show active TCP connections
lanton network traffic      # show interface traffic summary
lanton network sniff 5      # capture packets for 5 seconds
```

## 🧪 Validation Suite

Run all automated checks:

```powershell
pwsh scripts/dev.ps1 -Command Test-All
```

## 🤝 Contributing

1. Fork & branch from `main`.
2. Complete quest level, run validations.
3. PR labelled `quest-<level>`.

## 📜 License

MIT © Darbot Labs

---

*Built with ♥ by the Darbot Council. May your ports never clash!*
