@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-Patch.ps1" %*
set "result=%errorlevel%"
pause
exit /b %result%
