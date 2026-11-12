# ProjectKnight V3-022-R1 — P0 Defect Reproduction & Root-Cause Analysis

## 1. Overview
During the user review of the V3-022 Stage 1 gameplay recording (`D:\JUNYPAPA_STUDIO\Videos\ProjectKnight\V3-022\Stage1_QualityGate_Uncut.mp4`), four critical P0 gameplay/physics/capture defects were identified:
1. **`PROJECTILE-P0`**: Ranged enemy ("wizard" / purple-robed `SideQVRangedMinion`) projectile visibly stopped/froze in mid-air during combat.
2. **`PILLAR-P0`**: The player character walked straight through stone stage pillars (`GatePillar_1..3`, `BossPillar_Rear`).
3. **`BOSS-AIR-P0`**: During the boss fight, the player character abnormally launched skyward (`Y = 2.97m`) to the top of the screen above the boss.
4. **`SPEED-P0`**: Gameplay speed vs video playback speed discrepancy (`29.27s` video vs `64.13s` reported telemetry) and fast combat pacing.

All four defects were reproduced in `CLIENT/Game/tests/quality_gate/v3_022_r1_defect_repro.gd` (generating `PRE_FIX_REPRO_TRACE.json`) and pinpointed to exact frames in `Stage1_QualityGate_Uncut.mp4`.

---

## 2. Defect 1: `PROJECTILE-P0` — Ranged Enemy Projectile Freezing in Mid-Air

### Visual Reproduction Evidence
- **Before Video Frame**: `STUDIO_V3/evidence/V3-022-R1/captures/before_projectile_frozen.png` (extracted from `Stage1_QualityGate_Uncut.mp4` at `t = 14.0s`, `frame_028.png`).
- **Entity Identified**:
  - Shooter: `SideQVRangedMinion` (`res://scripts/side_quarter_view/side_qv_ranged_minion.gd`, purple-robed mage/crossbowman sprite).
  - Projectile: `SideQVCrossbowBolt` (`res://scripts/side_quarter_view/bosses/side_qv_crossbow_bolt.gd`, spawned in `_execute_shoot()`).

### Exact Root Cause
1. **Primary Bug (`is_active = false` Early-Return Orphan Bug in `_on_body_entered`)**:
   - In `side_qv_crossbow_bolt.gd` line 122, when a bolt collided with the player (`if body.is_in_group("player"):`), `_on_body_entered()` set `is_active = false` **before** calling `_impact_and_vanish(true)` on line 127.
   - However, `_impact_and_vanish(spark: bool)` started with `if not is_active: return` on line 136!
   - Consequently, **every time a projectile hit or was guarded/parried by the player**, `_on_body_entered()` set `is_active = false` (stopping `_physics_process` movement), and `_impact_and_vanish(true)` immediately returned early without spawning the impact burst or calling `queue_free()`! The bolt mesh remained permanently frozen in mid-air at the impact coordinates for the rest of the stage!
2. **Secondary Visual & Collision Issues**:
   - `bolt_mesh.rotation_degrees.x = 90.0` rotated the tapered cone tip (`top_radius = 0.04`) toward `+Z` (backward after `look_at`), making the blunt cylinder base face forward.
   - `_on_body_entered()` only checked `(body.collision_layer & 4) != 0`, which ignored `CSGBox3D` walls (`CastleBackWall`, `FrontParapet`) that do not expose a `StaticBody3D` `collision_layer` property directly unless `body is CSGShape3D` is also checked.

### Code Fix Applied (`side_qv_crossbow_bolt.gd`, `side_qv_ranged_minion.gd`)
- Removed the premature `is_active = false` assignment before `_impact_and_vanish(true)` in `_on_body_entered()`, so `_impact_and_vanish(true)` properly sets `is_active = false`, spawns `BoltImpactBurst`, and calls `queue_free()` on the exact impact frame.
- Added a continuous `PhysicsRayQueryParameters3D` sweep (`prev_pos -> global_position`, mask `1 | 4`) in `_physics_process()` and checked `body is StaticBody3D or body is CSGShape3D` so bolts never tunnel through pillars or walls.
- Fixed `bolt_mesh.rotation_degrees.x = -90.0` and added `BoltHeadRing` so the glowing bolt head clearly points along its flight direction (`mesh_tip_aligned_with_direction = true`).

---

## 3. Defect 2: `PILLAR-P0` — Character Passing Through Stone Pillars

### Visual & Physics Reproduction Evidence
- **Before Video Frame**: `STUDIO_V3/evidence/V3-022-R1/captures/before_pillar_pass_through.png` (`t = 5.0s`, `frame_010.png` — player walking straight through `GatePillar_1` at `x = 18.0`).
- **Pre-Fix Trace (`PRE_FIX_REPRO_TRACE.json`)**:
  - `has_static_body = false`, `csg_use_collision = false`, `passed_through = true` (`player.x` walked unhindered from `16.0` through `18.0` to `19.63` at `z = -2.4`).

