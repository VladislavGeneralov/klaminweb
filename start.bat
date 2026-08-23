@echo off
cd /d "%~dp0"
start "klamin-server" cmd /k "python -m http.server 8080 || python3 -m http.server 8080"
timeout /t 1 /nobreak >nul
start "" http://localhost:8080
