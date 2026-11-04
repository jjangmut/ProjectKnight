@echo off
setlocal
set "TASK_NAME=JUNYPAPA_ProjectKnight_DailyDevProcess"
set "BAT_PATH=%~dp0run_daily_dev_process.bat"

echo ========================================================================
echo  [JUNYPAPA STUDIO] Windows Task Scheduler Registration
echo ========================================================================
echo - Task Name: %TASK_NAME%
echo - Script Path: %BAT_PATH%
echo - Schedule: Daily at 09:00 AM (KST)
echo.

schtasks /create /tn "%TASK_NAME%" /tr "%BAT_PATH%" /sc daily /st 09:00 /f

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] Daily task successfully registered for 09:00 AM.
    echo Check status: schtasks /query /tn "%TASK_NAME%"
) else (
    echo.
    echo [NOTE] Administrator privileges may be required. Run as Administrator.
)

echo.
pause