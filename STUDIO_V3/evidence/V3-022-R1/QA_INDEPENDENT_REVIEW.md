# ProjectKnight V3-022-R1 — Independent QA & Game Director Verification Report

- **Task ID**: `V3-022-R1`
- **Branch**: `studio/v3-022-r1-physics-projectiles-pacing`
- **Worktree**: `D:\JUNYPAPA_STUDIO\Worktrees\ProjectKnight\V3-022-R1`
- **Reviewers**: `PK_QALead` (Independent QA Lead) & `PK_GameDirector` (Game Director)
- **Verification Date**: `2026-11-12`
- **Final Verdict**: **`QA PASS` / `APPROVED`**

---

## 1. Executive Summary

We performed an independent, evidence-driven audit of **V3-022-R1** across code changes, raw JSON traces, test execution logs, and Before/After visual captures in `STUDIO_V3/evidence/V3-022-R1/`. All four user-reported P0 defects from the V3-022 Stage 1 recording (`PROJECTILE-P0`, `PILLAR-P0`, `BOSS-AIR-P0`, and `SPEED-P0`) were deterministically reproduced (`PRE_FIX_REPRO_TRACE.json`), root-caused to exact lines of GDScript, fixed with clean architectural discipline, and verified via both isolated physics suites and an uncut 1.0x single-source Stage 1 playtest recording (`Run ID: V3-022-R1-E2E-1794492437`).

---

## 2. P0 Defect Verification Audit

### 2.1 `PROJECTILE-P0` — Ranged Enemy (`SideQVRangedMinion`) Projectile Freezing
- **Code Inspection** (`CLIENT/Game/scripts/side_quarter_view/bosses/side_qv_crossbow_bolt.gd`):
  - **Root Cause Confirmed**: Previously, `_on_body_entered()` set `is_active = false` prior to calling `_impact_and_vanish(true)`, which began with `if not is_active: return`. Every player collision/guard/parry halted `_physics_process` movement while skipping `queue_free()`, leaving orphaned crossbow bolts frozen in mid-air.
  - **Fix Verified**: Premature `is_active = false` assignment removed; `_impact_and_vanish(true)` now atomically deactivates physics, spawns `BoltImpactBurst`, and calls `queue_free()`. Continuous raycast sweep (`PhysicsRayQueryParameters3D`, mask `1 | 4`) prevents tunneling, and `bolt_mesh.rotation_degrees.x = -90.0` + `BoltHeadRing` align the tapered tip forward (`mesh_tip_aligned_with_direction = true`).
- **Trace & Visual Evidence** (`PROJECTILE_TRACE.json`, `captures/compare_projectile_before_after.png`):
  - `max_consecutive_frozen_frames_while_active`: **`0`** (moves `~0.275m` every physics tick at `16.5 m/s`).
  - `vanished_on_player_guard_frame`: **`18`** (`vanished_on_player_guard = true`).
  - `vanished_on_pillar_impact`: **`true`** (vanishes on `GatePillar_2` at frame 8).
  - `vanished_on_csg_world_wall_impact`: **`true`**.
  - `continues_cleanly_when_shooter_dies_midair`: **`true`**.
  - **Status**: **PASS**

### 2.2 `PILLAR-P0` — Stage Pillars & Gothic Wings Physical Collision
- **Code Inspection** (`CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_1.gd`):
  - **Root Cause Confirmed**: `_build_pillar()`, `_build_gothic_wing()`, and `ParapetPost_*` previously created visual-only `CSGBox3D` nodes without `use_collision = true` or `StaticBody3D` colliders.
  - **Fix Verified**: Every `GatePillar_1..3`, `BossPillar_Rear`, `GothicWing_Start/Bastion/Terrace/Boss`, and `ParapetPost_*` now has `use_collision = true` (`collision_layer = 4`) plus an explicit `StaticBody3D` (`PillarCollider`, Layer 4) and `BoxShape3D` matching its stone geometry.
- **Trace & Visual Evidence** (`PILLAR_COLLISION_RESULTS.json`, `captures/compare_pillar_before_after.png`):
  - `all_pillars_and_wings_have_layer4_colliders`: **`true`**.
  - `x_approach_blocked`: **`true`** (walking `+X` at `z = -2.35` into `GatePillar_1` halts cleanly at `x = 16.97` with `slide_collision_count = 1`, whereas pre-fix walked straight through `x = 18.0`).
  - `z_approach_blocked`: **`true`** (walking `-Z` at `x = 18.0` halts cleanly at `z = -1.67`).
  - `dash_into_pillar_blocked`: **`true`**.
  - `corridor_lane_bypass_open`: **`true`** (open playable corridor lane `Z in [-1.67, +3.0]` allows smooth traversal around pillars).
  - **Status**: **PASS**

