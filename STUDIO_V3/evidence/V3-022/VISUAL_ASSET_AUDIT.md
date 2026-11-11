# ProjectKnight V3-022: Stage 1 Visual Asset & VFX Full Audit (VIS-009 & VIS-010)

**Date:** 2026-11-11  
**Worktree:** `D:\JUNYPAPA_STUDIO\Worktrees\ProjectKnight\V3-022`  
**Target Branch:** `studio/v3-022-gameplay-quality-gates`  
**Auditor:** Antigravity / `PK_ArtDirector` & `PK_ClientLead`  
**Classification:** `P0_VISUAL_DEFECT_AUDIT`

---

## 1. Executive Summary

A comprehensive line-by-line audit of all combat VFX, procedural meshes, and weapon/shield props in Stage 1 was conducted to address the two critical player-facing visual defects:
1. **VIS-009:** Combat effects (sword slash, parry barrier, impact sparks, enemy attacks, boss patterns) blowing out into flat, untextured white shapes due to unbounded emission multipliers and linear tonemapping clipping.
2. **VIS-010:** Heavy Shield Knight wielding an untextured, rectangular `BoxMesh` with no shield geometry, rim, heraldry, or arm socket articulation.

---

## 2. Complete Stage 1 VFX & Prop Audit Table

| Source File & Lines | VFX / Prop Function | Mesh Type & Topology | Material Configuration | Albedo Texture | Root Cause of Defect | Target Color & Visual Fix |
|---|---|---|---|---|---|---|
| `side_qv_player.gd` L206–223 | Player Melee Radiant Slash | Procedural `ArrayMesh` via `_generate_slash_arc_mesh` (16 segs) | `albedo_color = Color(3.6, 2.8, 1.2, 0.88)`<br>`emission = Color(3.6, 2.6, 1.0)`<br>`energy = 4.5`, Unshaded | **None (`null`)**<br>No UVs generated! | Multiplier = $3.6 \times 4.5 = 16.2$. Severe HDR white-out. Without UVs and texture, renders as a flat solid white triangle fan. | Generate UVs in arc mesh. Apply `vfx_slash_arc_amber.png`. Bound emission to `Color(1.35, 0.90, 0.22)`, energy 1.4. Warm golden blade with motion taper. |
| `side_qv_player.gd` L186–203 | Player Guard Barrier (Parry) | `TorusMesh` (r_in: 0.6, r_out: 0.8) | `albedo_color = Color(0.2, 0.8, 1.8, 0.85)`<br>`emission = Color(0.2, 0.8, 2.0)`<br>`energy = 4.0`, Unshaded | **None (`null`)** | Plain torus ring. With energy 4.0, blue/green clips to pure white-cyan donut. | Replace with QuadMesh/curved shield facing front with `vfx_energy_barrier_runic.png`. Radiant azure-cyan runic lattice. Energy 1.4. |
| `side_qv_player.gd` L1120–1145 | Just Parry Clash Flash | `TorusMesh` (r_in: 0.45, r_out: 0.75) | `albedo_color = Color(1.2, 2.4, 3.8, 0.95)`<br>`emission = Color(1.2, 2.4, 3.8)`<br>`energy = 4.5` | **None (`null`)** | Multiplier = 17.1. Overwhelming white ring obscuring hero silhouette. | Bound emission to `Color(0.4, 1.2, 2.2)`, energy 1.6. Apply `vfx_hit_spark_burst.png` starlight radial burst. |
| `side_qv_elite_knight.gd` L57–72 | Heavy Shield Knight Greatshield | `BoxMesh` (0.18 × 1.35 × 0.72) | `albedo_color = Color(0.25, 0.28, 0.38)`<br>`metallic = 0.9`, `roughness = 0.3`<br>`emission = Color(0.3, 0.6, 1.4)`, `energy = 1.2` | **None (`null`)** | **Literally an untextured rectangular box!** Art placeholder with no bevel, no rim, no crest, no handle. | Replace with modeled/curved 3D Heater Shield mesh with UV mapping. Apply `heavy_shield_albedo.png`, metallic/roughness, and normal map. Socket to forearm with dynamic guard and bash animations. |
| `side_qv_elite_knight.gd` L143–164 | Shield Block Deflection Spark | `TorusMesh` (r_in: 0.25, r_out: 0.55) | `albedo_color = Color(1.5, 2.5, 4.0, 0.9)`<br>`emission = Color(1.5, 2.5, 4.0)`<br>`energy = 3.5` | **None (`null`)** | Torus mesh blows out into a white flare on impact. | Apply `vfx_hit_spark_burst.png` with steel spark particle dispersion. Bound emission to `Color(0.8, 1.4, 2.4)`, energy 1.5. |
| `side_qv_enemy.gd` L401–428 | Minion Defeat Soul Burst | `TorusMesh` (r_in: 0.25, r_out: 0.45) | `Color(0.8, 2.6, 3.8)` or `Color(3.5, 1.2, 0.3)`<br>`energy = 3.5` | **None (`null`)** | Solid white expanding donut. | Apply feathered shockwave texture with soft amber/gold soul dissolution particles. |
| `side_qv_boss.gd` L358–380 | Boss Danger Telegraph Ring | `TorusMesh` (r_in: 0.6, r_out: 0.95) | `albedo_color = Color(3.8, 0.4, 0.2, 0.9)`<br>`emission = Color(3.8, 0.4, 0.2)`<br>`energy = 4.5` | **None (`null`)** | Red multiplier = 17.1. Overbright white-yellow center with jagged edge. | Apply `vfx_shockwave_ring.png`. Rich crimson-amber gradient (`Color(1.5, 0.35, 0.1)`), energy 1.5. |
| `side_qv_boss.gd` L482–512 | Boss Ground Fissure Wave | `QuadMesh` (1.8 × 1.2) | `albedo_color = Color(3.5, 1.5, 0.2, 0.95)`<br>`emission = Color(3.5, 1.5, 0.2)`<br>`energy = 4.0` | **None (`null`)** | Blank untextured quad flying along floor. Solid white block. | Apply `vfx_boss_fissure_magma.png` with glowing molten cracks and rock debris. Energy 1.5. |
| `side_qv_boss.gd` L527–550 | Boss 360 Quake Shockwave | `TorusMesh` (r_in: 0.65, r_out: 1.05) | `albedo_color = Color(3.4, 0.55, 0.2, 0.9)`<br>`emission = Color(3.4, 0.55, 0.2)`<br>`energy = 4.2` | **None (`null`)** | Untextured torus expanding outward. | Apply `vfx_shockwave_ring.png` with concentric ring lines and ground dust alpha taper. |
| `side_qv_crossbow_bolt.gd` L45–70 | Crossbow Energy Bolt | `CylinderMesh` (r: 0.08, h: 0.85) | `Color(0.8, 1.6, 3.2)`<br>`energy = 3.5` | **None (`null`)** | Solid white beam streak. | Add cobalt-azure gradient core and translucent feathered tracer tail. Energy 1.5. |
| `side_qv_stage_base.gd` L125–146 | Environment Tonemapping & Glow | `WorldEnvironment` | `glow_enabled = true`, `bloom = 0.18`<br>Default tonemap: `LINEAR` | N/A | Linear tonemapping has zero highlight rolloff; any value $> 1.0$ clamps to pure white $(1,1,1)$. | Enable `tonemap_mode = TONEMAPPER_FILMIC` to preserve rich saturation across HDR highlights without clipping. |

