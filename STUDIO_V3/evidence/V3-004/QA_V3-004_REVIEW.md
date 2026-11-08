# QA Review Report: V3-004 Stage 2 Beastwood Forest Gorge

**Document ID:** `QA_V3-004_REVIEW.md`  
**Task ID:** `V3-004`  
**Milestone:** Stage 2 Beastwood Forest Gorge Real Play & Option C Plane Alignment  
**Target Branch:** `studio/v3-004-stage2-beastwood`  
**Reviewed Frozen Commit SHA:** `b36e0da38c4abf8fd82fdb5aaf6c03f4da5ac943`  
**Reviewer:** `PK_QALead` (Independent QA Lead)  
**Date:** 2026-11-08  
**Execution Environment:** Godot Engine v4.7.2.stable.official.ed1daf0bf / GL Compatibility / Windows 11 64-bit (1280×720 Landscape)  
**QA Verdict:** **QA PASS**

---

## 1. Executive Summary

As the independent QA Lead of ProjectKnight Studio V3, I conducted a complete, evidence-based audit across all three required QA layers (**Functional QA**, **Visual QA**, and **Play QA**) for milestone task `V3-004` on branch `studio/v3-004-stage2-beastwood` at frozen commit SHA `b36e0da38c4abf8fd82fdb5aaf6c03f4da5ac943`.

The audit verified that the previously identified high-risk Stage 2 defects—specifically off-plane minion spawns (`Z=±1.6`), 3D chase/velocity vectors (`velocity.z != 0`), 3D boss leap trajectories, unverified boss HP (28), and missing natural Phase 2 transitions—have been completely and rigorously resolved under **Option C: strict 2D gameplay plane lock at $Z = 0.0$**.

All tests were executed directly inside the Godot 4.7.2 engine runtime using genuine engine-parsed inputs with **zero cheats, zero direct position or HP mutations, zero direct signal emissions, and zero artificial shortcuts**. The continuous journey from **Title Screen $\rightarrow$ Stage 1 Clear $\rightarrow$ Stage 2 Natural Entry $\rightarrow$ 2 Beast Minion Kills $\rightarrow$ Beast Chieftain Boss Phases 1 & 2 $\rightarrow$ Natural Boss Defeat $\rightarrow$ Stage 2 Clear Signal $\rightarrow$ Stage 3 Transition** has been demonstrated with live test passes, complete telemetry logs, and 10 synchronized viewport captures.

---

## 2. Layer 1: Functional QA Audit

### 2.1 Option C Plane Lock ($Z = 0.0000$)
- **Player Character:** Initialized at $Z = 0.0000$, velocity $v_z = 0.0000$. Throughout movement, jump, attack combos, parry guard, and dash, $|z| \le 0.0000$ and $|v_z| \le 0.0000$ maintained across all frames.
- **Wave 1 Beast Minions (`SideQVBeastMinion` 1 & 2):**
  - Minion 1 spawned at $(4.5, 0.1, 0.0000)$; Minion 2 spawned at $(8.0, 0.1, 0.0000)$.
  - Across idle, chase, telegraph windup, charging, recovery, and stun states, telemetry in `Z_ACTOR_PRESENCE.csv` confirms $z = 0.0000$ and $v_z = 0.0000$ at every sample tick.
  - Chase logic uses purely 1D horizontal direction ($dir\_x = \text{signf}(diff\_x)$).
- **Wave 2 Beast Chieftain (`SideQVBeastChieftain`):**
  - Spawned at $(12.0, 0.1, 0.0000)$ with initial HP $28/28$.
  - Pounce Leap executed as a strict 2D parabolic arc ($v_y = 7.2\text{ m/s}$, $v_x = \text{facing\_dir} \times 9.0\text{ m/s}$, $v_z = 0.0000\text{ m/s}$).
  - Live execution of `v3_004_stage2_plane_and_combat.gd` confirmed: `Max airborne |vz|: 0.0000`.
- **Verdict:** **PASS (P0 Blockers: 0)**

### 2.2 Wave 1: Feral Beast Minions Natural Combat
- **Spawn & Attributes:** Two instances spawned cleanly; Max HP = 5 each.
- **Telegraph Fairness:** Minion charges feature a 0.32s crouch windup accompanied by high-energy orange warning flash (`modulate = Color(2.5, 0.6, 0.3)`). Hazard hitbox monitoring is explicitly disabled during windup.
- **Combat Resolution:** Both minions were defeated naturally through player attack combos and parry stun cancellations at $t = 12.937\text{s}$.
- **Hit Protection:** `has_hit_in_current_charge` prevents double-damage anomalies.
- **Verdict:** **PASS**

