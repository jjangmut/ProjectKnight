# ProjectKnight V3-025 — Independent QA Verification Report

- **Task ID**: `V3-025` — Stage 1 Combat Readability, Encounter Identity & Human Playtest Readiness
- **Branch**: `studio/v3-025-stage1-combat-readability-pacing`
- **Worktree**: `D:/JUNYPAPA_STUDIO/Worktrees/ProjectKnight/V3-025`
- **Reviewer**: `PK_QALead` (Independent QA Lead)
- **Audit Date**: `2026-11-15`
- **QA Verdict**: **`QA PASS`** (Split Gate Honors Maintained; 0 P0 / 0 P1 / 1 P2 Logged)

---

## 1. Executive Summary & Split Gate Audit

The QA Lead conducted an independent, evidence-backed verification of milestone **V3-025** across GDScript source implementations, raw JSON telemetry logs, video media streams, and rendered 1280×720 visual captures. 

In strict adherence to `AGENTS.md` (Rule 1 "Implementation != Approval", Rule 4 "Independent Review", Rule 5 "Evidence Required") and `V3-025.md` Section 5 ("Honesty: Split Gates"), this QA review enforces split gate accountability:

| Split Gate | Status | Evidence & Verification Notes |
| :--- | :---: | :--- |
| **Technical Regression Gate** | **`TECHNICAL_PASS`** | 100% pass across all 5 prior regression suites (V3-022 mechanics, V3-024 corner escape, lane alignment, defeat retry, sprite bounding). |
| **Visual Readability Gate** | **`VISUAL_PASS`** | Oversized flat red rectangular carpet hazard completely eliminated. Shape-accurate textured telegraphs with 3 distinguishable phases (`TELL`, `ACTIVE`, `RECOVERY`) verified across all 4 enemy roles. |
| **Gameplay Automation Gate** | **`GAMEPLAY_AUTOMATION_PASS`** | 100% honest natural-input E2E clear in 38.22s (2,293 frames @ 60 FPS, 12 normal enemies + boss, zero state writes/cheats). Mindless forward spam heavily punished in Encounter 3. |
| **Human Playtest Gate** | **`HUMAN_PLAYTEST_NOT_TESTED`** | **Pending real operator.** Zero fabricated surveys or fake fun scores. Production launch flow, in-game control guide (`[TAB]`/`[H]`), tactical pause menu (`[ESC]`), non-invasive telemetry HUD (`[F1]`), and 2-attempt checklist published in `HUMAN_PLAYTEST_GUIDE.md`. |

---

## 2. Three-Layer QA Audit

### 2.1 Functional QA (Mechanics, State Machine, Progression)
- **Natural Stage 1 Completion**: Verified in `NATURAL_E2E_RESULT.json` and reproduced live via `v3_021_r1_stage1_natural_e2e.gd`.
  - Mode: `NATURAL_INPUT_E2E` (Simulated standard Input events: `move_left`, `move_right`, `move_up`, `move_down`, `jump`, `attack`, `guard`, `dash`).
  - Total normal enemies defeated: **12 / 12** (Encounter 1: 3 Melee Grunts; Encounter 2: 2 Crossbowmen + 2 Grunts; Encounter 3: 2 Heavy Shield Knights + 2 Grunts + 1 Crossbowman).
  - Boss Commander defeated naturally; victory fanfare triggered at 38.22s.
- **Zero-Cheat Integrity**:
  - `direct_state_mutations: 0`
  - `player_hp_writes: 0`
  - `boss_hp_writes: 0`
  - `coordinate_teleports: 0`
  - `zero_cheats_audit_passed: true`
- **Instrumentation Correction (Parry Overcounting Fix)**:
  - Audited previous V3-024-R4 anomaly where 53 parries were reported in 35.63s due to counting every `guard` keypress.
  - Fix verified: `guard_inputs_attempted` (33) separated from true `confirmed_parries_deflected` (8) tied directly to the `just_parry_succeeded` signal.

### 2.2 Visual QA (Readability, Telegraphs, Dual Camera Tracking)
- **Elimination of Red Rectangular Hazard**:
  - Baseline defect reproduced in `BASELINE_VISUAL_DEFECTS.md` and traced to `Zone3_RoyalCrimsonCarpet` ($23.0\text{m} \times 2.8\text{m}$ untextured solid red plane with neon emissive yellow borders) in `side_qv_stage_1.gd`.
  - Overhaul verified: Replaced with textured Citadel flagstone tapestry (`TexFlagstone`), muted wine tint (`Color(0.42, 0.22, 0.26, 0.88)`), and non-emissive architectural stone curbs (`Color(0.60, 0.52, 0.42, 0.85)`). Zero hazard confusion remaining.
