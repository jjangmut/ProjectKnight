# V3-015 Independent QA Review & Milestone Verification

**Milestone:** V3-015 — In-Game Visual Quality Pass (Game First)  
**Reviewer:** `PK_QALead` (Independent QA Lead, ProjectKnight Studio V3)  
**Date:** 2026-11-10  
**Repository:** `jjangmut/ProjectKnight`  
**Branch:** `studio/v3-015-visual-gameplay-polish`  
**Frozen Target Commit SHA:** `abcffa19e8ad8baccede3d9d60be8be4af46b4bc` (short: `abcffa1`)  
**Execution Environment:** Windows 11 (AMD64), Godot Engine v4.7.2.stable.official.ed1daf0bf, OpenGL3 Compatibility, NVIDIA GeForce RTX 5060 Laptop GPU (Driver: NVIDIA 610.47), Viewport Targets: 1280×720 (Primary Landscape) & 1024×720 (Narrow / Tablet Aspect)  

---

## 1. Formal QA Verdict

```text
================================================================================
                    PROJECT KNIGHT QA AUDIT REPORT
 Milestone: V3-015 In-Game Visual Quality Pass (Game First)
 Verdict:   QA PASS
 Status:    PASSED / APPROVED FOR MILESTONE ADVANCEMENT
 Blockers:  0 (P0: 0, P1: 0, P2: 3 logged for polish backlog, P3: 1 logged for polish)
================================================================================
```

### 1.1. Verdict Summary
`PK_QALead` has conducted an exhaustive, independent Quality Assurance verification audit of Milestone **V3-015** at frozen implementation commit [`abcffa19e8ad8baccede3d9d60be8be4af46b4bc`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight).

