@echo off
chcp 65001 > nul
title Project Knight: Counterattack - Heroes War Tactical Edition (Stage 1~5 Full Campaign)
echo ===================================================================
echo [Project Knight : Counterattack] 히어로즈 워 택티컬 & 사이드 쿼터뷰 에디션
echo - 로비 & 도감: 히어로즈 워 택티컬 작전 사령부 & AX 기획 데이터 도감 (v2.0.0)
echo - 캠페인: OP-01 성문 외곽 ~ OP-05 침묵의 성채 (5개 스테이지 & 5대 보스)
echo - 시점: 3D 사이드 쿼터뷰 (-32도 피치 & 3D 벨트스크롤 깊이 이동)
echo ===================================================================
echo 조작법:
echo   - 이동: A, D (좌우 이동) / W, S (3D 깊이 안팎 이동)
echo   - 공격 / 3단 콤보 / 신성 관통창 검기: J 키 (우하단 STRIKE 버튼)
echo   - 점프: Space 키 (우하단 LEAP 버튼)
echo   - 방패 가드 / 0.14초 저스트 패링: K 키 (우하단 PARRY 버튼, 성공 시 3배 카운터)
echo   - 무적 회피 대시: Shift 키 (우하단 DASH 버튼)
echo   - AX 기획 데이터 도감: 타이틀 및 인게임 우상단 [AX 도감] 버튼
echo ===================================================================

set "GAME_DIR=%~dp0CLIENT\Game"
set "BUILD_EXE=%GAME_DIR%\builds\windows\ProjectKnight.exe"
set "GODOT_EXE=D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe"

if exist "%BUILD_EXE%" (
    start "" "%BUILD_EXE%"
    exit /b 0
)

if not exist "%GODOT_EXE%" (
    set "GODOT_EXE=D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
)

cd /d "%GAME_DIR%"
start "" "%GODOT_EXE%" --rendering-driver opengl3 "res://scenes/ui/TitleScreen.tscn"
exit /b 0
