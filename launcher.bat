@echo off
:: ============================================================
:: Windows Setup Toolkit v1.0.0 - Launcher
:: ============================================================
:: Unico punto de entrada .bat del proyecto.
:: Su unico trabajo es elevar PowerShell y lanzar menu.ps1.
:: Toda la logica real vive en los scripts .ps1.
:: ============================================================

PowerShell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process powershell.exe -ArgumentList '-NoExit -NoProfile -ExecutionPolicy Bypass -File ""%~dp0menu.ps1""' -Verb RunAs"
