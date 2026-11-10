# V3-016 Issue List & Disclosures

## Milestone Tracking
- **Milestone ID**: V3-016
- **Objective**: Render Performance Truth & Playable Visual Optimization (Game First)
- **Target Branch**: `studio/v3-016-render-performance-validation`

---

## Resolved Issues

### ISSUE-V3-016-001 (P1): False Performance Regression Artifact in V3-015 Measurement Fixture
- **Severity**: P1 - High
- **Category**: Performance Profiling & Metric Integrity
- **Description**: Independent audit of `STUDIO_V3/evidence/V3-015/AFTER_PERFORMANCE.json` noted that while draw calls rose only 0.8%, measured frame time appeared to spike from 25.35ms to 53.23ms and FPS showed `1.00`. This raised concerns of an unvalidated 110% render regression.
- **Root Cause**:
  1. The V3-015 capture fixture sampled only 19 frames immediately after `change_scene_to_file()` (frames 12–30), catching the initial 2-frame shader compilation and driver allocation spike (Frame 1: 98.28ms, Frame 2: 71.01ms).
  2. Synchronous `img.save_png()` on the main thread during frame generation introduced 25–40ms disk I/O overhead.
  3. `Engine.get_frames_per_second()` rolling 1-second window had not completed after 0.35s, returning Godot's uninitialized `1.0` placeholder.
- **Resolution**: Implemented `CLIENT/Game/tests/v3_016_benchmark_runner.gd` with 60 warmup frames discarded, 300 steady-state frames measured per run, and 3 runs per scenario across Stages 1, 3, and 4 under a live Win32 GUI window with OpenGL3 renderer. Reproduced parent pre-V3-015 baseline under identical conditions. Proved that frame pacing remained rock-solid at **16.67ms (60.0 FPS)** throughout both milestones.
- **Verification**: Verified via `STUDIO_V3/evidence/V3-016/benchmarks/BENCHMARK_SUMMARY.json` and 9 raw frame CSV logs.

---

### ISSUE-V3-016-002 (P2): Redundant Duplicate Winding Triangles in Slash Arc Mesh Generation
- **Severity**: P2 - Medium
- **Category**: Rendering Optimization / Geometry Allocation
- **Description**: In `side_qv_player.gd::_generate_slash_arc_mesh()`, the procedural algorithm created opposing reverse-winding triangles for each segment to achieve double-sided rendering (4 triangles / 12 indices per segment, 96 triangles total).
- **Resolution**: Since the material already sets `cull_mode = BaseMaterial3D.CULL_DISABLED`, hardware rasterization renders both front and back faces automatically. Refactored the mesh generator to emit a clean single quad (2 triangles / 6 indices per segment), cutting blade mesh geometry vertex allocation and draw submission by 50% (down to 48 triangles per arc).
- **Verification**: Verified via `v3_015_visual_and_reward_verification.gd` (Checks 19–22) and visually in `after_04_player_jump_grounded_shadow_and_blade.png`.

---

### ISSUE-V3-016-003 (P2): Floating Ground Contact Shadows During Airborne Jumps & Attacks (`ISSUE-V3-015-005`)
- **Severity**: P2 - Medium
- **Category**: Visual Polish / Grounding Integrity
- **Description**: In V3-015, the `GroundContactShadow` was parented to the CharacterBody3D at local offset $(0, 0.015, 0)$. When the player jumped or minions were knocked into the air, the shadow quad detached from the stone floor and floated in mid-air, destroying the grounding illusion.
- **Resolution**: In `_physics_process()` of `side_qv_player.gd`, `side_qv_enemy.gd`, and `side_qv_boss.gd`, when an actor is airborne (`not is_on_floor()`), the shadow quad's world Y position is locked to ground stone floor level ($0.015, Z=0.000$) and its horizontal scale is dynamically diminished proportional to height ($\max(0.40, 1.0 - \text{jump\_height} \times 0.16)$). When grounded, local offset $(0, 0.015, 0)$ is restored.
- **Verification**: Verified programmatically in `v3_015_visual_and_reward_verification.gd` (Check 17) and visually in `after_04_player_jump_grounded_shadow_and_blade.png`.

---

## Mandatory Milestone Disclosures

1. **`ANDROID_NOT_TESTED`**:
   All benchmark measurements, frame pacing analyses, and visual captures were conducted on PC Windows 11 under Godot 4.7.2 with Compatibility (OpenGL3) renderer on an NVIDIA GeForce RTX 5060 Laptop GPU. While unthrottled desktop throughput reached 1,048 FPS (0.95ms), desktop OpenGL3 performance does NOT predict physical Android mobile device thermals, GPU fill rate, thermal throttling, or battery drain. Physical Android hardware testing remains scheduled for mobile integration milestones.

2. **`HUMAN_PLAYTEST_NOT_VERIFIED`**:
   Visual comparisons, jump shadow grounding, and combat flows were validated via automated deterministic harnesses and simulated engine inputs. Subjective player feel, jump rhythm, and aesthetic impressions require dedicated human playtesting.

3. **`COMMERCIAL_RELEASE_READINESS_NOT_CLAIMED`**:
   While render performance truth has been established at 60 FPS steady-state, blade arc mesh geometry optimized by 50%, and jump contact shadows grounded, full commercial release readiness is not claimed. Additional stage variety, sound balancing, and mobile device optimization remain ongoing.
