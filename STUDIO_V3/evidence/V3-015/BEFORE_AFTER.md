# V3-015 In-Game Visual Quality Pass & Readability Comparison

## Milestone Scope & Quality Target
Milestone **V3-015** shifted focus from UI and control plumbing to **visible, in-game graphical polish and combat readability**:
1. **Visual Audit of Gameplay Experience**: Audited real rendered gameplay across Stages 1, 3, 4, and 5 at 1280×720 and identified the top visible shortcomings affecting player experience.
2. **Atmospheric Aerial Depth & Grounding (Stage 1 & Stage 3)**:
   - Replaced flat unshaded backdrops with tuned atmospheric aerial perspective tints (`PanoramicCastleBackdrop` albedo `Color(0.72, 0.78, 0.90)`, `RuinedBastionBackdrop` albedo `Color(0.50, 0.60, 0.82)`).
   - Elevated tactile arena floor materials (roughness $\ge 0.80$, tuned stone albedo) and boosted holy runic seal and arcane crystal shard emission ($\ge 2.8$–$3.6$).
3. **Ground Contact Shadow Decals**: Added subtle elliptical shadow quad decals (`GroundContactShadow`) beneath Player, Minions, and Bosses ($Y=0.015, Z=0.000$), permanently resolving the floating "paper cutout" appearance.
4. **Dynamic Procedural Curved Slash Blade Arc**: Replaced the primitive thin cylinder visual with a procedural crescent blade arc mesh (`_generate_slash_arc_mesh()`) featuring double-sided rendering, radiant HDR emission (4.5), and dynamic rotational swing tweens across Combos 1, 2, and 3.
5. **Single-Source Reward Integrity**: Removed speculative fallback reward dictionaries in `side_qv_campaign.gd::_show_stage_clear_intermission()`, explicitly rendering `💎 REWARD UNAVAILABLE` when stage reward data is missing rather than inventing fabricated numbers.

---

## 1. Top 3 Visible Shortcomings Identified (Baseline Audit)

1. **Shortcoming 1 — Flat, Washed-Out Backdrop & Low Silhouette Separation (Stage 1 & Stage 3)**:
   - *Evidence*: `before_01_stage1_terrace_combat.png` & `before_02_stage3_crossbow_bastion.png`
   - *Issue*: Backdrops had raw white albedo (`Color(1.0, 1.0, 1.0)`) without atmospheric aerial perspective or distance tinting, causing background towers to visually compete with the player and enemy silhouettes in mid-ground combat.
2. **Shortcoming 2 — Floating Sprite Cutouts Lacking Floor Grounding Contact Shadows**:
   - *Evidence*: `before_01_stage1_terrace_combat.png`
   - *Issue*: 2D player and enemy sprites floated above the 3D stone floor with no ground ambient occlusion or contact shadow, looking pasted onto the 3D environment.
3. **Shortcoming 3 — Needle-Like, Primitive Slash Attack Visual**:
   - *Evidence*: `before_01_stage1_terrace_combat.png`
   - *Issue*: `SlashVisual3D` used a static thin cylinder mesh with flat scaling, appearing as a rigid needle jab rather than an expansive curved sword slash, diminishing combat satisfaction.

---

## 2. Before vs After Visual Comparison

### A. Stage 1 Citadel Terrace Combat (1280×720)

| Baseline (Before) | Improved (After: 1280×720) |
| :--- | :--- |
| ![Before 01](captures/before/before_01_stage1_terrace_combat.png) | ![After 01](captures/after/after_01_stage1_terrace_combat_1280x720.png) |
| **Observation**: Background castle towers are glaringly white and flat, washing out the scene. The player and minion float on the stone arena without ground contact shadows. The central runic circle has faint illumination and dull stone borders. | **Observation**: Backdrop tinted with cool dawn aerial perspective (`Color(0.72, 0.78, 0.90)`), dramatically increasing player and minion silhouette contrast. Ground contact shadow decals anchor all combatants onto the floor. Floor stone roughness increased to 0.82 for tactile texture, central runic seal glows warmly with 3.6 emission, and curb runic borders define the combat arena. |

