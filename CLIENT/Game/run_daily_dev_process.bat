@echo off
setlocal
set "GODOT_BIN=D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

echo ========================================================================
echo  [JUNYPAPA STUDIO] Daily Game Dev Automation Pipeline
echo ========================================================================
echo [INFO] Running 5-phase daily development cycle...
echo.

"%GODOT_BIN%" --headless --path "%PROJECT_DIR%" -s "res://tests/daily_dev_process_runner.gd"

set "EXIT_CODE=%ERRORLEVEL%"
echo.
if %EXIT_CODE% EQU 0 (
    echo ========================================================================
    echo  [SUCCESS] Daily Dev Process Completed - 100%% PASS
    echo  [REPORT] Check: %PROJECT_DIR%\daily_reports\
    echo ========================================================================
) else (
    echo ========================================================================
    echo  [FAILURE] Daily Dev Process Failed with Exit Code: %EXIT_CODE%
    echo ========================================================================
)

exit /b %EXIT_CODE%