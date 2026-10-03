@echo off
rem Innovate Remote - double-click to install on this PC (asks for Administrator, then for the firm passphrase and a password for this PC)
title Install Innovate Remote
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-InnovateRemote.ps1" -Pause
if errorlevel 1 pause
