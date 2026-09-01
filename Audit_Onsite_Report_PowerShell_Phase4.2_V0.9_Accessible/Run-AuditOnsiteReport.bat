@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File ".\Start-AuditOnsiteReport.ps1"
if errorlevel 1 pause
endlocal
