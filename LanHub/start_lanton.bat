@echo off
REM Start the LANton server and open the web UI
cd /d %~dp0
echo Starting LANton server...

REM Set environment variables for web root and content root
set ASPNETCORE_WEBROOT=%~dp0\wwwroot
set ASPNETCORE_CONTENTROOT=%~dp0
set DOTNET_WATCH_RESTART_ON_RUDE_EDIT=1

REM Kill any existing processes on port 7071
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :7071') do (
    taskkill /F /PID %%a >nul 2>&1
)

REM Start the server with correct working directory
start "LANton Server" cmd /c "cd /d %~dp0 && dotnet bin\Debug\net10.0\LanHub.dll --urls=http://*:7071"

echo Waiting for server to initialize...
timeout /t 5 > nul
start "LANton UI" http://localhost:7071/
