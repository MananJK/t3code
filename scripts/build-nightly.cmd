@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-nightly.ps1" %*
exit /b %ERRORLEVEL%