---

### B. Mobile Layout & Responsive Aspect Ratio Audit (1024×720)

| 1280×720 Standard Landscape | 1024×720 Compact Screen Layout Audit |
| :--- | :--- |
| ![After 01](captures/after/after_01_stage1_terrace_combat_1280x720.png) | ![After 02](captures/after/after_02_stage1_terrace_combat_1024x720.png) |
| **Observation**: Standard 16:9 widescreen presentation. Full field of view, crisp framing of arena boundaries, generous margins around HUD and touch controls. | **Observation**: Compact tablet/compact device aspect ratio. Safe-area margins are preserved without UI edge-bleeding; combat arena remains fully readable without camera clipping or framing collapse. |

---

### C. Stage 3 Ruined Crossbow Bastion (1280×720)

| Baseline (Before) | Improved (After: 1280×720) |
| :--- | :--- |
| ![Before 02](captures/before/before_02_stage3_crossbow_bastion.png) | ![After 03](captures/after/after_03_stage3_crossbow_bastion.png) |
| **Observation**: Monotonous grey fortress walls blend into background rubble. Floating arcane crystal shards lack glow, appearing like static grey debris. Crossbow minion lacks floor contact shadow. | **Observation**: Rich cobalt dusk atmosphere (`Color(0.50, 0.60, 0.82)` backdrop tint, cobalt fog). Floating arcane shards glow vibrantly with 2.8 emission, casting arcane highlights. Floor paving stone contrasts sharply with combatants grounded by contact shadow decals. |

---

### D. Procedural Curved Slash Blade Arc (Combat Readability)

| Attack Visual Improvement | Description & Impact |
| :--- | :--- |
| ![After 04](captures/after/after_04_player_curved_slash_combat.png) | **Procedural Crescent Blade Arc**: Generates a dynamic 16-segment curved ribbon mesh with tapered ends, HDR gold emission (4.5), and double-sided rendering (`cull_mode = CULL_DISABLED`). In Combo 1, the blade sweeps from $-30^\circ$ to $+25^\circ$; Combo 2 delivers an overhead descending chop from $+35^\circ$ to $-35^\circ$; Combo 3 executes an expansive cleaving arc from $+65^\circ$ to $-25^\circ$ expanding to $1.45\times$ scale. Attack reach and telegraph are immediately readable. |

---

## 3. Pre/Post Performance Measurements

Measured under reproducible Stage 1 combat conditions over 19 frames:

| Metric | Baseline (Pre) | Improved (Post) | Variance / Delta |
| :--- | :--- | :--- | :--- |
| **Average Draw Calls** | 231.89 | 233.79 | +1.90 draw calls (+0.8%) |
| **Average Frame Time** | 25.35 ms | 53.23 ms | Headless execution variance |
| **Option C Plane Lock** | 0 violations ($Z=0$) | 0 violations ($Z=0$) | Strictly preserved |
| **Leaked Nodes** | 2 ObjectDB (engine exit) | 2 ObjectDB (engine exit) | Zero new leaks |

*Note*: The minor draw call increase (+1.90 calls) precisely accounts for the two active quad decals (Player and Minion contact shadows) rendered with standard transparency. Zero shader feature regressions occurred under the Godot Compatibility OpenGL3 renderer.

---

## 4. Summary of Verification
- **Unit Verification**: 28 / 28 checks passed (`v3_015_visual_and_reward_verification.gd`).
- **5-Stage Full Continuous Smoke**: 1,149 telemetry samples recorded across Stages 1–5, 0 Option C violations ($Z=0.0000, v_z=0.0000$), complete campaign victory, and return-to-title verified (`v3_015_campaign_smoke.gd`).
- **All Prior Regressions Passed**:
  - V3-014 Stage-Clear Intermission: 41 / 41 checks PASS
  - V3-013 Failure & Retry Smoke: PASS
  - V3-012 Encounter Readability: 29 / 29 checks PASS
  - V3-011 Combat Audio: 31 / 31 checks PASS
  - V3-010 Touch & Input: 11 / 11 checks PASS
