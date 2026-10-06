# [TASK-AR-018] Stage 4 Ground Slam Redraw Blocker Fix

## 상태

`INDEPENDENT REVIEW REQUESTED`

## 담당

Antigravity / JPStudio Graphics Quality Director + Client QA

## 우선순위

`P0 BLOCKER`

## 기준 브랜치

`antigravity/graphics-quality-pass-004-stage4`

## 신규 작업 브랜치

`antigravity/graphics-quality-pass-004-stage4-r1`

---

# 1. 작업 목적

TASK-AR-017 독립 검수에서 발견된 Stage 4 Blocker를 수정:
- `StageArt._process()`의 선택적 `queue_redraw()` 조건에 GroundSlamGolem의 windup 및 active slam 상태가 누락되어 정적 상황에서 공격 VFX가 매 프레임 갱신되지 못하던 결함 해결.
- 전투 상태 기반 선택적 redraw 트리거 및 공격 종료 시 잔상 제거 1회 cleanup redraw 구조 확립.
- 유휴(Idle) 상태에서의 무조건적 상시 리드로우 회귀 원천 차단.

---

# 2. 작업 완료 및 검증 내역

1. **`StageArt._process()` 선택적 리드로우 조건 추가**:
   - `_attach()`에서 `GroundSlamGolem` 등록 시 `"ground_slam"` 메타 플래그 명시적 연동.
   - `actors` 순회 시 `(entry.ground_slam or entry.variant == "golem") and actor.state == 2 and (actor.attack_phase == 0 or actor.is_attack_active)` 조건으로 `needs_redraw = true` 트리거.
   - 공격 종료 시 `_had_combat_draw` 메커니즘을 통해 정확히 1회 잔상 제거 redraw 호출 후 정적 상태 복귀.
2. **테스트 Instrumentation**:
   - `redraw_request_count`, `combat_redraw_active` 경량 카운터 연동으로 프로덕션 부하 없이 결정론적 검증 지원.
3. **신규 자동화 스모크 테스트 작성 및 PASS**:
   - `tests/stage4_ground_slam_redraw_smoke.gd` (17/17 checks PASS)
     - TEST 1 (Idle): 10 프레임 동안 0건 리드로우 (상시 리드로우 회귀 없음)
     - TEST 2 (Windup): 공격 윈드업 매 프레임 리드로우 갱신 (5/5)
     - TEST 3 (Active Slam): 액티브 지면 강타 매 프레임 리드로우 갱신 (5/5)
     - TEST 4 (Attack End): 공격 종료 시 잔상 제거용 정확히 1회 cleanup 리드로우
     - TEST 5 (No Permanent Redraw): 이후 20 프레임 동안 0건 리드로우 (정적 상태 완전 복귀)
4. **수동 캡처 완료 (`ART_REVIEW/graphics-pass-004-stage4-r1/`)**:
   - `01_ground_slam_windup.png`: 호박색/주황 지면 균열 림, ㄷ자 코너 브래킷, 룬 틱 가독성 확인.
   - `02_ground_slam_active.png`: 지면 충격파 링, 초고휘도 코어, 암석 파편 비산 확인.
5. **성능 게이트 재계측 (4개 전 구간 압도적 PASS)**:
   - Entry: Avg 263.7 FPS, 1% Low 215.9 FPS, P99 4.63 ms
   - First Golem: Avg 244.1 FPS, 1% Low 152.3 FPS, P99 6.57 ms (기준 > 120 FPS 대폭 상회)
   - Mid Sanctuary: Avg 218.0 FPS, 1% Low 146.2 FPS, P99 6.84 ms
   - Boss Combat: Avg 265.8 FPS, 1% Low 191.8 FPS, P99 5.21 ms (기준 > 120 FPS 대폭 상회)
6. **전체 회귀 테스트 100% PASS**:
   - 17개 테스트 스위트 전원 통과 (Stage 1/2/3 무회귀 입증).
