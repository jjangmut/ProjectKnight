@echo off
setlocal enabledelayedexpansion
set "GODOT_BIN=D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

echo ========================================================================
echo  [JUNYPAPA STUDIO] Continuous Quality & Development Loop Engine
echo ========================================================================
echo [INFO] Running ongoing continuous development & quality audit cycles...
echo [INFO] Press Ctrl+C at any time to pause or stop the loop.
echo.

set /a CYCLE=1

:loop
echo ------------------------------------------------------------------------
echo  >>> [CYCLE #!CYCLE!] Timestamp: %DATE% %TIME% <<<
echo ------------------------------------------------------------------------

"%GODOT_BIN%" --headless --path "%PROJECT_DIR%" -s "res://tests/daily_dev_process_runner.gd"

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Pipeline failed at Cycle #!CYCLE! with Exit Code: %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo.
echo [PASS] Cycle #!CYCLE! completed successfully. Waiting 10 seconds before next audit...
set /a CYCLE+=1
timeout /t 10 /nobreak >nul
goto loop