### 2.3 Wave 2: Beast Chieftain Boss Mechanics & Initial HP 28
- **Initial State:** Boss spawned with exactly $HP = 28/28$, Max Poise = 14.
- **Pattern 1 (Pounce Leap):**
  - Ground warning torus ring + popup `!` precedes leap by 0.35s.
  - Airborne leap trajectory is purely vertical and horizontal ($X/Y$).
  - Expanding emerald shockwave ($r = 3.6\text{ m}$) deals 2 HP on landing with single-hit protection.
- **Pattern 2 (Triple Claw Strike):**
  - 3 sequential forward slashes (Row 2 Frames 8 and 9) with distinct windup, active hitbox, and recovery phases.
  - Each slash parryable; parry inflicts 4 poise damage toward groggy break.
- **Pattern 3 (Enraged Roar & Phase 2 Transition):**
  - Triggered naturally when boss HP reached 12 ($\le 14$, 50% HP threshold).
  - Emitted `phase_changed(2)` and `boss_phase_changed(2)` signals.
  - Activated visible glowing emerald aura ring and 5.2m roar shockwave.
  - Enhanced move speed (5.6 m/s) and leap speed (11.5 m/s) verified.
- **Groggy & Shatter Break:**
  - Depleting poise to 0 triggered Groggy state with rotating overhead halo and bonus `SHATTER +1` damage.
- **Verdict:** **PASS**

### 2.4 Boss Defeat, Stage Clear Signal & Campaign Stage 3 Transition
- **Natural Defeat:** Boss HP reduced naturally from 28 to 0 at $t = 19.721\text{s}$. `boss_defeated` signal received with callback count == 1.
- **Stage Clear Signal:** Exactly one `stage_cleared` signal received at $t = 21.720\text{s}$ (count == 1).
- **Campaign Transition:** Campaign marked `cleared_stages[1] = true` and seamlessly loaded `SideQVStage3` (`OP-03: 무너진 성벽`, `current_stage_index = 2`).
- **Verdict:** **PASS**

---

## 3. Layer 2: Visual QA Audit

### 3.1 Foot Grounding & 3D Contact Shadows
- Directional sunlight/moonlight at rotation $(-48.0^\circ, -25.0^\circ, 0.0^\circ)$ casts sharp real-time 3D contact shadows onto the textured forest floor CSG box.
- Both 2D character sprites (hero paladin, beast minion, and 2.5m beast chieftain) render with `cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON`.
- Inspected in captures `04_stage2_natural_entry.png`, `05_stage2_beast_minions_combat.png`, `06_stage2_boss_spawn_full_sightline.png`, and `07_stage2_boss_pounce_leap.png`: no floating or detached sprite visual anomalies observed.

### 3.2 2D/3D Integration & Contrast
- 2D billboard sprites (`BILLBOARD_FIXED_Y`, `ALPHA_CUT_DISCARD`) blend harmoniously with 3D CSG geometry and PBR materials.
- Paladin knight silver-blue armor and Chieftain golden fur exhibit high visual contrast against dark green forest terrain and foliage.
- Emissive yellow-green firefly particles (56 count) and glowing runic totems add vibrant life without creating visual noise or obscuring characters.

### 3.3 Foreground Occlusion (0% Combat Plane Occlusion)
- All 5 ancient tree trunks are positioned deep in the background at $Z = -5.8\text{ m}$ to $-6.0\text{ m}$.
- Beast totems are placed at $Z = -3.2\text{ m}$.
- Boundary logs are set at $Z = \pm 5.8\text{ m}$.
- Across all 1280×720 captures, **foreground occlusion on the gameplay plane ($Z = 0.0$) is strictly 0.0%**. The sightline between player and enemies is completely clear across the entire 40-meter arena.

### 3.4 Ten Synchronized Viewport Captures Audit