- **Shape-Accurate Textured Telegraphs (3 Distinguishable Phases)**:
  - **Melee Grunt**: Directional sweeping floor arc (`TexSlashArcAmber`, $1.35\text{m} \times 0.85\text{m}$) during 0.28s `TELL` $\to$ crescent blade slash VFX (`TexEnemySlashCrescent`, 0.14s `ACTIVE`) $\to$ 0.22s vulnerable `RECOVERY` opening.
  - **Crossbow Minion**: 2-stage dynamic ground laser. 0.28s `TELL_TRACKING` (amber dotted beam tracking player $(X, Z)$ coordinate) $\to$ 0.14s `TELL_LOCKED` (frozen crimson beam + muzzle flare) $\to$ physical tracer bolt along exact locked vector $\to$ 0.28s `RECOVERY` recock.
  - **Heavy Shield Knight**: Directional runic runway strip (`TexEnergyBarrierRunic`, $1.85\text{m} \times 0.95\text{m}$) during 0.35s `TELL` $\to$ forward concussive surge ($3.2\text{m/s}$, 0.18s `ACTIVE`) $\to$ 0.42s vulnerable lowered-guard `RECOVERY`.
  - **Boss Commander**: $9.5\text{m} \times 1.35\text{m}$ runic runway lane (`Shield Line Charge`) + $2.4\text{m} \times 1.3\text{m}$ sweeping cleave arc (`Triple Cleave`).
- **Dual Camera Tracking & Framing**:
  - Verified across 725 boss fight frames: Both player and boss maintained on-screen ($100.0\%$, 0 off-screen frames).
  - Bounding box and silhouette visibility verified at 100% in `v3_024_r4_sprite_bounding_verification.gd` with min horizontal clearance of $2.09\text{m}$.

### 2.3 Play QA & Combat Pacing Benchmarks
- **6 Pacing Policies Evaluated (Identical Seeds)**:
  Evaluated in `PACING_POLICY_COMPARISON.json` and reproduced live via `v3_025_pacing_policy_verification.gd`:
  1. `stationary_attack_only`: **FAILED (Died)** at sim_t=8.53s, 9 HP damage taken.
  2. `forward_attack_spam`: **FAILED (Died)** at sim_t=21.83s~32.26s, 14~15 HP damage taken. Heavy frontal deflection by Heavy Shield Knights in Encounter 3 completely blocks forward spam.
  3. `xz_move_attack_no_defense`: **FAILED (Died)** at sim_t=11.07s, 9 HP damage taken.
  4. `tactical_counterplay`: **PASSED (Cleared)** at sim_t=27.36s~29.75s, 3~6 HP damage taken.
  5. `tactical_latency_250ms`: **PASSED (Cleared)** at sim_t=30.65s~32.90s, 6~10 HP damage taken.
  6. `tactical_latency_450ms`: **PASSED (Cleared)** at sim_t=25.28s~32.98s, 9~10 HP damage taken.
- **Fair Human Reaction Gap**: Adding 250ms and 450ms delays demonstrated a realistic increase in damage taken and pattern cycles without causing unavoidable traps or softlocks.
- **Distinct Counterplay Decisions**:
  - Encounter 1: Spacing outside arc tell $\to$ whiff punishing during recovery.
  - Encounter 2: Sidestepping along Z depth during crimson lock OR timing a Just Parry reflection.
  - Encounter 3: Frontal strikes deflect $\to$ Z-depth flanking ($|\Delta Z| \ge 0.45\text{m}$) or baiting shield bash for recovery punish.
  - Boss Sanctuary: Z-dodge outside 1.35m charge corridor $\to$ wall stun punish.

---

## 3. Media Provenance & Checksum Audit

All three deliverable videos in `D:/JUNYPAPA_STUDIO/Videos/ProjectKnight/V3-025/` were inspected via `ffprobe` and validated against `VIDEO_PROVENANCE.json`:

