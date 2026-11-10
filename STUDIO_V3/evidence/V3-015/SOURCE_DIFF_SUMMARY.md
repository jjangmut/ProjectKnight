# V3-015 Source Code Diff & Architecture Summary

## Modified Production Files

### 1. `CLIENT/Game/scripts/side_quarter_view/side_qv_campaign.gd`
- **Bounded Correctness Fix (Reward Integrity)**:
  - In `_show_stage_clear_intermission()`:
    - Removed speculative fallback dictionary `shard_rewards = {0: 20, 1: 25, 2: 30, 3: 35, 4: 50}` and default fallback `20`.
    - If `current_stage_instance` has `last_earned_shards > 0`, that authoritative value is used and displayed (`"+ %d SOUL SHARDS EARNED"`).
    - If `last_earned_shards <= 0` or unavailable, sets `earned_shards = -1` and displays `"💎 REWARD UNAVAILABLE"` explicitly.
    - Eliminates duplicate reward assumptions and ensures single-source data flow between stages and the campaign UI layer.

### 2. `CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_1.gd`
- **Citadel Terrace Visual Polish & Atmospheric Aerial Depth**:
  - `_setup_3d_environment()`: Configured tailored dawn lighting with ambient color `Color(0.88, 0.92, 1.0)`, volumetric fog density `0.015`, fog light `Color(0.52, 0.62, 0.80)`, and glow bloom `0.22`.
  - `PanoramicCastleBackdrop`: Adjusted material albedo to `Color(0.72, 0.78, 0.90)` to create aerial perspective depth, resolving background visual competition with 2D character silhouettes.
  - `ArenaFloor`: Set stone roughness to `0.82` and albedo to `Color(0.85, 0.88, 0.95)` for crisp tactile surface definition.
  - `CentralRunicSeal`: Elevated gold emission energy multiplier to `3.6` with warm runic highlights.
  - Curbs & Braziers: Added runic borders and increased brazier omni lights to energy `2.8` and attenuation range `10.5m`.

### 3. `CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_3.gd`
- **Ruined Crossbow Bastion Twilight Contrast & Arcane Elements**:
  - `_setup_3d_environment()`: Configured deep cobalt twilight with ambient color `Color(0.30, 0.40, 0.62)`, fog density `0.020`, and fog light `Color(0.20, 0.28, 0.48)`.
  - `RuinedBastionBackdrop`: Set albedo tint to `Color(0.50, 0.60, 0.82)` for silhouette contrast against ruined masonry.
  - `ArenaFloor`: Paving roughness set to `0.80` with dark granite albedo `Color(0.68, 0.74, 0.86)`.
  - Floating Arcane Shards: Elevated crystal emission energy to `2.8` with cyan-violet glow.
  - Lanterns: Increased warm torch lights to range `6.8m` and energy `2.4`.

### 4. `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd`
- **Ground Contact Shadow & Procedural Curved Slash Arc**:
  - `_setup_ground_contact_shadow()`: Created `GroundContactShadow` quad mesh ($0.95 \times 0.45\text{ m}$) at $Y=0.015, Z=0.000$ with soft gradient alpha ($0.55$) and `TRANSPARENCY_ALPHA` flag.
  - `_generate_slash_arc_mesh()`: Procedural ArrayMesh algorithm generating a 16-segment curved crescent blade ribbon with outer radius $1.35\text{ m}$, inner radius $0.55\text{ m}$, sweeping $110^\circ$.
  - `SlashVisual3D`: Replaced primitive cylinder mesh with procedural crescent blade arc. Configured material with `cull_mode = CULL_DISABLED` and radiant HDR emission energy `4.5`.
  - Attack Animation Tweens: Added dynamic rotational sweeps and scales:
    - Combo 1: Sweeps $-30^\circ \to +25^\circ$, scale $0.45 \to 1.15 \to 0.25$.
    - Combo 2: Sweeps $+35^\circ \to -35^\circ$, scale $0.45 \to 1.25 \to 0.25$.
    - Combo 3: Sweeps $+65^\circ \to -25^\circ$, scale $0.50 \to 1.45 \to 0.20$.

### 5. `CLIENT/Game/scripts/side_quarter_view/side_qv_enemy.gd`
- **Minion Ground Contact Shadow**:
  - Added `_setup_ground_contact_shadow()` instantiating a $0.85 \times 0.40\text{ m}$ shadow quad at $Y=0.015, Z=0.000$, alpha $0.50$.
  - Automatically hidden upon death (`_on_death()`).

### 6. `CLIENT/Game/scripts/side_quarter_view/side_qv_boss.gd`
- **Boss Ground Contact Shadow**:
  - Added `_setup_ground_contact_shadow()` instantiating a $1.80 \times 0.75\text{ m}$ shadow quad at $Y=0.015, Z=0.000$, alpha $0.60$.
  - Automatically hidden upon boss defeat (`_on_death()`).

---

## New Test Scripts
1. `CLIENT/Game/tests/v3_015_capture_before.gd`: Baseline capture and performance fixture for Stages 1, 3, 4, 5.
2. `CLIENT/Game/tests/v3_015_visual_and_reward_verification.gd`: 28-assertion programmatic verification suite checking reward positive/negative paths, backdrop tints, floor roughness, runic emissions, shadow quads, procedural blade arc geometry, double-sided materials, and HDR emission.
3. `CLIENT/Game/tests/v3_015_capture_and_verify.gd`: High-resolution rendered 1280×720 and 1024×720 after-capture and performance sampling fixture.
4. `CLIENT/Game/tests/v3_015_campaign_smoke.gd`: Continuous real-input 5-stage campaign smoke test recording telemetry, SFX timeline, and victory flow.
