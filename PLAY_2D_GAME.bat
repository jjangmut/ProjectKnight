@echo off
chcp 65001 > nul
title Project Knight - 2D Classic Edition (Stage 1~5 Completed Version)
echo ===================================================================
echo [Project Knight] 2D 클래식 완성 에디션 (2D Side-Scrolling Action Edition)
echo - Stage 1 ~ Stage 5 횡스크롤 2D 정식 캠페인 실행
echo ===================================================================
start "" "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0CLIENT\Game" res://scenes/stage/Campaign.tscn
exit /b 0
