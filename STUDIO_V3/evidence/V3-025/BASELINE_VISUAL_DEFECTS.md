# V3-025 Baseline Visual Defects & Telegraph Reproduction Report

## 1. Executive Summary
During the audit of V3-024-R4 gameplay captures and Stage 1 source code, four distinct visual and telegraph defects were identified and reproduced. Most notably, a massive red rectangle in Encounter 3 that was reported as an "oversized red rectangular attack danger zone" was traced to an untextured environment floor decal (`Zone3_RoyalCrimsonCarpet`) combined with flat laser geometry and missing directional weapon indicators.

---

## 2. Identified Visual Defects & Root Causes

### Defect 1: The Encounter 3 "Giant Red Rectangle" (Zone3_RoyalCrimsonCarpet)
- **Observed Behavior**: At timestamp 00:00:16~00:00:18 in `Stage1_Natural_Complete_1x.mp4` (Encounter 3), a large flat, opaque red rectangle ($23.0\text{m} \times 2.8\text{m}$) with neon yellow borders blankets the entire combat floor between the player and the Heavy Shield Knights.
- **Root Cause**: In `CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_1.gd` lines 283–312:
  ```gdscript
  var z3_carpet := MeshInstance3D.new()
  z3_carpet.name = "Zone3_RoyalCrimsonCarpet"
  var z3_quad := QuadMesh.new()
  z3_quad.size = Vector2(23.0, 2.8)
  z3_mat.albedo_color = Color(0.68, 0.14, 0.18, 0.94) # Flat solid red
  for z_trim in [-1.42, 1.42]:
      t_mat.albedo_color = Color(1.2, 0.92, 0.32, 0.95) # Glowing neon yellow borders
      t_mat.emission = Color(1.2, 0.92, 0.32, 1.0)
      t_mat.emission_energy_multiplier = 1.2
  ```
  While intended as a decorative royal palace carpet, the combination of **untextured solid red color** and **emissive yellow warning border lines** made it indistinguishable from a bugged rectangular AoE attack telegraph.
- **Evidence**:
  - `STUDIO_V3/evidence/V3-025/diagnosis/diag_017.png`
  - Contour analysis: bounding box $(x=624, y=372, w=435, h=12)$ in screen space, covering the entire active lane.

---

### Defect 2: Rigid Flat Red Laser Line for Crossbow Minions (aim_laser_3d)
- **Observed Behavior**: In Encounter 2 (and 3), crossbow minions project a flat, static, unshaded red stick across the floor.
- **Root Cause**: In `CLIENT/Game/scripts/side_quarter_view/side_qv_ranged_minion.gd` lines 89–106 and 251–254:
  ```gdscript
  aim_laser_3d = MeshInstance3D.new()
  var l_quad := QuadMesh.new()
  l_quad.size = Vector2(6.5, 0.08) # Rigid 6.5m quad
  l_mat.albedo_color = Color(1.6, 0.25, 0.2, 0.85) # Unshaded red
  aim_laser_3d.position = Vector3(facing_dir_x * 3.25, 0.06, 0.0) # Fixed along X
  ```
  The line is locked along the X-axis ($Z=0$), failing to rotate toward the player's true depth coordinate ($Z$). When the bolt fires toward $(player.x, player.z)$, the visual laser and the physical projectile trajectory diverge, providing misleading visual cues.
- **Evidence**:
  - `STUDIO_V3/evidence/V3-025/diagnosis/diag_001.png`
  - Bounding box $(x=528, y=404, w=613, h=4)$.

---

### Defect 3: Melee Grunts & Shield Knights Lacking Directional Shape Telegraphs
- **Observed Behavior**: Melee enemies only projected a generic circular shockwave ring on the floor (`EnemyWindupRing3D`), offering no visual cue for swing direction, forward reach, attack cone, or post-attack vulnerability.
- **Root Cause**: `side_qv_enemy.gd` and `side_qv_elite_knight.gd` lacked directional mesh indicators matching their actual `attack_area_3d` collision extents ($1.2\text{m} \times 0.7\text{m}$ for Grunt, $1.8\text{m} \times 0.9\text{m}$ for Shield Bash).
- **Consequence**: Players could not read whether an attack was a frontal thrust, horizontal cleave, or shield bash, nor when the active frames started and ended.

---

### Defect 4: Overcounted Parry Instrumentation in Natural E2E Verification
- **Observed Behavior**: `NATURAL_E2E_RESULT.json` in V3-024-R4 reported `parries_performed: 53` across a 35.63-second run.
- **Root Cause**: In `v3_021_r1_stage1_natural_e2e.gd` line 724:
  ```gdscript
  func _trigger_just_parry() -> void:
      guard_hold_timer = 0.16
      Input.action_press("guard")
      telemetry["parries_performed"] += 1
  ```
  Every single `guard` button press by the automated bot was counted as a "parry performed", regardless of whether an enemy attack was active or whether a clash actually occurred.
- **Correction**: Split telemetry into `guard_inputs_attempted`, `successful_parries_deflected`, and `successful_counter_ripostes`.

---

## 3. Corrective Plan of Action
1. **Redesign Zone 3 Carpet**:
   Replace flat untextured red plane with textured Citadel flagstone tapestry (`TexFlagstone`), muted royal wine tint (`Color(0.42, 0.22, 0.26, 0.88)`), and non-emissive architectural stone curb borders (`Color(0.60, 0.52, 0.42, 0.85)`).
2. **Implement Dynamic 3-Phase Crossbow Telegraph**:
   - Tracking phase (amber dotted targeting beam pointing dynamically from crossbow muzzle to player).
   - Lock phase (beam locks in place, flashes crimson 0.14s before firing, providing reaction window).
   - Active phase (tracer bolt launched along exact locked trajectory).
   - Recovery phase (recock animation, laser cleared).
3. **Implement Shape-Accurate Directional Telegraphs for Melee Enemies**:
   - Grunt: 1.2m directional sweeping arc telegraph matching horizontal swing reach.
   - Shield Knight: 1.8m directional shield bash lane telegraph matching forward surge.
   - Visually distinct TELL (windup), ACTIVE (damage flash), and RECOVERY (vulnerable opening) phases.
4. **Implement Accurate Telemetry Instrumentation & Latency Benchmarks**:
   - Distinguish guard inputs from true clash deflections.
   - Benchmark pacing with 250ms and 450ms reaction-delayed policies alongside 4 core combat policies.
