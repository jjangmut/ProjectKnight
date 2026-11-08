# V3-003 Final Real Input-Path Verification — Result and Limitations

**Task ID:** `V3-003` (In-place Final Real Input Path Verification)  
**Branch:** `studio/v3-003-stage1-p1`  
**Base Commit:** `48b9861docs(state): scope final V3-003 validation strictly to real GUI and touch input routing`  
**Execution Environment:** Windows 11, Godot 4.7.2 Console (`Godot_v4.7.2-stable_win64_console.exe`), OpenGL Compatibility (1280x720 windowed)  
**Historical Queue Record:** Preserved as APPROVED iteration 1 (`5e785316...`). In-place verification addendum applied under `REOPEN_NOT_SUPPORTED`.

---

## 1. Summary of Verified Gates

### Gate A: Real Viewport GUI Click & Zero-Cheat E2E Playthrough
- **Real GUI Click**: `btn_new_game` located at global center `(971.5, 216.0)`. Driven via genuine `InputEventMouseButton` (press & release) dispatched into Godot's engine input pipeline via `Input.parse_input_event()` and `Input.flush_buffered_events()`.
- **Signal Observation**: Observation callback attached to `btn_new_game.pressed`. Count asserted: exactly **1** (pre-click: 0, post-click: 1).
- **Prohibited Cheats Eliminated & Verified**:
  - `btn.pressed.emit()`: **ELIMINATED**.
  - `_on_new_game_pressed()` direct invocation: **ELIMINATED**.
  - `player.facing_dir_x = 1.0 / -1.0` direct mutation: **ELIMINATED**. Facing direction changes exclusively through natural `move_left` / `move_right` inputs and observed.
  - `receive_hit()` / HP mutation / actor teleportation: **ZERO DETECTED**.
  - Automated self-audit in `_verify_source_integrity()`: **PASS**.
- **Stage 1 Combat & Progression**:
  - Wave 1 Minions 1 & 2: defeated naturally through input movement & attacks.
  - Boss Commander: spawned naturally at HP 24/24.
  - Boss Defeat: HP recorded dropping `24 -> 22 -> 20 -> 16 -> 14 -> 12 -> 6 -> 3 -> 0`.
  - `boss_defeated` signal observation callback count: exactly **1**.
  - `stage_cleared` signal observation callback count: exactly **1**.
  - Stage 2 Transition: naturally loaded `SideQVStage2` ("야수숲 Beastwood Forest Gorge").
  - Test Suite Exit Code: **0**.

### Gate B: Real Mobile Touch Pipeline & Multi-Touch Concurrency
- **Event Dispatching**: All touch inputs dispatched via `InputEventScreenTouch` to Godot engine pipeline (`Input.parse_input_event()` + `Input.flush_buffered_events()`). Direct script calls (`hud._input(ev)`) strictly eliminated.
- **Action Buttons Verified**:
  - Strike (`btn_attack` center `(1080.0, 570.0)`): **PASS** (triggers State.ATTACK & attack action).
  - Leap (`btn_jump` center `(1010.0, 480.0)`): **PASS** (triggers jump action & airborne velocity).
  - Parry (`btn_guard` center `(925.5, 520.0)`): **PASS** (triggers State.GUARD & barrier visual).
  - Dash (`btn_dash` center `(932.0, 600.0)`): **PASS** (triggers State.DASH & dash action).
- **Multi-Touch Concurrency & Dual Release Orders**:
  - Index 0 Joystick Right + Index 1 Strike: **PASS**. Released 0 then 1 without stuck inputs.
  - Index 0 Joystick Right + Index 1 Leap: **PASS**. Released 1 then 0 without stuck inputs.
- **Release Safety**: All 8 actions checked post-release. Stuck count: exactly **0**.
- **Test Suite Exit Code**: **0**.

### Gate C: Input Ownership & Strict Boundary Limitations
- **Simulated Hardware Ownership**:
  - Simulated keyboard key down for `KEY_A` (`move_left`). Verified `Input.is_action_pressed("move_left") == true`.
  - Virtual joystick touch index 0 dragged left, then released.
  - Immediate assertion post-touch release: `Input.is_action_pressed("move_left") == true` (confirmed touch release did not extinguish keyboard action).
  - Keyboard key up dispatched. Verified `Input.is_action_pressed("move_left") == false`.
  - Assertion result: **PASS**.
- **Strict Limitation Disclosures**:
  - Keyboard Ownership Scope: **`SIMULATED_KEY_ROUTE_ONLY`** (injected through engine event parser; physical keypress state on physical device not simulated).
  - Physical Hardware Ownership: **`PHYSICAL_HARDWARE_NOT_VERIFIED`**.
  - Android Hardware Status: **`NOT_TESTED`** (verified in Windows 1280x720 desktop environment).
  - Commercial Release Status: **`NOT_APPROVED`** (stage 1 input slice acceptance gate only).

---

## 2. Test Execution & OS Shell Evidence

| Suite | Command | Exit Code | Raw Log |
|---|---|:---:|---|
| Touch UI | `Godot ... -s res://tests/v3_003_real_touch_ui.gd` | 0 | `TOUCH_EVENT_ROUTE_LOG.txt` |
| Boss Windup | `Godot ... -s res://tests/v3_003_boss_charge_timing.gd` | 0 | `BOSS_WINDUP_TIMELINE.csv` |
| Real Input E2E | `Godot ... -s res://tests/v3_003_real_input_e2e.gd` | 0 | `ACTUAL_GUI_INPUT_E2E_LOG.txt` |

Full verbatim OS shell transcript containing absolute command lines, stdout, stderr, and exit codes is stored in:
`STUDIO_V3/evidence/V3-003/final-input/SHELL_COMMANDS_STDOUT_STDERR_EXIT.txt`

---

## 3. Synchronized Render Captures

All 6 screenshots were captured using `await RenderingServer.frame_post_draw` to ensure complete frame rendering. Recorded in `CAPTURE_MANIFEST.json`:

1. `01_title_deploy_click.png` (158 KB) - TitleScreen Deploy button highlighted at center (971.5, 216.0).
2. `02_stage1_natural_entry.png` (1.30 MB) - SideQVCampaign loaded Stage 1 Citadel Terrace Gate; player visible at X=-7.50.
3. `03_minions_natural_combat.png` (1.30 MB) - Player in active melee combat against Citadel minions.
4. `04_boss_spawn_full_sightline.png` (1.26 MB) - Boss Commander spawned with full sightline at X=11.50, HP 24/24.
5. `05_boss_combat_parry_strike.png` (1.29 MB) - Boss defeated at HP 0, parry stun impact VFX.
6. `06_stage1_clear_stage2_transition.png` (1.39 MB) - Stage 1 cleared, campaign loaded Stage 2 Beastwood Gorge.

---

## 4. Conclusion

All findings from `STUDIO_V3/reviews/V3-003-RETEST-EXTERNAL-INDEPENDENT-REVIEW.md` (Blocking P1-A, P1-B, P1-C) have been resolved with genuine Godot input routing, verified signal counts, zero cheats, and honest boundary disclosures.
