@echo off
REM Start LANton from the main directory
cd /d %~dp0
echo Starting LANton from the project root...

REM Navigate to LanHub directory and run the startup script
cd LanHub
call start_lanton.bat
