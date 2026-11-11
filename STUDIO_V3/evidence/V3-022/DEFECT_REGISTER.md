# ProjectKnight V3-022 Defect Register

## Defect Summary
| Issue ID | Severity | Category | Component | Description | Resolution Status | Verified By |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **VIS-009** | **P0 BLOCKER** | Visual Art / VFX | `side_qv_player.gd`, `side_qv_boss.gd`, `side_qv_enemy.gd`, `side_qv_crossbow_bolt.gd`, `side_qv_stage_base.gd` | Combat and attack VFX appeared indistinguishably white and flat due to untextured meshes, missing UVs, unbounded HDR emission multipliers (up to 16.2), and linear tonemapping clipping. | **RESOLVED & VERIFIED** | `COLOR_CLIP_AUDIT.json`, In-Engine Captures 01-03, 07-08 |
| **VIS-010** | **P0 BLOCKER** | 3D Prop / Rigging | `side_qv_elite_knight.gd` | Heavy Bastion Knight shield was an untextured primitive `BoxMesh` (12 triangles) with no UVs, no heraldic crest, no curvature, and static hardcoded positioning without forearm socketing or recoil. | **RESOLVED & VERIFIED** | `SHIELD_PROP_AUDIT.md`, In-Engine Captures 04-06 |

---

## Detailed Defect Records

### [VIS-009] Combat VFX Blown-Out White / Missing Textures & Palettes
- **Reported Behavior**:
  - Swords swings, parry rings, impact sparks, enemy attacks, and boss shockwaves clipped to flat pure white `(255, 255, 255)`.
  - Visual distinction between parry (cyan), attack (amber), and enemy danger (crimson) was destroyed during gameplay.
- **Root Causes**:
  1. `_generate_slash_arc_mesh()` omitted `SurfaceTool.set_uv()`, making texture mapping impossible.
  2. Materials used unbounded raw HDR colors (e.g. `Color(3.6, 2.8, 1.2) * 4.5 = 16.2`).
  3. Godot `WorldEnvironment` defaulted to linear tonemapping which abruptly clipped all highlights past 1.0 into 255, 255, 255 white without rolloff.
- **Implemented Fix**:
  1. Generated dedicated runtime PNG textures: `vfx_slash_arc_amber.png`, `vfx_energy_barrier_runic.png`, `vfx_hit_spark_burst.png`, `vfx_enemy_slash_crescent.png`, `vfx_boss_fissure_magma.png`, `vfx_shockwave_ring.png`.
  2. Implemented explicit UV mapping across arc sweep $(U \in [0, 1])$ and width $(V \in [0, 1])$.
  3. Bounded emission energy multipliers to $1.30 \sim 1.35$ with additive blending and alpha falloff.
  4. Enabled `Environment.TONE_MAPPER_FILMIC` in `side_qv_stage_base.gd` for smooth HDR saturation rolloff.
- **Quantitative Audit Result**:
  - White clipping ratio: **0.0%** across all sampled effects.
  - Saturated chroma ratio: **50.8% - 70.2%** distinct amber, cyan, and volcanic magma hues.

---

### [VIS-010] Heavy Bastion Knight Shield Untextured BoxMesh Placeholder
- **Reported Behavior**:
  - The Heavy Shield Knight carried a literal grey rectangular block `BoxMesh.new(0.18, 1.35, 0.72)`.
  - Missing any medieval shield silhouette, heraldic crest, metallic rim, curvature, or attachment to arm.
- **Root Causes**:
  1. Prototype used `BoxMesh` with a single flat color material `Color(0.25, 0.28, 0.38)` and no textures.
  2. Hardcoded position `shield_mesh.position.x = face_x * 0.45` with zero socketing, rotation, or dynamic response.
- **Implemented Fix**:
  1. Authored procedural 3D curved Heater Shield mesh `_generate_heater_shield_mesh()`:
     - 948 vertices, 316 triangles (>20x geometric fidelity).
     - Cylindrical convex front curvature ($z = -0.075(1 - 4x^2/W^2)$).
     - Pointed lower tip, 8-sided raised central umbo boss, double-sided plate thickness.
     - Generated smooth normals, tangents, and explicit UV coordinates.
  2. Authored 512x512 PBR textures:
     - `heavy_shield_albedo.png`: Gold-embossed heraldic griffin crest, polished steel rim with rivets, obsidian-blue field.
     - `heavy_shield_normal.png`: Tangent-space bevel, rivets, and crest relief normal map.
     - `heavy_shield_metallic_roughness.png`: Metallic steel borders and satin-finished crest.
  3. Rigged dedicated `ShieldSocket` node with dynamic combat postures:
     - Frontal defensive guard: locked forward against incoming attacks.
     - Relaxed carry: natural inward tilt on the forearm.
     - Impact recoil: elastic backward kickback $(-0.12m)$ and tilt $(+14^\circ)$ with recovery.
     - Shield bash: forward lunge $(+0.58m)$ with shield leading.
- **Quantitative Audit Result**:
  - Gold crest pixels detected in front beauty shot: **45,441 px**.
  - Metallic rim specular highlights: **164,496 px**.
  - Geometric & PBR audit: **100% PASS**.