---

## 3. Coherent Functional Color Palette

To ensure instant readability during combat, distinct colors and visual motifs are assigned to every gameplay event:

| Event Category | Primary Palette | Accent / Energy | Texture Motif |
|---|---|---|---|
| **Player Greatsword Slash** | Warm Amber Gold (`#FFAA1E`) | Solar Yellow Core (`#FFE066`) | Smooth tapered crescent arc with motion streaks and sharp cutting rim |
| **Player Guard / Just Parry** | Luminous Azure Cyan (`#1EB8FF`) | Crystalline Aqua (`#80E5FF`) | Hexagonal energy lattice with runic edge and radiating starlight sparks |
| **Heavy Shield Knight** | Forged Dark Iron (`#323846`) | Polished Brass / Gold Trim (`#D4A038`) | Layered heater shield with steel rivets, heraldic lion crest, and leather straps |
| **Enemy Attacks (Melee/Bash)** | Danger Crimson Orange (`#E63B12`) | Ember Spark (`#FF6E30`) | Jagged aggressive slash trail and blunt concussive shock |
| **Crossbow Bolt** | Electric Cobalt Cyan (`#2080FF`) | Lapis Trail (`#60B0FF`) | Aerodynamic arrow shaft with luminous feathered tracer |
| **Boss Fissure & Quake** | Molten Magma Red-Orange (`#D94010`) | Volcanic Yellow Flame (`#FF9920`) | Jagged subterranean ground cracks and concentric shockwave ripples |