| # | Capture ID | Timestamp | Verified Subject & Visual Quality |
|---|---|:---:|---|
| 01 | `01_title_deploy_click.png` | 0.417s | Title Screen GUI, crisp Deploy button press state. |
| 02 | `02_stage1_entry.png` | 0.583s | Stage 1 Citadel Gate baseline environment & grounding. |
| 03 | `03_stage1_boss_defeat.png` | 6.612s | Stage 1 Boss defeat & trauma screen shake feedback. |
| 04 | `04_stage2_natural_entry.png` | 10.428s | Stage 2 Beastwood Gorge entry, emerald fog & tree backdrop. |
| 05 | `05_stage2_beast_minions_combat.png` | 10.595s | Wave 1 combat against feral beast minions on terrain plane. |
| 06 | `06_stage2_boss_spawn_full_sightline.png` | 14.154s | Beast Chieftain boss spawn, full sightline, HP bar at top. |
| 07 | `07_stage2_boss_pounce_leap.png` | 14.287s | Boss Pounce Leap telegraph arc & airborne launch. |
| 08 | `08_stage2_boss_phase2_roar.png` | 18.964s | Phase 2 Enraged Roar shockwave & glowing aura ring. |
| 09 | `09_stage2_boss_natural_defeat.png` | 19.721s | Boss natural defeat, "STAGE CLEARED!" banner & soul shards. |
| 10 | `10_stage2_clear_stage3_transition.png` | 23.653s | Stage 3 Crossbow Bastion transition (`OP-03`). |

All 10 images are confirmed present on disk at `STUDIO_V3/evidence/V3-004/captures/` with valid 1280×720 resolution and metadata recorded in `CAPTURE_MANIFEST.json`.
- **Verdict:** **PASS**

---

## 4. Layer 3: Play QA Audit

### 4.1 Pacing & Encounter Rhythm
- **Stage 2 Flow:** Total traversal and combat duration was $\approx 13.2\text{ seconds}$ within the continuous 23.7s full run.
- **Wave 1:** 2 minions provide immediate high-energy engagement without overwhelming the player.
- **Wave Transition:** Natural advance rightward past $X \ge 6.5$ triggers boss entry cleanly.
- **Wave 2:** Boss pacing divides evenly into disciplined Phase 1 (HP 28 $\rightarrow$ 14) and frantic Phase 2 Enrage (HP 14 $\rightarrow$ 0). No dead time or stalling observed.

### 4.2 Telegraph Fairness & Counterplay
- Every high-damage enemy action gives readable visual telegraphs:
  - Beast Minion: 0.32s crouch + orange flash $\rightarrow$ Parry Stun window is intuitive.
  - Chieftain Pounce Leap: 0.35s ground torus ring + popup `!` $\rightarrow$ clear signal to parry or dash.
  - Chieftain Phase 2 Roar: 5.2m shockwave ring + screen banner $\rightarrow$ distinct phase shift cue.
- No unfair proximity damage or instantaneous off-screen attacks occurred.

### 4.3 Zero Cheats & Anti-Shortcut Source Audit
- `CLIENT/Game/tests/v3_004_stage2_real_input_e2e.gd` contains an internal self-audit function `_verify_source_integrity()` that scans the test script source code for disallowed shortcuts.
- Independent QA verification confirmed:
  - `pressed.emit()`: **ZERO** occurrences in test code.
  - `_on_new_game_pressed()`: **ZERO** direct calls.
  - `player.facing_dir_x = ...`: **ZERO** direct mutations.
  - `receive_hit(...)`: **ZERO** direct damage injections.
  - `current_hp = ...`: **ZERO** direct mutations during playthrough.
  - `stage_cleared.emit(...)`: **ZERO** fake signal calls.
  - `boss_defeated.emit(...)`: **ZERO** fake signal calls.
  - `enemy_defeated.emit(...)`: **ZERO** fake signal calls.
- **Verdict:** **PASS**

---

## 5. Regression Suite Execution

Independent QA re-ran the entire regression suite in the live Godot 4.7.2 environment:

1. **Stage 2 Option C Plane & Combat Fixture (`v3_004_stage2_plane_and_combat.gd`):**
   - Command: `Godot_v4.7.2-stable_win64_console.exe --path CLIENT/Game -s res://tests/v3_004_stage2_plane_and_combat.gd`
   - Exit Code: **0** (All checks passed)
