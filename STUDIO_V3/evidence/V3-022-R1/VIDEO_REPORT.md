# ProjectKnight V3-022-R1 — 1.0x Gameplay Video & Visual Comparison Report

## 1. Output Video Specifications
- **File Path**: `D:\JUNYPAPA_STUDIO\Videos\ProjectKnight\V3-022-R1\Physics_Pacing_Playtest_1x.mp4`
- **SHA256**: `5B10B4FAA43B9CD15B792B7AAE6BF95B9879A9BBD9B30B24CFB1BE2E28EA0002`
- **File Size**: `58,132,124` bytes (`~55.44 MB`)
- **Resolution**: `1280x720` (16:9 Landscape)
- **Video Stream**: `h264 (High)`, `yuvj420p`, `60/1` FPS (`r_frame_rate: "60/1"`), `1,849` frames (`nb_frames: "1849"`), duration `30.816667s`
- **Audio Stream**: `aac (LC)`, `48,000 Hz`, stereo, duration `30.816000s`
- **Run ID (Single-Source Telemetry & Recording)**: `V3-022-R1-E2E-1794492437`
- **Simulation Duration**: `30.82s` (`1,849` rendered frames / `1,848` physics ticks at `60 Hz` = `1.000x` exact real-time playback speed; no `setpts` or speed filters used).
- **Playtest Classification**: `AUTOMATED_INPUT_UNMODIFIED_GAME_STATE` (`HUMAN_NOT_TESTED`, `direct_state_mutations_performed = 0`).

---

## 2. Key Timestamps in `Physics_Pacing_Playtest_1x.mp4`

| Timestamp | Video Frame | Gameplay Event & Defect Verification |
| :--- | :---: | :--- |
| **`00:00.00 - 00:02.55`** | `0 - 153` | **Encounter 1 (Outer Gate Guard)**: 3 enemies defeated naturally via 3-hit combos, Just Parry, and depth flanking. |
| **`00:03.80 - 00:04.80`** | `228 - 288` (`frame_009.png`) | **`PILLAR-P0` Verified**: Player steers cleanly around the physical stone collider of `GatePillar_1` (`x = 18.0`, `Z in [-3.375, -2.025]`) along the open corridor lane instead of clipping through the stonework. |
| **`00:04.90 - 00:11.57`** | `294 - 694` (`frame_014.png`) | **`PROJECTILE-P0` Verified (Encounter 2)**: Purple-robed ranged sniper (`SideQVRangedMinion`) fires cyan crossbow bolts (`SideQVCrossbowBolt`) at `t = 6.5s - 7.5s`. Each bolt travels continuously every frame (`16.5 m/s`), is parried (`PARRIED!` popup at `t = 7.0s`), spawns an impact burst, and vanishes (`queue_free()`) immediately without freezing in mid-air. |
| **`00:12.28 - 00:16.68`** | `737 - 1001` (`frame_029.png`) | **Encounter 3 (Terrace Heavy Guard)**: Heavy Shield Knight frontal block (`BLOCKED!`), Z-lane depth flanking (`Z in [-2.14, +2.24]`), and ranged sniper takedown. |
| **`00:18.28 - 00:24.78`** | `1097 - 1487` (`frame_042.png`) | **`BOSS-AIR-P0` Verified (Boss Fight)**: Commander (`max_hp = 48`) executes `SHIELD_CHARGE`, `QUAKE_RING`, and `TRIPLE_CLEAVE`. Both player (`max_y = 0.60m`) and boss (`max_y = 0.10m`) stay grounded with zero skyward pogo launches (`2.97m` bug eliminated). |
| **`00:24.78 - 00:30.82`** | `1487 - 1849` | **Boss Defeat & Stage Clear Fanfare**: Natural stage clear (`stage_cleared_naturally = true`, `final_player_hp = 3/9`). |

---

## 3. Side-by-Side Before / After Captures (`STUDIO_V3/evidence/V3-022-R1/captures/`)

1. **Stone Pillar Collision (`PILLAR-P0`)**:
   - Before: `captures/before_pillar_pass_through.png` (Player walking straight through `GatePillar_1` in V3-022 video).
   - After (Debug Collision Shapes): `captures/after_pillar_debug_collision.png` (`StaticBody3D` Layer 4 collider wireframe visible, physically blocking player at `x = 16.97`).
   - After (Playtest Bypass): `captures/after_pillar_bypass_playtest.png` (Player bypassing `GatePillar_1` in open corridor lane).
   - Side-by-Side Comparison: `captures/compare_pillar_before_after.png`.
2. **Ranged Enemy Projectile (`PROJECTILE-P0`)**:
   - Before: `captures/before_projectile_frozen.png` (Orphaned bolt frozen on left side of screen after hitting player due to `_on_body_entered` early-return bug).
   - After (Flight & Parry Impact): `captures/after_projectile_flight.png` & `captures/after_projectile_parry_playtest.png` (Bolt flying cleanly and vanishing with `PARRIED!` burst upon impact).
   - Side-by-Side Comparison: `captures/compare_projectile_before_after.png`.
3. **Boss Fight Vertical Stability (`BOSS-AIR-P0`)**:
   - Before: `captures/before_boss_air_pop.png` (Player launched to `Y = 2.97m` at top of screen with `POGO!` popups).
   - After: `captures/after_boss_grounded_playtest.png` & `captures/after_boss_grounded_combat.png` (Grounded melee clash and controlled jump arc `<= 1.34m`).
   - Side-by-Side Comparison: `captures/compare_boss_air_before_after.png`.
