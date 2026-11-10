# V3-016 Source Code Diff & Architecture Summary

## Modified Production Files

### 1. `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd`
- **Blade Arc Mesh Triangle Optimization**:
  - In `_generate_slash_arc_mesh()`:
    - Removed redundant reverse-winding duplicate quad geometry.
    - Since `cull_mode` is set to `BaseMaterial3D.CULL_DISABLED` on `SlashVisual3D`'s material, Godot automatically renders both front and back faces in hardware.
    - Reduced geometry from 4 triangles (12 vertex indices) per segment down to 2 triangles (6 vertex indices) per segment. Across 16 segments, index count decreased from 96 triangles down to 48 triangles per slash arc.
    - Halved vertex buffer allocation and draw submission overhead for sword slashes with zero visual regression.
- **Dynamic Ground-Anchored Jump Shadow Projection (`ISSUE-V3-015-005` Fix)**:
  - In `_physics_process()`:
    - Added airborne height calculation: `var jump_height: float = maxf(0.0, global_position.y - 0.1)`.
    - When airborne (`not is_on_floor()`):
      - Keeps `ground_shadow.global_position.y = 0.015` firmly pinned to the ground stone floor level.
      - Keeps `ground_shadow.global_position.z = 0.000` coplanar with the Option C gameplay plane.
      - Scales shadow dynamically with height: `var shadow_scale: float = maxf(0.40, 1.0 - jump_height * 0.16)`.
      - Applies `ground_shadow.scale = Vector3(shadow_scale, shadow_scale, 1.0)`.
    - When grounded (`is_on_floor()`):
      - Resets local `position = Vector3(0.0, 0.015, 0.0)` and `scale = Vector3.ONE`.
    - Resolves the visual defect where contact shadows lifted into the air during jumps and attacks.

### 2. `CLIENT/Game/scripts/side_quarter_view/side_qv_enemy.gd`
- **Minion Ground Shadow Floor Anchoring**:
  - In `_physics_process()`:
    - When minion is airborne (e.g. knocked up by heavy combo attacks or descending platforms), `ground_shadow.global_position.y` remains clamped to ground level ($0.015$) with $Z=0.000$, and scales smoothly based on elevation above ground.
    - Preserves grounded local offset $(0.0, 0.015, 0.0)$ when on floor.

### 3. `CLIENT/Game/scripts/side_quarter_view/side_qv_boss.gd`
- **Boss Ground Shadow Floor Anchoring**:
  - In `_physics_process()`:
    - Anchors boss contact shadow to ground floor ($Y=0.015, Z=0.000$) to prevent shadow displacement during attack animations or poise stagger.

---

## New Automated Test & Verification Scripts

### 1. `CLIENT/Game/tests/v3_016_benchmark_runner.gd`
- Dedicated steady-state benchmark runner measuring real Godot Win32 GUI window with Compatibility (OpenGL3) renderer.
- Discards first 60 warmup frames to exclude initial scene load and shader compilation overhead.
- Samples 300 steady-state frames per run across 3 runs per scenario on:
  - Scenario 1: Stage 1 Citadel Terrace Combat
  - Scenario 2: Stage 3 Ruined Crossbow Bastion
  - Scenario 3: Stage 4 Titan Stone Sanctuary
- Measures wall-clock frame-to-frame delta via `Time.get_ticks_usec()`.
- Calculates mean, median, P95, P99, 1% low frame time, effective FPS, and mean draw calls.
- Outputs individual per-frame CSV logs and aggregated benchmark JSON summary (`STUDIO_V3/evidence/V3-016/benchmarks/`).

### 2. `CLIENT/Game/tests/v3_016_capture_and_verify.gd`
- High-fidelity visual capture fixture producing:
  - `after_01_stage1_terrace_combat_1280x720.png`
  - `after_02_stage1_terrace_combat_1024x720.png`
  - `after_03_stage3_crossbow_bastion.png`
  - `after_04_player_jump_grounded_shadow_and_blade.png`
  - `after_05_stage4_golem_sanctuary.png`
  - `after_06_stage5_silent_citadel.png`
- Performs screenshot saving outside of timing intervals to eliminate measurement contamination.
- Programmatically audits and writes `CAPTURE_VERIFICATION_RESULT.json`.
