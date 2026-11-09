@echo off
title AD FINEM Stream Kit - Installer
if not exist "%~dp0_system\install.ps1" (
  echo.
  echo  Please UNZIP the folder first:
  echo  right-click the .zip file ^> "Extract All...", then run INSTALL.bat from the extracted folder.
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_system\install.ps1"
echo.
pause
