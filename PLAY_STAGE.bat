@echo off
chcp 65001 > nul
title Project Knight: Counterattack (Heroes War Tactical Edition)
set "WORKTREE_DIR=%~dp0"
set "BUILD_EXE=%WORKTREE_DIR%CLIENT\Game\builds\windows\ProjectKnight.exe"
set "GODOT_EXE=D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe"

if exist "%BUILD_EXE%" (
    start "" "%BUILD_EXE%"
    exit /b 0
)

start "" "%GODOT_EXE%" --path "%WORKTREE_DIR%CLIENT\Game" "res://scenes/ui/TitleScreen.tscn"
exit /b 0