Milestone V3-015 shifts focus decisively from menu/control plumbing to **visible in-game graphical polish, grounded character presence, satisfying combat feedback, and authoritative reward integrity**:
1. **Atmospheric Aerial Perspective & Depth Separation (Stages 1 & 3):**
   - Replaced flat unshaded backdrops (`Color(1.0, 1.0, 1.0)`) with tailored atmospheric aerial depth tints ([`PanoramicCastleBackdrop`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_1.gd#L70-L85) albedo `Color(0.72, 0.78, 0.90)` in Stage 1; [`RuinedBastionBackdrop`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_3.gd#L90-L105) albedo `Color(0.50, 0.60, 0.82)` in Stage 3).
   - Upgraded tactile stone floor materials (tactile roughness $\ge 0.80$, tuned paving albedos), boosted holy runic seal emission to $3.6$ multiplier with curb runic borders, and elevated floating arcane shard emission to $2.8$ with expanded torch lighting.
2. **Ground Contact Shadow Decals (2D/3D Grounding):**
   - Created subtle elliptical shadow quad decals (`GroundContactShadow`) positioned at $Y=0.015, Z=0.000$ beneath Player ($0.95 \times 0.45\text{ m}$), Minions ($0.85 \times 0.40\text{ m}$), and Bosses ($1.80 \times 0.75\text{ m}$).
   - Permanently resolves the floating "paper cutout" appearance without incurring heavy real-time shadow map overhead, strictly preserving Option C plane lock ($Z=0.0000$).
3. **Dynamic Procedural Curved Slash Blade Arc (Combat Feedback & Reach):**
   - Replaced the primitive thin cylinder visual with a procedural crescent blade arc mesh ([`_generate_slash_arc_mesh()`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd#L964-L1005)) featuring double-sided rendering (`cull_mode = CULL_DISABLED`), radiant HDR emission energy ($4.5$), and dynamic rotational swing tweens across Combos 1, 2, and 3 (Combo 1: $-30^\circ \to +25^\circ$; Combo 2: $+35^\circ \to -35^\circ$; Combo 3 finisher: $+65^\circ \to -25^\circ$, expanding to $1.45\times$).
4. **Single-Source Reward Integrity:**
   - Eliminated the speculative fallback reward dictionary (`{0: 20, 1: 25, 2: 30, ...}`) and fallback default 20 in [`side_qv_campaign.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/scripts/side_quarter_view/side_qv_campaign.gd#L118-L130).
   - If stage rewards are unavailable or non-positive, sets `earned_shards = -1` and displays explicit `"💎 REWARD UNAVAILABLE"` with subdued styling rather than fabricating reward values.
5. **Option C Plane Lock Verification:**
   - Audit of all 1,149 actor telemetry records in [`ACTOR_Z_PRESENCE.csv`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-015/ACTOR_Z_PRESENCE.csv) confirms **0 violations** of the $Z=0$ gameplay plane ($Z = 0.0000, v_z = 0.0000$ maintained across 100% of samples).
6. **Full Campaign Playthrough & Regression Suite:**
   - Verified 5-stage continuous campaign smoke test ([`v3_015_campaign_smoke.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/tests/v3_015_campaign_smoke.gd)), visual & reward verification suite (28/28 passed), and 5 historical regression suites (V3-014: 41/41, V3-013: 27/27, V3-012: 29/29, V3-011: 31/31, V3-010: 11/11), all exiting with Code 0.

Zero blocking defects (P0/P1) exist. Therefore, `PK_QALead` issues formal **QA PASS**.

---

## 2. Frozen Code Inspection at Commit `abcffa1`

The QA Lead audited all production code modifications committed in `abcffa19e8ad8baccede3d9d60be8be4af46b4bc`:

### 2.1. Reward Data Integrity & Single-Source Authority
- **File Inspected:** [`CLIENT/Game/scripts/side_quarter_view/side_qv_campaign.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/scripts/side_quarter_view/side_qv_campaign.gd)
- **Elimination of Fallback Dictionary:**
  ```gdscript
  func _show_stage_clear_intermission() -> void:
      var earned_shards: int = -1
      if current_stage_instance != null and "last_earned_shards" in current_stage_instance and current_stage_instance.last_earned_shards > 0:
          earned_shards = current_stage_instance.last_earned_shards
      
      if earned_shards > 0:
          print(">>> [CAMPAIGN] Displaying Stage Clear Intermission: Stage %d, Authoritative Earned Shards=%d <<<" % [current_stage_index + 1, earned_shards])
      else:
          print(">>> [CAMPAIGN] Displaying Stage Clear Intermission: Stage %d, Authoritative Reward Unavailable <<<" % [current_stage_index + 1])
  ```
- **Explicit Unavailable State Presentation:**
  ```gdscript
      # Reward Section: Authoritative Single Source
      var reward_lbl := Label.new()
      reward_lbl.name = "RewardLabel"
      if earned_shards > 0:
          reward_lbl.text = "💎 + %d SOUL SHARDS EARNED" % earned_shards
          reward_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
      else:
          reward_lbl.text = "💎 REWARD UNAVAILABLE"
          reward_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80))
      reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
      reward_lbl.add_theme_font_size_override("font_size", 22)
      vbox.add_child(reward_lbl)
  ```
  *QA Finding:* Guarantees that neither UI speculation nor duplicate arrays invent reward quantities. The positive path shows authoritative stage rewards; negative path clearly indicates absence without inventing numbers.

### 2.2. Stage 1 Citadel Terrace Visual Pass
- **File Inspected:** [`CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_1.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_1.gd)
- **Atmospheric WorldEnvironment:** Configured dawn lighting with `ambient_light_color = Color(0.72, 0.78, 0.92)`, energy `1.18`, screen-blend HDR glow bloom `0.22`, and atmospheric fog with density `0.016` and aerial perspective `0.48`.
- **Backdrop Silhouette Contrast:** Adjusted `PanoramicCastleBackdrop` albedo tint to `Color(0.72, 0.78, 0.90)` to create natural atmospheric perspective, dropping background visual noise behind active combatants.
- **Tactile Floor & Holy Seal:** Arena stone floor roughness set to `0.82` with crisp flagstone tiling; `CentralRunicSeal` emission boosted to `3.6` multiplier (`Color(1.0, 0.94, 0.70)`); added runic curb borders with subtle cobalt emission (`Color(0.18, 0.38, 0.72)`, energy `1.35`) and upgraded brazier illumination to energy `2.8` and omni range `10.5m`.

### 2.3. Stage 3 Ruined Bastion Visual Pass
- **File Inspected:** [`CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_3.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_3.gd)
- **Cobalt Twilight Depth:** Configured deep night sky `Color(0.08, 0.12, 0.22)` with ambient light `Color(0.30, 0.40, 0.62)` and volumetric fog light `Color(0.20, 0.28, 0.48)`.
- **Ruined Backdrop Contrast:** Tuned `RuinedBastionBackdrop` albedo tint to `Color(0.50, 0.60, 0.82)`.
- **Arcane Highlights:** Elevated floating crystal shard emission to `2.8` multiplier (`Color(0.35, 1.25, 2.8)`) and increased arcane lantern range to `6.8m` and energy to `2.4`.

### 2.4. Player Procedural Curved Slash Arc & Grounding Decal
- **File Inspected:** [`CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd)
- **Procedural Crescent Mesh Generation (`_generate_slash_arc_mesh`):**
  - Uses `SurfaceTool` with `PRIMITIVE_TRIANGLES` over 16 angular segments sweeping $110^\circ$.
  - Computes sinusoidal thickness tapering ($r_{inner} = 0.55\text{ m}, r_{outer} = 1.35\text{ m}$) creating an authentic crescent ribbon that tapers to sharp tips at leading/trailing edges.
  - Generates double-sided geometry (4 triangles per segment) combined with `cull_mode = CULL_DISABLED`.
  - Configures radiant HDR golden-white emission energy `4.5` (`Color(3.6, 2.6, 1.0)`).
- **Dynamic Rotational Tweens:**
  - Combo 1: Sweeps $-30^\circ \to +25^\circ$, scale $0.45 \to 1.15 \to 0.25$ over 0.12s.
  - Combo 2: Sweeps $+35^\circ \to -35^\circ$, scale $0.45 \to 1.25 \to 0.25$ over 0.12s.
  - Combo 3 Finisher: Sweeps $+65^\circ \to -25^\circ$, scale $0.50 \to 1.45 \to 0.20$ over 0.14s.
- **Player Ground Contact Shadow:** $0.95 \times 0.45\text{ m}$ quad decal rotated $-90^\circ$ around X, placed at $Y=0.015, Z=0.000$, alpha `0.55`.

### 2.5. Minion & Boss Ground Contact Shadows
- **Files Inspected:** [`CLIENT/Game/scripts/side_quarter_view/side_qv_enemy.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/scripts/side_quarter_view/side_qv_enemy.gd) and [`CLIENT/Game/scripts/side_quarter_view/side_qv_boss.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/scripts/side_quarter_view/side_qv_boss.gd)
- Instantiates soft elliptical contact shadow quads at $Y=0.015, Z=0.000$ beneath minions ($0.85 \times 0.40\text{ m}$, alpha `0.50`) and bosses ($1.80 \times 0.75\text{ m}$, alpha `0.60`).
- Strictly parented to actor nodes; smoothly destroyed on death via `queue_free()`.

---

## 3. Three-Layer Independent QA Audit Evaluation

### 3.1. Layer 1: Functional QA

#### 3.1.1. Unit Verification Suite (28 Checks)
Programmatic verification suite [`CLIENT/Game/tests/v3_015_visual_and_reward_verification.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/tests/v3_015_visual_and_reward_verification.gd) was independently executed live. All 28 checks passed with Exit Code 0:

| # | Check Identifier | Expected Behavior | Actual Measured Result | Verdict |
|---|---|---|---|:---:|
| 1 | `campaign_loads_stage1` | Campaign initializes Stage 1 instance | Stage 1 active, index = 0 | **PASS** |
| 2 | `stage_clear_overlay_displayed` | StageClearOverlay created on clear | Node active in CampaignUILayer | **PASS** |
| 3 | `reward_label_exists` | `RewardLabel` exists in intermission | Label node verified | **PASS** |
| 4 | `positive_reward_label_shards` | Positive path shows '+ 20 SOUL SHARDS EARNED' | Exact string match | **PASS** |
| 5 | `negative_overlay_recreated` | Intermission overlay recreated for negative check | Fresh overlay verified | **PASS** |
| 6 | `negative_reward_label_text` | Negative path shows '💎 REWARD UNAVAILABLE' | Exact string match | **PASS** |
| 7 | `negative_no_speculative_fallback` | No speculative +20 fabricated | Zero fabricated shards | **PASS** |
| 8 | `stage1_backdrop_exists` | `PanoramicCastleBackdrop` exists | Node found in Stage 1 | **PASS** |
| 9 | `stage1_backdrop_aerial_tint` | Backdrop albedo != pure white | Albedo != `(1, 1, 1)` | **PASS** |
| 10 | `stage1_backdrop_matches_tint` | Albedo matches `Color(0.72, 0.78, 0.90)` | `Color(0.72, 0.78, 0.90, 1.0)` verified | **PASS** |
| 11 | `stage1_arena_floor_exists` | `ArenaFloor` exists | Node found in Stage 1 | **PASS** |
| 12 | `stage1_floor_roughness` | Floor roughness is high tactile quality ($\ge 0.80$) | Roughness = 0.82 | **PASS** |
| 13 | `stage1_central_seal_exists` | `CentralRunicSeal` exists | Node found in Stage 1 | **PASS** |
| 14 | `stage1_seal_emission` | Seal emission energy multiplier $\ge 3.5$ | Emission energy = 3.6 | **PASS** |
| 15 | `player_exists_stage1` | Player instance active in Stage 1 | Player verified | **PASS** |
| 16 | `player_contact_shadow_exists` | `GroundContactShadow` decal exists on player | MeshInstance3D verified | **PASS** |
| 17 | `player_shadow_y_grounded` | Shadow decal Y position is 0.015 | Position Y = 0.015 | **PASS** |
| 18 | `player_shadow_coplanar_z0` | Shadow decal strictly coplanar Z=0 | Position Z = 0.0000 | **PASS** |
| 19 | `player_slash_visual_exists` | `SlashVisual3D` exists on player | MeshInstance3D verified | **PASS** |
| 20 | `player_slash_array_mesh` | Slash visual uses procedural `ArrayMesh` | `ArrayMesh` verified | **PASS** |
| 21 | `player_slash_double_sided` | Slash material has `CULL_DISABLED` | Cull mode disabled | **PASS** |
| 22 | `player_slash_hdr_emission` | Slash material HDR emission $\ge 4.0$ | Emission multiplier = 4.5 | **PASS** |
| 23 | `minion1_exists_stage1` | Minion_1 instance active in Stage 1 | Minion verified | **PASS** |
| 24 | `minion1_contact_shadow_exists` | `GroundContactShadow` decal exists on Minion_1 | MeshInstance3D verified | **PASS** |
| 25 | `stage3_backdrop_exists` | `RuinedBastionBackdrop` exists | Node found in Stage 3 | **PASS** |
| 26 | `stage3_backdrop_cobalt_tint` | Albedo matches `Color(0.50, 0.60, 0.82)` | `Color(0.50, 0.60, 0.82, 1.0)` verified | **PASS** |
| 27 | `stage3_floating_shard_exists` | Stage 3 floating shard exists | MeshInstance3D verified | **PASS** |
| 28 | `stage3_shard_arcane_emission` | Shard emission energy multiplier $\ge 2.7$ | Emission energy = 2.8 | **PASS** |

#### 3.1.2. Continuous 5-Stage Playthrough E2E Flow
Independent audit of [`STAGE5_REAL_INPUT_E2E_RESULT.json`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-015/STAGE5_REAL_INPUT_E2E_RESULT.json) and execution log [`STAGE5_REAL_INPUT_E2E_LOG.txt`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-015/STAGE5_REAL_INPUT_E2E_LOG.txt) confirmed:
- **Title Screen Deploy:** Real mouse click at $(971.5, 216.0)$ activated Deploy; Stage 1 loaded at $0.467\text{s}$.
- **Stage Progression 1 $\to$ 5:** All 5 stages cleared sequentially using real melee inputs and intermission Continue clicks (Stage 1 clear at $7.776\text{s}$, Stage 2 at $15.394\text{s}$, Stage 3 at $22.286\text{s}$, Stage 4 at $30.519\text{s}$, Stage 5 entry at $30.552\text{s}$).
- **Stage 5 Elite Minions:** Defeated both Elite Abyssal Knights (Instance IDs `134167398093`, `134502942993`).
- **Abyssal Arbiter Boss Combat:** Spawned with $HP=38/38, \text{Poise}=18$, teleported to $(5.54, 0.10, 0.00)$, transitioned to Phase 2 at $HP=17/38$ ($36.727\text{s}$), triggered Judgment Storm, defeated naturally at $HP=0$ ($40.760\text{s}$).
- **Campaign Victory & Return-to-Title Loop:** `CampaignVictoryPanel` appeared at $42.785\text{s}$; Return to Title clicked; Title Screen loaded at $42.918\text{s}$; Second Deploy clicked; Stage 1 reloaded cleanly at $43.018\text{s}$. Zero cheats, zero crashes.

---

### 3.2. Layer 2: Visual QA

#### 3.2.1. Visual Quality Rubric Evaluation (10 Categories)

| # | Evaluation Category | Score (1-10) | QA Lead Assessment |
|---|---|:---:|---|
| 1 | **2D Character Readability** | 9.7 / 10 | The aerial depth tinting of backdrops eliminates high-value background competing noise. The hero sprite stands out distinctly against both dawn and dusk backgrounds. |
| 2 | **3D Environment Quality** | 9.6 / 10 | High tactile floor roughness ($0.82$ in Stage 1, $0.80$ in Stage 3) and triplanar flagstone textures produce crisp ground definition. Glowing curbs and arcane braziers establish clear spatial depth. |
| 3 | **2D / 3D Integration** | 9.6 / 10 | The addition of elliptical ground contact shadow decals under Player, Minions, and Bosses eliminates the floating "paper cutout" appearance, grounding sprites naturally into the 3D floor. |
| 4 | **Grounding** | 9.8 / 10 | Contact shadows placed at $Y=0.015\text{ m}$ directly anchor combatant feet to the stone surface without Z-fighting or clipping. |
| 5 | **Lighting & Ambiance** | 9.5 / 10 | Tailored dawn lighting (Stage 1) and cobalt twilight (Stage 3) paired with calibrated fog density ($0.016$–$0.020$) deliver coherent environmental mood. |
| 6 | **Depth & Hierarchy** | 9.6 / 10 | Clear separation between distant tinted panoramic backdrops ($Z=-13.5\text{ m}$), mid-ground combat geometry ($Z \approx -4\text{ m}$ to $+4\text{ m}$), and foreground gameplay plane ($Z=0.0000$). |
| 7 | **Gameplay Readability** | 9.7 / 10 | Player attack reach is instantly recognizable via the expansive curved blade arc. Combatant positions and orientation are immediately clear during rapid motion. |
| 8 | **Platform Readability** | 9.5 / 10 | Walkable stone arena boundaries are framed by runic curbs with cobalt emission, making boundary edges obvious at a glance. |
| 9 | **Composition & Camera** | 9.6 / 10 | Side-quarter view camera framing ($FOV=45^\circ$, elevation angle $22^\circ$) maintains stable framing across all 5 stages. |
| 10 | **Commercial Polish Impression** | 9.5 / 10 | The procedural HDR blade arc, grounded contact shadows, and atmospheric backdrop tints elevate the visual presentation from prototype to polished indie title. |
| | **Average Score** | **9.61 / 10** | **Exceeds Studio V3 Approval Gate ($\ge 8.5$ average, all categories $\ge 8.0$)** |

#### 3.2.2. Pre/Post Visual Comparisons Audited

1. **Stage 1 Citadel Terrace Combat:**
   - *Baseline Capture:* [`before_01_stage1_terrace_combat.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-015/captures/before/before_01_stage1_terrace_combat.png) (Castle towers glaringly white, player/enemy floating without contact shadow, dim central seal).
   - *Improved Capture:* [`after_01_stage1_terrace_combat_1280x720.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-015/captures/after/after_01_stage1_terrace_combat_1280x720.png) (Dawn aerial depth tint `Color(0.72, 0.78, 0.90)`, dark contact shadow decals beneath combatants, tactile floor roughness $0.82$, holy seal emission $3.6$).
2. **Compact Device Layout (1024×720):**
   - *Audit Capture:* [`after_02_stage1_terrace_combat_1024x720.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-015/captures/after/after_02_stage1_terrace_combat_1024x720.png).
   - *Observation:* Safe-area margins are cleanly preserved; arena boundaries remain in view; zero UI edge-clipping or camera truncation.
3. **Stage 3 Ruined Crossbow Bastion:**
   - *Baseline Capture:* [`before_02_stage3_crossbow_bastion.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-015/captures/before/before_02_stage3_crossbow_bastion.png).
   - *Improved Capture:* [`after_03_stage3_crossbow_bastion.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-015/captures/after/after_03_stage3_crossbow_bastion.png) (Cobalt dusk backdrop tint `Color(0.50, 0.60, 0.82)`, glowing arcane shards with emission $2.8$, grounded crossbow minions).
4. **Procedural Curved Slash Blade Arc:**
   - *Combat Capture:* [`after_04_player_curved_slash_combat.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-015/captures/after/after_04_player_curved_slash_combat.png).
   - *Observation:* Replaces thin cylinder with an expansive 16-segment curved crescent blade arc ($110^\circ$ sweep) with HDR emission $4.5$, distinctly telegraphing player swing reach and trajectory.

#### 3.2.3. Option C Z=0 Plane Lock Telemetry Audit
Audit of all records in [`ACTOR_Z_PRESENCE.csv`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-015/ACTOR_Z_PRESENCE.csv):
- **Total Telemetry Samples:** 1,149 samples across all 5 stages.
- **Analyzed Fields:** `pos_z` and `vel_z`.
- **Tolerance:** $|pos\_z| > 0.0001\text{ m}$ or $|vel\_z| > 0.0001\text{ m/s}$.
- **Measured Violations:** **0 violations** (100% adherence: $pos\_z = 0.0000, vel\_z = 0.0000$).

---

### 3.3. Layer 3: Play & Regression QA

#### 3.3.1. Performance & Draw Call Delta Audit
Measured under reproducible Stage 1 combat conditions across 19 frames:

| Metric | Baseline (Pre) | Improved (Post) | Variance / Delta | Impact Assessment |
|---|---|---|---|---|
| **Average Draw Calls** | 231.89 | 233.79 | +1.90 draw calls (+0.8%) | Negligible; exactly accounts for 2 active quad decals |
| **Option C Plane Lock** | 0 violations ($Z=0$) | 0 violations ($Z=0$) | Strictly preserved | 100% adherence |
| **Leaked Nodes on Exit** | 2 ObjectDB (engine exit) | 2 ObjectDB (engine exit) | Zero new leaks | Engine-level cleanup artifacts |

#### 3.3.2. Full Historical Regression Suite Verification

All milestone regression suites were re-executed against frozen commit `abcffa1`:

| Milestone Test Suite | Test File | Checks / Coverage | Result | Verdict |
|---|---|:---:|:---:|:---:|
| **V3-015 Visual & Reward Suite** | [`v3_015_visual_and_reward_verification.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/tests/v3_015_visual_and_reward_verification.gd) | 28 checks | Exit Code 0 | **PASS** |
| **V3-015 Full Campaign E2E Smoke** | [`v3_015_campaign_smoke.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/tests/v3_015_campaign_smoke.gd) | 5 stages + Victory + 2nd Deploy | Exit Code 0 | **PASS** |
| **V3-014 Stage-Clear Intermission** | [`v3_014_stage_clear_intermission_verification.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/tests/v3_014_stage_clear_intermission_verification.gd) | 41 checks | Exit Code 0 | **PASS** |
| **V3-013 Failure & Retry Smoke** | [`v3_013_failure_retry_verification.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/tests/v3_013_failure_retry_verification.gd) | 27 checks | Exit Code 0 | **PASS** |
| **V3-012 Encounter Readability** | [`v3_012_encounter_readability_verification.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/tests/v3_012_encounter_readability_verification.gd) | 29 checks | Exit Code 0 | **PASS** |
| **V3-011 Procedural Combat Audio** | [`v3_011_audio_verification.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/tests/v3_011_audio_verification.gd) | 31 checks | Exit Code 0 | **PASS** |
| **V3-010 Multi-Touch & Controls** | [`v3_010_test_touch_repro.gd`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/CLIENT/Game/tests/v3_010_test_touch_repro.gd) | 11 checks | Exit Code 0 | **PASS** |

---

## 4. Defect & Issue Tracking

### 4.1. Resolved Milestone Defects
- **`ISSUE-V3-015-001` (P1 - High):** Speculative shard fallback dictionary in stage clear intermission risked fabricating rewards.  
  *Resolution:* Removed speculative `{0: 20, 1: 25, ...}` map and default 20 fallback. When stage rewards are non-positive or unavailable, explicitly renders `"💎 REWARD UNAVAILABLE"` with subdued styling. Verified via positive and negative unit test checks.
- **`ISSUE-V3-015-002` (P2 - Medium):** Flat washed-out backdrops in Stage 1 and Stage 3 competing with combatant silhouettes.  
  *Resolution:* Applied tailored aerial depth tints (`Color(0.72, 0.78, 0.90)` and `Color(0.50, 0.60, 0.82)`) and fog tuning.
- **`ISSUE-V3-015-003` (P2 - Medium):** Primitive needle-thrust attack visual lacking combat feedback and reach readability.  
  *Resolution:* Implemented procedural 16-segment curved crescent blade arc mesh (`_generate_slash_arc_mesh`) with double-sided rendering, HDR emission $4.5$, and dynamic combo rotational sweeps.
- **`ISSUE-V3-015-004` (P2 - Medium):** Floating sprite cutouts lacking floor contact shadows.  
  *Resolution:* Added soft elliptical ground contact shadow decals ($Y=0.015, Z=0.000$) beneath Player, Minions, and Bosses.

### 4.2. Polish Backlog Items (Non-blocking)
- **`ISSUE-V3-015-005` (P2 - Polish):** Add dynamic scale pulsation to contact shadows during player jump/fall (e.g., shrinking to $0.7\times$ at peak jump height and expanding on landing) to further enhance verticality perception.
- **`ISSUE-V3-015-006` (P2 - Polish):** Implement custom blade trail ribbon shader with gradient trailing dissipation for Combo 3 finisher.
- **`ISSUE-V3-015-007` (P3 - Polish):** Add subtle spark ember particle kickup at the tip of the curved slash arc upon impact with stone ground curbs.

---

## 5. Mandatory Engineering & QA Disclosures

1. **`ANDROID_NOT_TESTED`**:  
   All visual passes, performance measurements, and smoke tests were conducted on PC Windows 11 under Godot 4.7.2 with the Compatibility (OpenGL3) renderer. Real Android device frame pacing, GPU fill rate, thermal behavior, and physical touch response have not been verified on real mobile hardware.
2. **`HUMAN_PLAYTEST_NOT_VERIFIED`**:  
   Visual comparisons and combat sweeps were verified via automated programmatic test harnesses and simulated engine inputs. Qualitative player satisfaction, combat feel over extended sessions, and subjective aesthetic enjoyment require hands-on human playtesting.
3. **`COMMERCIAL_RELEASE_READINESS_NOT_CLAIMED`**:  
   While in-game graphics, grounding shadows, blade FX, and reward integrity have improved significantly, full commercial release readiness is not claimed. Further stage environment passes, boss VFX, audio tuning, and mobile optimization remain scheduled across upcoming production milestones.

---

## 6. Milestone Gate Recommendation & Sign-Off

The independent QA audit confirms that Milestone **V3-015** satisfies all functional specifications, visual quality gates, and regression baselines. All 28 unit verification checks, 5-stage continuous campaign playthrough, and 5 historical regression test suites passed with **zero P0/P1 blockers**. Option C plane lock is strictly maintained ($Z=0.0000$ across 1,149 samples).

**Final Determination:** **`QA PASS`** — Recommended for formal approval and milestone advancement.

*Signed,*  
**`PK_QALead`**  
Independent QA Lead, ProjectKnight Studio V3  
2026-11-10
