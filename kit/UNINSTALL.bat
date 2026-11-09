@echo off
title AD FINEM Stream Kit - Uninstall
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_system\uninstall.ps1"
echo.
pause
