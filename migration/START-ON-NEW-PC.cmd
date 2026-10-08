@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=Join-Path $env:TEMP 'Hotshot-Bootstrap-New-PC.ps1'; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Chasmas/Godot-game-development/migration/beefier-pc-2026-10-08/migration/Bootstrap-New-PC.ps1' -OutFile $p; & $p"
pause
