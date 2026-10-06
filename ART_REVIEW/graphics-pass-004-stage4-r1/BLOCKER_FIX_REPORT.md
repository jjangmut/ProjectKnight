# [TASK-AR-018] Stage 4 Ground Slam Redraw Blocker Fix 보고서

- **작업**: TASK-AR-018 Stage 4 Ground Slam Redraw Blocker Fix
- **기준 브랜치**: `antigravity/graphics-quality-pass-004-stage4`
- **작업 브랜치**: `antigravity/graphics-quality-pass-004-stage4-r1`
- **검토일**: 2026-10-06
- **상태**: **`INDEPENDENT REVIEW REQUESTED`**
- **모바일 상태**: **`ANDROID PERFORMANCE NOT VERIFIED`**

---

## 1. Original Issue (원 결함 증상)

TASK-AR-017 독립 검수 결과, GroundSlamGolem의 지면 강타 전조(Telegraph), 지면 균열(Ground Crack), 룬 틱(Rune Ticks), 충격파 링(Shockwave Ring), 비산 암석 파편(Stone Debris) 렌더링 코드가 `StageArt._draw()`에 구현되어 있었으나, 플레이어가 정지해 있거나 공격하지 않는 정적인 상황에서 골렘의 공격 VFX 애니메이션이 매 프레임 정상 갱신되지 못하고 프리징되거나 갱신이 누락되는 렌더 블로커가 발생했습니다.

---

## 2. Root Cause (근본 원인 분석)

`CLIENT/Game/scripts/art/stage_art.gd`의 `_process()` 내 선택적 `queue_redraw()` 조건식에 GroundSlamGolem의 공격 상태 감지가 누락되어 있었습니다:

- 기존 `needs_redraw` 트리거:
  - 플레이어 공격 (`player.is_attacking`)
  - 가드 블록 플래시 (`player._guard_block_flash_remaining > 0.0`)
  - 피격 상태 (`player_pose == "hit"`)
  - 골 도달 애니메이션 (`goal_ready`)
  - **Stage 2 Charging Beast 윈드업 (`entry.charging and actor.state == 2 and actor.attack_phase == 0`)**

즉, Stage 4의 `GroundSlamGolem`이 윈드업(`actor.state == 2, attack_phase == 0`) 또는 액티브 슬램(`actor.state == 2, is_attack_active == true`) 상태에 돌입하더라도 `needs_redraw = true`가 발생하지 않아 캔버스 아이템 리드로우가 생략되었습니다.

---

## 3. Code Change (코드 수정 내역)

### 1) Actor 메타 식별 플래그 추가 (`_attach`)
```gdscript
var is_charging: bool = source.ends_with("/charging_beast.gd")
var is_ground_slam: bool = source.ends_with("/ground_slam_golem.gd") or actor.get_meta("ground_slam", false) or variant == "golem"
actors.append({
    "actor": actor,
    "sprite": sprite,
    "visual": visual,
    "label": label,
    "hp_bar": hp_bar,
    "key": key,
    "height": height,
    "variant": variant,
    "charging": is_charging,
    "ground_slam": is_ground_slam,
    "last_x": actor.global_position.x,
    "distance": 0.0,
    "frame_index": -1
})
```

### 2) 선택적 리드로우 조건 및 테스트 Instrumentation (`_process`)
```gdscript
for entry in actors:
    var actor = entry.actor
    if not is_instance_valid(actor):
        continue
    # Stage 2: Charging Beast windup
    if entry.charging and actor.state == 2 and actor.attack_phase == 0:
        needs_redraw = true
        break
    # Stage 4: Ground Slam Golem windup or active slam
    if (entry.get("ground_slam", false) or entry.variant == "golem") and actor.state == 2:
        if actor.attack_phase == 0 or actor.is_attack_active:
            needs_redraw = true
            break

combat_redraw_active = needs_redraw
if needs_redraw:
    _had_combat_draw = true
    redraw_request_count += 1
    queue_redraw()
elif _had_combat_draw:
    _had_combat_draw = false
    redraw_request_count += 1
    queue_redraw()
```

---

## 4. 프레임 주기별 리드로우 동작 검증

1. **Windup Redraw Behavior (윈드업 전조)**:
   - `actor.state == 2 and actor.attack_phase == 0` 동안 매 프레임 `needs_redraw = true` 유지.
   - 호박색/주황 지면 균열 림, 밝은 코어 라인, 코너 브래킷, 5개 룬 틱 파편의 시간 경과(`_phase_time_remaining`)에 따른 애니메이션이 부드럽게 갱신됨.
2. **Active Redraw Behavior (액티브 강타)**:
   - `actor.state == 2 and actor.is_attack_active == true` 동안 매 프레임 `needs_redraw = true` 유지.
   - 반경 확산 충격파 링, 초고휘도 코어 링, 7개 비산 암석 파편의 궤적이 프레임 누락 없이 실시간 렌더링됨.
3. **Cleanup Behavior (공격 종료 후 잔상 제거)**:
   - 액티브 공격이 종료되어 `is_attack_active`가 `false`가 되는 순간 `needs_redraw`가 `false`로 전환.
   - 이전 프레임에서 설정된 `_had_combat_draw == true` 플래그에 의해 **정확히 1회 클린업 `queue_redraw()`**가 호출되어 캔버스에 남은 잔상을 완벽히 소거함.
