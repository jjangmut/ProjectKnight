# ProjectKnight V3-022-R1 — Verification Test Matrix

## 1. Execution Summary

| Test Suite | Script Path | Mode | Exit Code | Verdict |
| :--- | :--- | :--- | :---: | :---: |
| **Pre-Fix Defect Reproduction** | `res://tests/quality_gate/v3_022_r1_defect_repro.gd` | Windowed GPU | `0` | **REPRODUCED** (`PRE_FIX_REPRO_TRACE.json`) |
| **Post-Fix 3-Part Mechanics Suite** (`PILLAR-P0`, `PROJECTILE-P0`, `BOSS-AIR-P0`) | `res://tests/quality_gate/v3_022_r1_mechanics_verification.gd` | Windowed GPU (`--debug-collisions` & Clean) | `0` | **PASS** (`0` assertion errors) |
| **Natural No-Cheat Stage 1 E2E + 1.0x Video Capture** | `res://tests/v3_021_r1_stage1_natural_e2e.gd` | Windowed GPU + `--write-movie --fixed-fps 60` | `0` | **PASS** (`Run ID: V3-022-R1-E2E-1794492437`) |
| **Stationary Attack-Only Baseline** | `res://tests/v3_021_r1_stage1_natural_e2e.gd -- --baseline-attack-only` | Headless | `0` | **PASS** (`stage_cleared_naturally = false`) |

- **Human Testing Status**: `HUMAN_NOT_TESTED` / `AUTOMATED_INPUT_UNMODIFIED_GAME_STATE` (All runs executed via simulated `Input.action_press`/`action_release` events with `direct_state_mutations_performed = 0`).

---

## 2. Detailed Assertion Matrix

### A. `PILLAR-P0` — Stage Pillar Physical Collisions (`PILLAR_COLLISION_RESULTS.json`)
- `all_pillars_and_wings_have_layer4_colliders`: **`true`** (`GatePillar_1..3`, `BossPillar_Rear`, `GothicWing_Start/Bastion/Terrace/Boss`, `ParapetPost_*`).
- `x_approach_blocked`: **`true`** (Player walking `+X` from `x=16.2, z=-2.35` into `GatePillar_1` is physically stopped at `x=16.97` with `slide_collision_count = 1`).
- `z_approach_blocked`: **`true`** (Player walking `-Z` from `x=18.0, z=-1.0` into `GatePillar_1` is physically stopped at `z=-1.68` with `slide_collision_count = 1`).
- `dash_into_pillar_blocked`: **`true`** (High-speed dash into `GatePillar_1` does not tunnel through).
- `corridor_lane_bypass_open`: **`true`** (Player freely walks past `x=18.0` to `x=19.63` along open corridor lane `z=0.0`).

### B. `PROJECTILE-P0` — Ranged Projectile Motion & Impact (`PROJECTILE_TRACE.json`)
- `entity_class`: `SideQVCrossbowBolt` (`res://scripts/side_quarter_view/bosses/side_qv_crossbow_bolt.gd`).
- `mesh_tip_aligned_with_direction`: **`true`** (`dot = 1.0`).
- `max_consecutive_frozen_frames_while_active`: **`0`** (Moves `~0.275m` every physics frame at `16.5 m/s`).
- `vanished_on_player_guard_frame`: **`20`** (Impacts player shield at `x=33.65`, spawns `BoltImpactBurst`, and calls `queue_free()` on the exact impact frame — fixing the `_on_body_entered` early-return bug).
- `vanished_on_pillar_impact`: **`true`** (Blocked by `GatePillar_2` at frame 8, `x=44.80`).
- `vanished_on_csg_world_wall_impact`: **`true`** (Impacts `CastleBackWall` and vanishes).
- `continues_cleanly_when_shooter_dies_midair`: **`true`**.

### C. `BOSS-AIR-P0` — Boss Fight Vertical Stability (`BOSS_VERTICAL_TRACE.json`)
- `max_unintended_player_y_meters` (Grounded combat through `SHIELD_CHARGE`, `QUAKE_RING`, `TRIPLE_CLEAVE`, parry, and knockback): **`0.00m`** (Threshold `<= 0.15m`).
- `max_boss_y_meters`: **`0.00m`** in fixture, **`0.10m`** in full E2E playtest.
- `max_intentional_jump_arc_y_meters` (Single jump + repeated horizontal air attacks alongside boss): **`1.34m`** (Matches normal `1.28m` jump arc; eliminates the pre-fix `2.97m` skyward Pogo launch).
- `max_player_y_during_boss` in full natural Stage 1 victory run (`V3-022-R1-E2E-1794492437`): **`0.60m`**.

### D. `SPEED-P0` — Single-Source Clock & Video Pacing Audit (`CAPTURE_CLOCK_AUDIT.json`)
- `run_id`: `V3-022-R1-E2E-1794492437`
- `rendered_frame_count`: `1,849` frames
- `physics_tick_count`: `1,848` ticks
- `simulation_duration_seconds`: `30.82s`
- `mp4_nb_frames`: `1,849` frames @ `60/1` FPS
- `mp4_duration_seconds`: `30.816667s` (`playback_speed_ratio = 1.0`, zero FFmpeg speed/PTS manipulation).
