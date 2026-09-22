# 프로젝트 현재 상태(Project State)

## 프로젝트

Project Knight

## 현재 단계

5대 관문 보스 및 일반 적군 4종 고해상도 아틀라스 리소스 전수 교체, 몬스터 상단 탑승 플랫폼(TopPlatform), 공격 애니메이션 VFX 전수 연동 및 Android 최신 APK 정식 빌드 완료 (Full Character & VFX Overhaul Complete)

## 현재 목표

Studio Director의 지시사항 완수:
1. 선택 코스 완료 보너스 효과와 진행 사항 알림 noti 텍스트 겹침 분리 완료
2. 최상층 몬스터 AI 멈춤 현상 해소 및 플랫폼 순찰/자율 전투 도약 구현
3. 5대 관문 보스(BossCommander, BeastChieftain, CrossbowCommander, AncientGolemGuardian, AbyssalArbiter) 고해상도 6프레임 아틀라스 리소스 전수 교체 및 박스 폴리곤 박멸
4. 일반 적 4종(TestEnemy, RangedEnemy, ChargingBeast, GroundSlamGolem) 고해상도 아틀라스 리소스 장착 및 박스 폴리곤 완전 은폐
5. 모든 몬스터 및 보스 머리 위 상단 탑승 플랫폼(`TopPlatform`, AnimatableBody2D One-Way) 장착
6. 전 보스 및 일반 몬스터의 고유 공격/특수기 애니메이션 이펙트(VFX) 전수 구현
7. 헤드리스 자동화 테스트 80개 검사항목 100% 무결점 통과 및 최신 Android APK 빌드 완주

## 최근 완료 작업 (High-Res Visuals, AI Mobility & HUD Polish)

- `stage_presentation.gd`: 선택 코스 완료 보너스 효과(`route_status`)와 진행 알림(`encounter_hint`, `toast`)의 겹침 현상 원천 차단 (동적 수직 스택 배치 및 전용 글래스모피즘 캡슐 필 HUD 적용)
- `test_enemy.gd`: 상층 몬스터 AI 개편 — 플레이어가 하층/지면에 있을 때도 시야 탐지(360px)하여 `State.CHASE`로 능동 전환, 발판 단차 드롭다운(`_perform_drop_down()`)을 통해 하층으로 자율 강하 및 교전 돌입, 순찰 중 스턱 시 자동 방향 반전
- `ranged_enemy.gd`: 사격 후 이동/재배치 쿨다운(`_attack_cooldown_remaining`) 적용으로 제자리 굳음 해소, 하층 플레이어 추적 강하 및 2D 목표 조준 발사(`configure_target`) 연동
- `enemy_projectile.gd`: 2D 임의 각도 궤적 및 목표 지점 지향(`configure_target`) 지원
- `tests/ai_enhancement_and_ui_scale_smoke.gd`: Check 11 추가로 상층 몬스터 하층 플레이어 감지 CHASE 전환 및 원거리 적 2D 조준 발사 검증 완료 (총 83 checks 100% PASS)
- 5대 관문 보스 및 일반 적 4종 고해상도 아틀라스 리소스/공격 애니메이션 VFX/TopPlatform 무결점 확인

## 최근 빌드 산출물

- **Android APK**: `CLIENT/Game/builds/android/ProjectKnight.apk` (103,057,596 bytes, ~98.28MB)
- **최신 빌드 일시**: 2026-09-17 15:20:26
- **패키지 명칭**: `com.junypapa.projectknight` (v1.0.0, arm64-v8a + armeabi-v7a)
- **서명 상태**: Android 35.0.0 apksigner 정식 서명 및 검증 완료 (Debug Keystore)

## 마지막 갱신

날짜: 2026-09-17
갱신자: 스튜디오 에이전트(Studio Agent)
