# [TASK-CL-019] 영혼 파편(Soul Shards) 드랍, 자석 흡수 및 영구 세이브 연동

- 상태: DONE
- 담당: Client Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `DESIGN/COMBAT_JUICE_AND_BOSS_SPEC_001.md`


## 1. 개요
적 처치 시 포물선으로 튀어오르는 영혼 파편 액터 `shard_drop.gd`를 제작하고, 플레이어 접근 시 자석 유도 흡수, 수집 카운트 누적, `SaveManager` 영구 저장을 연동함.

## 2. 작업 내역
1. `CLIENT/Game/scripts/system/shard_drop.gd` 구현.
2. 적(`test_enemy.gd`, `ranged_enemy.gd`, `boss_commander.gd`) 사망 시 파편 방출 스폰.
3. 플레이어 및 세이브 시스템 영구 저장(`stats.soul_shards`) 연동.
