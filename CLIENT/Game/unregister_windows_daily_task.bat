@echo off
setlocal
set "TASK_NAME=JUNYPAPA_ProjectKnight_DailyDevProcess"

echo ========================================================================
echo  [JUNYPAPA STUDIO] Windows Task Scheduler Task Unregistration
echo ========================================================================

schtasks /delete /tn "%TASK_NAME%" /f

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] Scheduled task '%TASK_NAME%' has been removed.
) else (
    echo.
    echo [NOTE] Task not found or Administrator privileges required.
)

echo.
pause