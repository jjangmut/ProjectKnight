# V3-022 P0 Visual Defects — White/Overexposed VFX and Untextured Block Shield

**Source:** User's direct visual feedback after watching the latest Stage1 video.  
**Severity:** **P0, blocks visual quality approval**.  
**Applies to branch:** `studio/v3-022-gameplay-quality-gates` (base V3-021-R1).  
**Ordering:** Audit existing actual assets → reproduce at gameplay-frame level → fix materials/meshes/FX → capture before/after and verify. Do not spend time inventing more enemy AI or levels until these defects are addressed.

## 1. VFX appear indistinguishably white / lacking texture (VIS-009)

**Confirmed source pattern** (V3-021-R1):
- `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd`: `SlashVisual3D` builds a procedural mesh using `_generate_slash_arc_mesh`, `StandardMaterial3D.albedo_color = Color(3.6,2.8,1.2,0.88)`, emission `Color(3.6,2.6,1.0)`, `emission_energy_multiplier=4.5`, no albedo texture; shield barrier uses `Color(0.2,0.8,1.8)` with emission `Color(0.2,0.8,2.0)`, energy 4.0. Other sparks/rings similarly use overbright (>1.0) colors plus emission.
- `side_qv_boss.gd`: warning rings, fissure, charging VFX use `Color(3.8,0.4,0.2)` or similar + emission 4~4.5, no albedo texture in those mesh materials.
- `side_qv_elite_knight.gd`: block spark using `Color(1.5,2.5,4.0)` + emission 3.5.
This explains credible wash-out/textureless flat-color appearance, **but root cause still requires rendered frame/renderer exposure audit** (tonemapping, HDR, blend mode, transparency and actual captured frames). Do not blindly conclude every white pixel is from one material.

**Requirements:**
1. Produce a complete `VISUAL_ASSET_AUDIT.csv` or markdown table enumerating all combat VFX and weapon/shield procedural mesh nodes in Stage1: source path + line, VFX function, material params (albedo texture null?, unbounded RGB, emission energy), observed screenshot time, intended readable color, owner and fix. Include character swing, parry, dash, hurt, enemy attack, shield block, boss 3 patterns, telegraphs, impact sparks, drop orbs and backdrop lighting.
2. Inspect `CLIENT/Game/assets/**` for pre-existing suitable VFX textures, gradient/noise/flipbooks, mesh data; reuse originals if available. Where not, produce **real runtime-used** game textures/gradients/alpha masks (Godot-generated or committed small PNG resources) and hook them into actual `StandardMaterial3D.albedo_texture` / shader / particle texture. **Do not claim textured FX from simply recoloring procedural white triangles.** A high-quality procedural 3D ring may still be textureless by design if visually legible; document intent.
3. Establish a coherent, functionally distinct combat palette rather than all white: e.g., player sword warm gold with darker taper and motion streak; guard/parry cool cyan segmented shield with translucent edge; enemy attacks muted red/orange warning preceding active frame; boss fissure deep ember/orange with ground cracks; ranged projectile readable contrasting color. Do not rely on color alone: shape/animation/timing must differ. All palettes checked against actual Stage1 stone floor/light.
4. Reduce emission energy / HDR bloom clipping, alpha opacity, oversize geometry and overlapping effects. Clamp and profile materials in rendered game, choose bounded linear values consistent with Godot renderer; no arbitrary global brightness change that damages scene. Validate nonwhite chroma and visible silhouette on 4+ real frames per FX (startup, active, impact, recovery).
5. Match sprite weapon swing→slash arc→hitbox→impact location, including left/right/up/down/depth diagonals. If animation assets lack front/back poses, record real missing art and either author useable directional animation sprites or mark `DIRECTIONAL_ART_MISSING`; no false-perfect claim.

## 2. Enemy's large 'shield' looks like plain rectangular block (VIS-010)

**Confirmed source code:** `CLIENT/Game/scripts/side_quarter_view/side_qv_elite_knight.gd` lines ~56–72:
```gdscript
shield_mesh = MeshInstance3D.new()
shield_mesh.name = "TowerShieldMesh"
var s_box := BoxMesh.new()
shield_mesh.mesh = s_box
var smat := StandardMaterial3D.new()
smat.albedo_color = Color(0.25, 0.28, 0.38, 1.0)
smat.emission_enabled = true
smat.emission = Color(0.3, 0.6, 1.4, 1.0)
smat.emission_energy_multiplier = 1.2
shield_mesh.material_override = smat
```
**This is literally an untextured BoxMesh**, not a detailed modeled shield. It is an identifiable art placeholder, even if earlier QA scored it highly.

**Requirements:**
1. Replace the plain BoxMesh with a recognizably shield-shaped low-poly/2.5D prop: beveled/convex face or shape silhouette, visible rim, layered metal or wood panels, central boss/crest, sensible thickness/handle/attachment to enemy; **actual UV/texture or geometry detail**. Prefer available approved art assets. If using authored replacement texture, bundle a real image resource and apply to the in-game mesh—not to a separate concept screenshot.
2. The shield **must visibly belong to the knight's arm**, not float like a generic block. Animate its facing/rotation, guarding raised stance, bash wind-up, impact and recovery aligned to strike direction, including depth movement; preserve collision and blocking physics. If Sprite3D layering conflicts with 3D shield depth/order, fix occlusion.
3. Protect silhouette at **actual 1280×720 play scale**, not merely zoomed-in model inspection. Show textured front face, rear/side view and guard/bashed frames next to reference. Decorative geometry can be simplified for mobile performance but cannot look like an untextured cube.
4. Keep player attack hit direction and shield front-block logic consistent: frontal hit blocked, side/back correctly connect; no combat cheat or HP changes in visual showcase.

## 3. Hard acceptance / proof

- Create before/after side-by-side PNGs from **actual Godot-rendered window** under same camera, graphics config and frame phase (player slash, parry, shield knight guard, bash, boss fissure, boss ring, ranged shot), both 1280×720. No image-editor concept art passed off as in-game assets. Include video segment 20–40 seconds of meaningful combat, without state mutation. The original user video plus uploaded R1 video are historical evidence.
- `COLOR_CLIP_AUDIT.json`: per-frame clipped/near-white pixel ratio in each combat ROI using stable capture; note that white specular is allowed for tiny bright cores but not if entire slash/guard reads white. ROI segmentation can be assisted with debug overlays, not subjective color pass by metrics alone.
- `SHIELD_PROP_AUDIT.md`: mesh asset path, UV/textures source, runtime usage proof, material values, actual play-scale screenshots and motion states.
- QA must visually examine frames. Passing Godot parse tests or a renderer color sample does **not** certify art quality; mark `VISUAL_GATE_PENDING` until user/human reviewer sees corrected capture.
- P0 outcome if actual texture/shape asset absent: `ART_ASSET_REQUIRED`, not `PASS`. Do not create fake screenshots or declare a textured shield while gameplay still uses `BoxMesh`.
- Update `DEFECT_REGISTER.md` and `FRAME_REVIEW_INDEX.json` with `VIS-009` and `VIS-010`; do not overwrite existing recorded defects, append. Do not develop Stage2–5, Android or unrelated systems.
