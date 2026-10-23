@echo off
chcp 65001 > nul
title Project Knight - Side Quarter-View Edition (2D Characters + 3D World)
echo ===================================================================
echo [Project Knight] 사이드 쿼터뷰 에디션 (Side Quarter-View Edition)
echo - 캐릭터: 2D 고해상도 스프라이트 (팔라딘, 적, 보스 지휘관)
echo - 배경: 3D 석조 성채 아레나 (실시간 3D 조명 및 3D 그림자 투영)
echo - 시점: 사이드 쿼터뷰 (-15도 피치 앵글 & 3D 벨트스크롤 깊이 이동)
echo ===================================================================
echo 조작법:
echo   - 이동: A, D (좌우 이동) / W, S (3D 깊이 안팎 이동)
echo   - 공격 / 콤보 / 검기: J 키 (3타 시 360도 황금빛 3D 크레센트 검기 방출)
echo   - 점프: Space 키 (3D 물리 점프 & 보스 지진 충격파 회피)
echo   - 가드 / 0.14초 저스트 패링: K 키 (적 공격 순간 방어 시 스턴 + 3배 카운터)
echo   - 회피 대시: L 키 (무적 판정 고속 3D 대시)
echo   - 모바일 UI: 화면 터치 및 마우스 클릭 지원
echo ===================================================================

set "GAME_DIR=%~dp0CLIENT\Game"
set "GODOT_EXE=D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe"

if not exist "%GODOT_EXE%" (
    set "GODOT_EXE=D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
)

cd /d "%GAME_DIR%"
start "" "%GODOT_EXE%" --rendering-driver opengl3 "scenes/side_quarter_view/SideQuarterViewArena.tscn"
exit /b 0
