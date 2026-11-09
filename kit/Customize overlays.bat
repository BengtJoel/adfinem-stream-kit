@echo off
rem Opens the AD FINEM overlay editor. Save writes straight to settings.js in this folder.
if not exist "%~dp0_system\editor.ps1" (
  echo Please UNZIP the folder first, then run this again.
  pause & exit /b 1
)
start "AD FINEM editor" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_system\editor.ps1"
