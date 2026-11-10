@echo off
setlocal
cd /d "%~dp0"
set PYTHON_EXE=pythonw.exe
where %PYTHON_EXE% >nul 2>nul
if %ERRORLEVEL% neq 0 (
    set PYTHON_EXE=python.exe
)
start "" %PYTHON_EXE% "%~dp0launcher.py"
endlocal
