# [TASK-CL-023] 플레이어 대시(Dash) 및 공중 회피(Air Dash) I-Frame 시스템

- 상태: DONE
- 담당: Client Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `DESIGN/STAGE3_BOSS_AND_AIR_DASH_SPEC_001.md`

## 1. 개요
플레이어의 지상 및 공중 대시 메커니즘을 구현하고, 순간 고속 기동(540px/s), 무적 프레임(I-frame, 0.22초 지속 피격 무효화), 고스트 잔상(Ghost Trail) 및 공중 1회 제한 착지 리셋을 탑재함.

## 2. 완료 내역
- `player.gd`: `dash()`, `_update_dash_state()`, `_end_dash()`, `_spawn_ghost_trail()` 및 `dash_performed` 시그널 구현.
- `receive_attack()`, `receive_hit()`: 대시 상태(`is_dashing` or `is_invulnerable`) 시 공격 무효화/회피 로직 연동.
- 공중 대시 1회 제한(`_can_air_dash`) 및 착지 시 갱신 연동.
