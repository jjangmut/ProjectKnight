@echo off
chcp 65001 >nul
echo [Project Knight] 캐릭터 및 보스 스프라이트 정밀 검증 스튜디오 실행 중...
"D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0" "res://scenes/ui/SpriteInspectorTool.tscn"
