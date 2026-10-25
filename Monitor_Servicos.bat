@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Monitor de Servicos do Windows - Auditoria
mode con: cols=120 lines=42 >nul 2>&1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Monitor-Servicos.ps1" %*
set "MONITOR_RESULT=%ERRORLEVEL%"
if not "%MONITOR_RESULT%"=="0" (
  echo.
  echo Nao foi possivel executar o monitor. Verifique a mensagem acima.
  pause
)
exit /b %MONITOR_RESULT%
