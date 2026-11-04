@echo off
chcp 65001 >nul
echo [JUNYPAPA STUDIO] 3대 에이전트(기획·그래픽·QA) 자율 품질 검증 루틴 실행 중...
"D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0" -s "res://tests/studio_auto_pipeline_suite.gd"
pause
