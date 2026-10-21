@echo off
chcp 65001 > nul
title Project Knight - True Quarter-View 3D Edition
echo ===================================================================
echo [Project Knight] 진정한 쿼터뷰 3D 에디션 (True Quarter-View 3D Edition)
echo Mixamo 3D 애니메이션 팔라딘과 3D 아레나 보스전을 시작합니다.
echo ===================================================================
echo 조작법:
echo   - 이동: W, A, S, D (또는 화살표 키 / 8방향 3D 자유 이동)
echo   - 공격 / 콤보 / 검기: J 키 (3타 피니셔 시 360도 크레센트 검기 방출)
echo   - 점프: Space 키 (3D 점프 및 보스 지진 충격파 회피)
echo   - 가드 / 0.14초 저스트 패링: K 키 (적 공격 순간 방어 시 3배 카운터)
echo   - 회피 대시: L 키 (무적 판정 고속 3D 대시)
echo   - 모바일 가상 패드: 화면 터치/클릭 지원
echo ===================================================================

set GODOT_EXE=D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe
set GAME_DIR=D:\JUNYPAPA_STUDIO\Worktrees\ProjectKnight\ART-STAGE-BATCH-001\CLIENT\Game

if not exist "%GODOT_EXE%" (
    set GODOT_EXE=D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe
)

start "" "%GODOT_EXE%" --path "%GAME_DIR%" "res://scenes/quarter_view_3d/QuarterViewArena3D.tscn"
exit /b 0
