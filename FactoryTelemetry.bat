@echo off
REM Launcher for the Factory Telemetry & OEE Monitor operator console.
REM Double-click to run, or pass args, e.g.:  FactoryTelemetry.bat -Target Local
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Start-FactoryConsole.ps1" %*
if errorlevel 1 pause