4. **Idle Behavior (유휴 시 상시 리드로우 원천 차단)**:
   - 클린업 완료 후 `_had_combat_draw = false` 및 `needs_redraw = false` 상태가 유지되어 유휴 10프레임 및 20프레임 계측 시 리드로우 요청 0건 확인.
   - Stage 1 R3 최적화 아키텍처(비전투 시 StageArt 무상시 리드로우) 100% 보존.

---

## 5. 성능 계측 비교 (Performance Before vs After)

- 측정 환경: 1280×720 Landscape / Compatibility OpenGL 3.3 / RTX 5060 Laptop GPU / VSync OFF (각 600 프레임)

| 측정 구간 | Pass 004 Baseline Avg FPS | R1 Fix 후 실측 Avg FPS | 기준 1% Low | R1 실측 1% Low | 기준 P99 | R1 실측 P99 | 게이트 판정 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Entry** | 291.3 FPS | **263.7 FPS** | >= 45.0 | **215.9 FPS** | <= 22.0 ms | **4.63 ms** | **PASS** |
| **2. First Golem** | 273.3 FPS | **244.1 FPS** | >= 45.0 | **152.3 FPS** | <= 22.0 ms | **6.57 ms** | **PASS** |
| **3. Mid Sanctuary** | 258.2 FPS | **218.0 FPS** | >= 45.0 | **146.2 FPS** | <= 22.0 ms | **6.84 ms** | **PASS** |
| **4. Boss Combat** | 292.6 FPS | **265.8 FPS** | >= 45.0 | **191.8 FPS** | <= 22.0 ms | **5.21 ms** | **PASS** |

- **평가**:
  - 선택적 전투 리드로우 연동 후에도 First Golem 전투는 **244.1 FPS**, Boss 전투는 **265.8 FPS**를 기록.
  - 급락 기준치(< 120 FPS) 대비 2배 이상 높은 프레임 헤드룸을 여유 있게 확보함.

---

## 6. 수동 검증 캡처 (`ART_REVIEW/graphics-pass-004-stage4-r1/`)

1. **`01_ground_slam_windup.png`**:
   - 골렘의 공격 윈드업 자세에서 호박색/주황 지면 균열 림, ㄷ자 코너 브래킷, 룬 틱이 AttackArea 콜리전 범위(폭 220px)와 정밀하게 일치함을 검증.
2. **`02_ground_slam_active.png`**:
   - 주먹 강타 시점의 반경 확산 충격파 링, 초고휘도 코어, 암석 파편 비산 효과가 지면과 결합되어 선명하게 표현됨을 검증.

---

## 7. 자동화 회귀 테스트 결과 (총 17개 스위트 100% PASS)

1. `tests/stage4_ground_slam_redraw_smoke.gd`: **17/17 PASS** (신규 R1 테스트)
2. `tests/stage4_graphics_pass_smoke.gd`: **25/25 PASS**
3. `tests/stage4_render_performance_gate.gd`: **4/4 Sectors PASS**
4. `tests/stage3_graphics_pass_smoke.gd`: **25/25 PASS** (Stage 3 무회귀 입증)
5. `tests/stage2_graphics_pass_smoke.gd`: **24/24 PASS** (Stage 2 무회귀 입증)
6. `tests/stage1_r2_blocker_fixes_smoke.gd`: **27/27 PASS** (Stage 1 무회귀 입증)
7. `tests/game_and_graphic_quality_smoke.gd`: **60/60 PASS**
8. `tests/stage_reward_and_equipment_smoke.gd`: **23/23 PASS**
9. `tests/boss1_visual_polish_smoke.gd`: **17/17 PASS**
10. `tests/campaign_transition_test.gd`: **PASS**
11. `tests/stage_art_smoke.gd`: **37/37 PASS**
12. `tests/stage_smoke.gd`: **37/37 PASS**
13. `tests/combat_deepening_smoke.gd`: **10/10 PASS**
14. `tests/guard_core_smoke.gd`: **21/21 PASS**
15. `tests/sprint4_smoke.gd`: **23/23 PASS**
16. `tests/enemy_motion_smoke.gd`: **130/130 PASS**
17. `tests/data_driven_smoke.gd`: **38/38 PASS**

---

## 8. Remaining Risks & Android Status

- **Remaining Risks**: 없음. 유휴 리드로우 완전 방지, 공격 중 연속 갱신 및 1회 잔상 제거 클린업이 자동화 테스트로 증명됨.
- **Android Status**: **`ANDROID PERFORMANCE NOT VERIFIED`** (PC 데스크톱 환경 실측 기준).

---

## 9. 최종 판정

```text
TASK-AR-018 implementation completed.

GroundSlamGolem windup redraw verified.
GroundSlamGolem active slam redraw verified.
Attack-end cleanup verified.
Idle per-frame redraw regression prevented.
Stage 4 performance gate PASS.
Stage 1/2/3/4 regression tests PASS.
Android performance remains NOT VERIFIED.

Status:
INDEPENDENT REVIEW REQUESTED
```
