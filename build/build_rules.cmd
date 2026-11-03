@echo off
rem Validate rules and rebuild README.md using Windows built-in PowerShell (no install needed).
rem   build\build_rules.cmd           rewrite README.md
rem   build\build_rules.cmd --check   fail if README.md is stale
setlocal
set "ARGS="
if /i "%~1"=="--check" set "ARGS=-Check"
if /i "%~1"=="-check" set "ARGS=-Check"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_rules.ps1" %ARGS%
set "RC=%ERRORLEVEL%"
rem Keep the window open when started by double-click from Explorer
echo %CMDCMDLINE% | find /i "/c" >nul && pause
exit /b %RC%
