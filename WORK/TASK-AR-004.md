# 작업(Task)

작업 ID: TASK-AR-004
제목: 기사 플레이어 액션 스프라이트 시트 실에셋 검증 및 어댑터 연동
상태: DONE (에셋 확인 및 PlayerArt 17 checks PASS)
분야: AR (아트)
담당: Art Lead
결정 근거: DEC-008 (버티컬 슬라이스 프로덕션 전환)
참조 문서: DESIGN/PLAYER_SPRITE_SPEC_001.md, CLIENT/Game/assets/player_frames/motion_manifest.json

## 1. 지시

`DESIGN/PLAYER_SPRITE_SPEC_001.md`에 규격화된 기사 플레이어의 핵심 액션 스프라이트 시트(`idle_v1.png`, `run_v2.png`, `attack_v2.png`, `guard_v1.png`, `hurt_v1.png`, `death_v1.png`, `jump_v1.png`)와 `motion_manifest.json`을 검증하고, `Player.tscn`의 `PlayerArt` 어댑터 노드와의 연동 무결성을 확인한다.

## 2. 완료 조건

1. `assets/player_frames/`의 7대 모션 프레임 시트 및 매니페스트 피벗 정합성 확인.
2. `player_art.gd`를 통한 달리기/대기/공격/방어/피격 스프라이트 동적 전환 검증.
3. 자동 QA `tests/player_art_smoke.gd` 실행 및 17 checks 0 failures PASS.

## 3. 결과물

- `CLIENT/Game/assets/player_frames/motion_manifest.json`
- `tests/player_art_smoke.gd` (17 checks PASS)
