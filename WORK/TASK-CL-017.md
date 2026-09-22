# [TASK-CL-017] 전투 주스 엔진 (HitStop, Screen Shake, Floating Damage Text) 구축

- 상태: DONE
- 담당: Client Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `DESIGN/COMBAT_JUICE_AND_BOSS_SPEC_001.md`


## 1. 개요
타격 시 프레임 프리즈(HitStop), 비선형 감쇠 카메라 흔들림(Camera Shake), 동적 플로팅 전투 대미지 텍스트를 관장하는 중앙 모듈 `game_feel_manager.gd`를 구축하고, 플레이어 및 적 피격 로직에 연동함.

## 2. 작업 내역
1. `CLIENT/Game/scripts/system/game_feel_manager.gd` 구현.
2. `player.gd`에 타격 시 히트스톱, 카메라 셰이크, 대미지 폰트 연동.
3. `test_enemy.gd`, `ranged_enemy.gd` 피격 시 연동.