2. **Stage 1 Mobile Touch Event Routing & Ownership (`v3_003_real_touch_ui.gd`):**
   - Command: `Godot_v4.7.2-stable_win64_console.exe --path CLIENT/Game -s res://tests/v3_003_real_touch_ui.gd`
   - Exit Code: **0** (All checks passed; multi-touch release safety and keyboard ownership confirmed)
3. **Stage 1 Boss Charge Timing & Telegraph Fixture (`v3_003_boss_charge_timing.gd`):**
   - Command: `Godot_v4.7.2-stable_win64_console.exe --path CLIENT/Game -s res://tests/v3_003_boss_charge_timing.gd`
   - Exit Code: **0** (All checks passed; measured windup 0.4333s $\ge$ 0.42s requirement)
4. **Stage 2 Continuous Real-Input E2E (`v3_004_stage2_real_input_e2e.gd`):**
   - Command: `Godot_v4.7.2-stable_win64_console.exe --path CLIENT/Game -s res://tests/v3_004_stage2_real_input_e2e.gd`
   - Exit Code: **0** (All checks passed; continuous Title $\rightarrow$ Stage 3 completed in 23.670s)

---

## 6. QA Traceability & Acceptance Matrix

| Requirement Item | Acceptance Criteria | Measured Verification Evidence | Status |
|---|---|---|:---:|
| **Option C Plane Lock** | All actors at $Z=0.0000$, $v_z=0.0000$ | `Z_ACTOR_PRESENCE.csv`: $|z| \le 0.0000, |v_z| \le 0.0000$ across all ticks | **PASS** |
| **Wave 1 Minion Combat** | 2 natural beast defeats via input | 2 real kills confirmed at $t=12.937\text{s}$ | **PASS** |
| **Boss Initial HP** | Exactly 28/28 at spawn | Observed $HP=28/28$ at $t=14.154\text{s}$ | **PASS** |
| **Boss Pounce Leap** | 2D parabolic leap with 0.35s telegraph | Airborne max $|v_z| = 0.0000\text{ m/s}$, capture `07` | **PASS** |
| **Boss Triple Claw** | 3-hit forward melee combo | 3 slashes observed at $t=16.389\text{s}$ | **PASS** |
| **Boss Phase 2 Roar** | Triggered at $HP \le 14$ with signals | Fired at $HP=12$, `phase_changed(2)` received | **PASS** |
| **Natural Boss Defeat** | $HP=0$ via attacks/parries | Defeated at $t=19.721\text{s}$, `boss_defeated` count=1 | **PASS** |
| **Stage Clear Signal** | Exactly one `stage_cleared` callback | Callback received at $t=21.720\text{s}$ (count=1) | **PASS** |
| **Campaign Progression** | Natural load of Stage 3 instance | `SideQVStage3` loaded at $t=23.537\text{s}$ | **PASS** |
| **Visual Grounding** | Contact shadows on forest floor | Real-time directional shadows in captures 04-09 | **PASS** |
| **Corridor Occlusion** | 0% occlusion by totems/trees/logs | Corridor $Z=0.0$ 100% unobstructed | **PASS** |
| **Zero Cheats** | No teleport/HP/signal injection | Source self-audit passed, live test passed | **PASS** |

---

## 7. Scope Boundaries & Honest Disclosures

In accordance with Studio V3 governance protocols:
1. **Desktop PC Environment Only:** All tests were conducted in Godot 4.7.2 under Windows 11 with GL Compatibility renderer.
2. **Android Physical Device:** **`NOT_TESTED`**. Mobile touch events were verified via engine-parsed viewport events; physical device certification has not been performed.
3. **Commercial Release:** **`NOT_APPROVED`**. Milestone certification applies strictly to Stage 2 implementation milestone `V3-004`.

---

## 8. Final QA Declaration

The implementation of milestone task `V3-004` on branch `studio/v3-004-stage2-beastwood` at frozen commit SHA `b36e0da38c4abf8fd82fdb5aaf6c03f4da5ac943` has been independently audited and verified with complete reproducible evidence.

There are **0 P0 blockers**, **0 P1 major issues**, and **0 regressions**. All acceptance criteria set forth in `STUDIO_V3/tasks/V3-004.md` have been fulfilled.

**Final Verdict:** **`QA PASS`**  
**Audited Frozen Commit SHA:** `b36e0da38c4abf8fd82fdb5aaf6c03f4da5ac943`  
**Signed:** `PK_QALead` (Independent QA Lead)
