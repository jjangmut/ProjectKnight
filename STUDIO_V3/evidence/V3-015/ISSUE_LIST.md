# V3-015 Issue List & Disclosures

## Milestone Tracking
- **Milestone ID**: V3-015
- **Objective**: In-Game Visual Quality Pass (Game First)
- **Target Branch**: `studio/v3-015-visual-gameplay-polish`

---

## Resolved Issues

### ISSUE-V3-015-001 (P1): Speculative Shard Fallback Map in Stage Clear Intermission
- **Severity**: P1 - High
- **Category**: Data Integrity / UI
- **Description**: In `side_qv_campaign.gd::_show_stage_clear_intermission()`, legacy code contained a fallback dictionary `shard_rewards = {0: 20, 1: 25, 2: 30, 3: 35, 4: 50}` and defaulted to `20` when `current_stage_instance.last_earned_shards` was missing or zero. This broke the single-source reward principle and risked fabricating reward numbers if a stage did not award shards.
- **Resolution**: Removed the speculative dictionary and default 20 fallback. When authoritative `last_earned_shards` is $\le 0$, the campaign sets `earned_shards = -1` and displays `"💎 REWARD UNAVAILABLE"` without inventing numbers. Added both positive-path and negative-path assertions in `v3_015_visual_and_reward_verification.gd`.
- **Verification**: Verified via `v3_015_visual_and_reward_verification.gd` (Checks 1–7) and 5-stage continuous smoke.

---

### ISSUE-V3-015-002 (P2): Flat Washed-Out Backdrop Competing with Combatants
- **Severity**: P2 - Medium
- **Category**: Visual Polish / Scene Hierarchy
- **Description**: Baseline audits revealed that Stage 1 and Stage 3 backdrops had raw white/grey albedos (`Color(1.0, 1.0, 1.0)`) without atmospheric aerial perspective or distance tinting. The background towers visually competed with the player and enemy silhouettes in mid-ground combat.
- **Resolution**: Configured tailored dawn aerial perspective tint (`Color(0.72, 0.78, 0.90)`) for Stage 1's `PanoramicCastleBackdrop` and cobalt dusk tint (`Color(0.50, 0.60, 0.82)`) for Stage 3's `RuinedBastionBackdrop`. Boosted environment fog and ambient lighting to clearly separate the gameplay plane ($Z=0$) from distant background geometry.
- **Verification**: Verified via paired before/after captures and `v3_015_visual_and_reward_verification.gd` (Checks 8–10, 25–26).

---

### ISSUE-V3-015-003 (P2): Primitive Needle-Thrust Attack Visual Lacking Combat Feel
- **Severity**: P2 - Medium
- **Category**: Combat Readability & Feedback
- **Description**: `SlashVisual3D` previously instantiated a thin static cylinder with uniform scaling. The attack looked like a rigid needle jab rather than an expansive curved sword swing, failing to communicate attack reach, arc, or satisfying impact.
- **Resolution**: Implemented `_generate_slash_arc_mesh()` to build a procedural 16-segment curved crescent blade ribbon. Applied double-sided rendering (`cull_mode = CULL_DISABLED`) and HDR emission energy (`4.5`). Wired dynamic rotational sweep and scale tweens for Combo 1 ($-30^\circ \to +25^\circ$), Combo 2 ($+35^\circ \to -35^\circ$), and Combo 3 ($+65^\circ \to -25^\circ$, expanding to $1.45\times$).
- **Verification**: Verified via `after_04_player_curved_slash_combat.png` and `v3_015_visual_and_reward_verification.gd` (Checks 19–22).

---

### ISSUE-V3-015-004 (P2): Floating Sprite Cutouts Lacking Floor Contact Shadows
- **Severity**: P2 - Medium
- **Category**: 2D/3D Integration & Grounding
- **Description**: 2D player and enemy sprites appeared pasted onto the 3D ground because there was zero contact shadow or ambient occlusion at their feet.
- **Resolution**: Created soft elliptical shadow quad decals (`GroundContactShadow`) positioned at $Y=0.015, Z=0.000$ beneath Player ($0.95\times 0.45\text{ m}$), Minions ($0.85\times 0.40\text{ m}$), and Bosses ($1.80\times 0.75\text{ m}$). Decals are strictly coplanar with Option C gameplay plane ($Z=0$) and smoothly disappear on death.
- **Verification**: Verified via `v3_015_visual_and_reward_verification.gd` (Checks 16–18, 23–24) and visual inspection of rendered captures.

---

## Mandatory Milestone Disclosures

1. **`ANDROID_NOT_TESTED`**:
   All visual passes, performance measurements, and smoke tests were conducted on PC Windows 11 under Godot 4.7.2 with Compatibility (OpenGL3) renderer. Real Android device frame pacing, GPU fill rate, thermal behavior, and touch response on physical mobile hardware have not been verified.

2. **`HUMAN_PLAYTEST_NOT_VERIFIED`**:
   Visual comparisons and combat sweeps were verified via automated programmatic harnesses and simulated engine inputs. Qualitative player satisfaction, combat feel over extended sessions, and subjective aesthetic enjoyment require hands-on human playtesting.

3. **`COMMERCIAL_RELEASE_READINESS_NOT_CLAIMED`**:
   While in-game graphics, grounding shadows, blade FX, and reward integrity have improved significantly, full commercial release readiness is not claimed. Further stage environment passes, boss VFX, audio tuning, and mobile optimization remain scheduled across upcoming production milestones.