| File | Resolution | FPS | Duration | File Size | SHA256 Verified |
| :--- | :---: | :---: | :---: | :---: | :---: |
| `Stage1_CombatReadability_1x.mp4` | 1280×720 | 60 | 38.22s (2,293 frames) | 85,973,961 B | `11D641F41E93C6B359F3AD1C7B0F817A2173D74D34E8470A8CCDC26AA873AC5D` (PASS) |
| `VFX_Telegraph_Readability_1x.mp4` | 1280×720 | 60 | 9.35s (561 frames) | 9,029,539 B | `8B1F285DCA787116C5E57E59EEAB8C7EE20BBC36E3AD0F2CF9EDB32B029CD576` (PASS) |
| `Enemy_Role_Counterplay_1x.mp4` | 1280×720 | 60 | 8.68s (521 frames) | 13,935,036 B | `D0F824EE492AAEFB4A9F4C672EBA87C4A4C28A08272C710F478B84C4D8AD2F02` (PASS) |

---

## 4. Technical Regression Suite Audit

All 5 prior milestone regression suites were executed independently in Godot 4.7.2 stable:

1. `v3_022_r1_mechanics_verification.gd` (Pillar collisions, projectile sweep/reflect, vertical stability): **PASS**
2. `v3_024_r2_corner_escape_verification.gd` (4-corner escape, 2 depth rails, dash phase, guard walk): **PASS** (204/204 movement frames, 0 stuck frames)
3. `v3_024_r3_lane_alignment_verification.gd` (Same-lane combat, foot-Y diff 0.0px, Z-dodge evasion): **PASS** (100% alignment rate)
4. `v3_024_r4_defeat_retry_verification.gd` (Player defeat overlay, retry button, clean stage reload): **PASS**
5. `v3_024_r4_sprite_bounding_verification.gd` (Dual camera tracking, silhouette visibility): **PASS** (100% visibility, 0 critical overlaps)

---

## 5. QA Issue Ledger

### Defect V3-025-QA-01 (P2 - Minor Test Harness Discrepancy)
- **File**: `CLIENT/Game/tests/quality_gate/v3_025_telegraph_frame_verification.gd` lines 256–258
- **Severity**: **P2 (Minor / Polish Backlog)** — Does NOT block milestone progression.
- **Observed Behavior**: In `_test_shield_knight_bash()`, the test spawns a `SideQVEliteKnight` facing left (`face_x = -1.0`), leaves `knight.target_player` unassigned (`null`), and calls `knight.receive_hit(2, Vector3.LEFT, false)`. Because `incoming_x = -1.0` and `face_x = -1.0`, `incoming_x * face_x = +1.0` (which is not `< -0.1`), the test's hit is treated as a rear strike rather than a frontal strike. As a result, the knight takes damage instead of deflecting, triggering `SCRIPT ERROR: Assertion failed: Frontal guard must block head-on strikes at line 258`.
- **In-Game Behavior Verification**: In actual stage gameplay (`side_qv_stage_1.gd` line 699), `knight.target_player = player` is properly bound, and player attack pushes (`Vector3.RIGHT` for a left-to-right attack) correctly trigger `is_frontal_hit = true` and shield deflection. This is visually confirmed in `Enemy_Role_Counterplay_1x.mp4` and validated in the `forward_attack_spam` benchmark (where the player dies in Encounter 3 due to frontal blocks).
- **Recommendation for Client Lead**: In `v3_025_telegraph_frame_verification.gd:256`, set `knight.target_player = current_player` or pass `Vector3.RIGHT` for the frontal attack simulation so the isolated test harness assertion cleanly passes without GDScript script errors.

---

## 6. QA Verdict & Routing

- **Milestone Determination**: **`QA PASS`**
- **Justification**:
  1. All P0 deliverables (red rectangle elimination, shape-accurate textured telegraphs, 3-phase attack cues, distinct enemy counterplay, human-playable local test flow) are fully verified with reproducible evidence.
  2. All P1 combat pacing requirements (6 policies evaluated, forward spam punished, human reaction delay modeled, parry instrumentation corrected) are fully satisfied.
  3. All 5 prior milestone technical regressions passed 100%.
  4. Split gate honesty is strictly maintained (`HUMAN_PLAYTEST_NOT_TESTED` honestly declared).
  5. Only one minor P2 test harness discrepancy logged, with zero gameplay impact.
- **Routing**: Routed to **PK_Producer** to coordinate task closure and forward to **PK_GameDirector** for final commercial milestone approval.
