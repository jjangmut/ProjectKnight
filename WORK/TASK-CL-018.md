# [TASK-CL-018] 1지역 관문 보스 '타락한 방패 기사단장' 2페이즈 AI 및 아레나 봉쇄 구현

- 상태: DONE
- 담당: Client Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `DESIGN/COMBAT_JUICE_AND_BOSS_SPEC_001.md`


## 1. 개요
1지역 최종 인카운터에 배치되는 전용 보스 `boss_commander.gd`를 제작하고, 아레나 양방향 차단 게이트, 2페이즈 분노 전환, 지면 강타 충격파 투사체(`boss_shockwave.gd`), 보스 처치 시 슬로모션 연출을 연동함.

## 2. 작업 내역
1. `CLIENT/Game/scripts/enemy/boss_commander.gd` 및 `boss_shockwave.gd` 구현.
2. 1페이즈(방패 강타, 2단 대검 베기, 철벽 방어 자세) AI 로직.
3. 2페이즈(체력 <= 50% 분노, 도약 강타 충격파, 광포 돌진) AI 로직.
4. `first_stage.gd` 5번째 인카운터(최종장)에 보스 스폰 및 전후방 게이트 잠금 연동.