### Exact Root Cause
- In `CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_1.gd`, `_build_pillar()` (lines 384–414), `_build_gothic_wing()` (lines 417–441), and `_build_corridor_architecture()` (`ParapetPost_*`, lines 281–291) constructed `CSGBox3D` meshes with `use_collision = false` (default) and no `StaticBody3D` child. Once the temporary spectral encounter barrier dissolved, the stone pillars had zero physical collision.

### Code Fix Applied (`side_qv_stage_1.gd`)
- Enabled `use_collision = true` (`collision_layer = 4`) and attached an explicit `StaticBody3D` (`PillarCollider`, `collision_layer = 4`, `collision_mask = 0`) + `CollisionShape3D` (`BoxShape3D`) to every `GatePillar_1..3`, `BossPillar_Rear`, `GothicWing_*`, and `ParapetPost_*`.
- Verified in `PILLAR_COLLISION_RESULTS.json` that walking (`+X`, `-Z`) and dashing into `GatePillar_1` are physically blocked while the playable 2.5D corridor lanes (`Z in [-1.7, +3.0]`) remain completely open for traversal and flanking.

---

## 4. Defect 3: `BOSS-AIR-P0` — Boss Fight Abnormal Airborne Pop (`Y = 2.97m`)

### Visual & Physics Reproduction Evidence
- **Before Video Frame**: `STUDIO_V3/evidence/V3-022-R1/captures/before_boss_air_pop.png` (`t = 19.0s`, `frame_038.png` — player launched to the very top of the screen above the boss HP bar with `POGO!` text popups).
- **Pre-Fix Trace (`PRE_FIX_REPRO_TRACE.json`)**:
  - `max_player_y_meters = 2.97m`, `spurious_air_pop_reproduced = true`.

### Exact Root Cause
- In `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd` lines 809–810 (`_check_melee_hit()`):
  ```gdscript
  if not is_on_floor():
      _execute_pogo_bounce()
  ```
- `_execute_pogo_bounce()` set `velocity.y = jump_velocity * 0.96` (`+6.53 m/s`) on **every single mid-air melee hit**, regardless of whether the enemy was below the player or beside the player, and with no per-airtime limit or downward input requirement!
- When the player jumped over the Boss's `TRIPLE_CLEAVE` fissure wave and attacked horizontally while airborne next to the tall boss capsule, each combo hit triggered `_execute_pogo_bounce()`, launching the player from `Y = 1.28m -> 2.42m -> 2.97m` into the upper rafters!

### Code Fix Applied (`side_qv_player.gd`, `side_qv_boss.gd`)
- Added `has_used_air_pogo` (reset on `is_on_floor()`) and restricted `_execute_pogo_bounce()` in `_check_melee_hit()` so it ONLY triggers when:
  1. `not is_on_floor()` and `not has_used_air_pogo`
  2. `velocity.y <= 0.2` (descending or near apex)
  3. `Input.is_action_pressed("move_down")` (intentional Hollow Knight-style down-slash pogo)
  4. The struck target is actually below the player (`global_position.y > target_pos.y + 0.85` and `absf(dx) < 1.15`).
- Also added `set_deferred("monitoring", false)` in `side_qv_boss.gd` (`apply_parry_stun` and `_enter_groggy_state`) to eliminate the Godot physics signal warning during Just Parry stuns.
- Post-fix verification (`BOSS_VERTICAL_TRACE.json` & E2E run):
  - Grounded boss combat max player Y: `0.00m` (`<= 0.15m`).
  - Intentional jump + mid-air horizontal combo max player Y: `1.34m` (normal single-jump apex, vs `2.97m` pre-fix).
  - Full natural Stage 1 playtest boss fight max player Y: `0.60m`, max boss Y: `0.10m`.

---

## 5. Defect 4: `SPEED-P0` — Simulation Clock vs Video Playback Speed Audit

### Root Cause Diagnosis
- Inspection of `Stage1_QualityGate_Uncut.mp4` (`1,756` frames @ `60/1` FPS = `29.266667s`) proved that the video was encoded at 1.0x Movie Maker frame rate (`1756 / 60 = 29.27s`), whereas the `64.13s` duration cited in the V3-022 report came from a **separate** non-Movie-Maker run (`STAGE1_PACING_TOO_FAST_PLUS_SEPARATE_RUN_TELEMETRY_MISMATCH`).
- In V3-022-R1, we recorded telemetry and the Movie Maker AVI/MP4 in the **exact same execution** (`Run ID: V3-022-R1-E2E-1794492437`), increased Boss HP from `38` to `48`, and verified a 1:1 frame-to-tick match (`1,849` rendered frames = `30.82s` simulation duration = `30.816667s` MP4 duration).