### 2.3 `BOSS-AIR-P0` — Boss Fight Abnormal Skyward Launch (`Y = 2.97m`)
- **Code Inspection** (`CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd`, `side_qv_boss.gd`):
  - **Root Cause Confirmed**: `_check_melee_hit()` previously called `_execute_pogo_bounce()` (`velocity.y = jump_velocity * 0.96`) on every airborne melee hit regardless of target elevation or directional input, causing horizontal air combos against the tall boss capsule to stack upward impulses to `Y = 2.97m`.
  - **Fix Verified**: Added `has_used_air_pogo` (reset in `_on_landed_on_floor()`) and gated `_execute_pogo_bounce()` behind `not is_on_floor() and not has_used_air_pogo and velocity.y <= 0.2 and any_target_below and Input.is_action_pressed("move_down")` where `any_target_below` requires `global_position.y > target_pos.y + 0.85` and `absf(dx) < 1.15`. Also verified `set_deferred("monitoring", false)` in `side_qv_boss.gd` during parry stun/groggy states.
- **Trace & Visual Evidence** (`BOSS_VERTICAL_TRACE.json`, `captures/compare_boss_air_before_after.png`, `test_results_v3_021_r1_natural.json`):
  - Grounded boss combat (`SHIELD_CHARGE`, `QUAKE_RING`, `TRIPLE_CLEAVE`, parry, knockback): `max_unintended_player_y_meters = 0.00m` (`<= 0.15m` gate).
  - Single jump + mid-air horizontal combo alongside boss: `max_intentional_jump_arc_y_meters = 1.34m` (normal single-jump apex vs `2.97m` pre-fix).
  - Full natural E2E boss fight (`V3-022-R1-E2E-1794492437`): `max_player_y_during_boss = 0.60m`, `max_boss_y_during_boss = 0.10m`.
  - **Status**: **PASS**

### 2.4 `SPEED-P0` — Simulation Clock vs Video Playback Speed & Pacing Audit
- **Evidence Inspection** (`CAPTURE_CLOCK_AUDIT.json`, `TEST_MATRIX.md`, `VIDEO_REPORT.md`, `CLIENT/Game/test_results_v3_021_r1_natural.json`):
  - **Single-Source Run ID**: `V3-022-R1-E2E-1794492437` verified identical across `CAPTURE_CLOCK_AUDIT.json` and `CLIENT/Game/test_results_v3_021_r1_natural.json`.
  - **1:1 Frame-to-Tick Lock**: `rendered_frame_count = 1,849`, `physics_tick_count = 1,848` at `60 Hz` (`simulation_duration_seconds = 30.82s`).
  - **Video Stream Match**: `D:\JUNYPAPA_STUDIO\Videos\ProjectKnight\V3-022-R1\Physics_Pacing_Playtest_1x.mp4` (`SHA256: 5B10B4FAA43B9CD15B792B7AAE6BF95B9879A9BBD9B30B24CFB1BE2E28EA0002`, `58,132,124` bytes) has `nb_frames = 1849` at `60/1` FPS = `30.816667s` (`playback_speed_ratio = 1.0`, zero FFmpeg `setpts`/speed filters).
  - **Zero-Cheat Integrity**: `direct_state_mutations_performed = 0`, `zero_cheats_audit_passed = true`, `stage_cleared_naturally = true`, `total_enemies_defeated_naturally = 12`, `parries_performed = 24`, `final_player_hp = 3/9`.
  - **Status**: **PASS**

---

## 3. Game Director Quality Gate Scoring

| Category | Score (0–10) | Notes |
| :--- | :---: | :--- |
| **Functional Physics & Collision Integrity** | **9.4** | Layer 4 `StaticBody3D` colliders on all corridor pillars/wings block walking, Z-strafing, and dashing while keeping the main Z corridor open. |
| **Projectile Readability & Lifecycle** | **9.3** | `SideQVCrossbowBolt` moves every active frame (`0` frozen frames), aligns its glowing cone tip forward, and cleanly vanishes with impact sparks on shield/pillar/wall collision. |
| **Boss Combat Grounding & Vertical Control** | **9.5** | Eliminated spurious skyward pogo launches (`2.97m -> 1.34m` max jump arc, `0.00m` grounded drift). Boss fight stays firmly grounded and readable within the camera frame. |
| **2D/3D Integration & Visual Consistency** | **9.0** | Characters respect 3D architectural obstacles (`GatePillar_1..3`) instead of clipping through stonework; projectiles interact physically with 3D pillars and walls. |
| **Capture Honesty & Pacing Authenticity** | **9.5** | True 1.0x single-source recording (`1,849` frames = `30.82s` sim = `30.816667s` MP4) with zero direct state mutations. |
| **Overall Average** | **9.34 / 10.0** | **Exceeds >= 9.0 Vertical Slice Quality Gate (No category below 8.0)** |

---

## 4. Final Verdict

- **QA Lead Decision**: **`QA PASS`** (Zero unresolved P0/P1 issues; all acceptance criteria and regression checks verified with reproducible evidence).
- **Game Director Decision**: **`APPROVED`**
