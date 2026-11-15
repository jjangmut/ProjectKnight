# V3-026-R1-NATIVE-2D — Pure 2D Combat Animation Rebuild & 3D Sprite Rollback

**Project:** ProjectKnight / Godot 4.7.2 stable / 2.5D belt-scroll / Stage 1 only  
**Branch:** `studio/v3-026-r1-rollback-broken-combo-art`  
**Base:** `studio/v3-026-combat-animation-foundation` (`9142386`)  
**Owner:** PK_GameDirector / PK_ArtDirector / PK_ClientLead / PK_QALead  
**User Decision & Mandate:**
1. **Permanent Ban of 3D-Based Sprites:** 3D-based character sprite generation and Blender-to-2D rendering are completely abolished. No 3D model conversions or new 3D models.
2. **Pure 2D Character Animation:** Rebuild combat animations using pure 2D frame animation or 2D parts animation based strictly on the authentic original 2D knight character design (`idle_v1_aligned.png`, `attack_v1_aligned.png`).
3. **Step-by-Step Gated Rollout:**
   - Step A: Roll back broken 3D combo sprites in code to the clean 2D baseline (`attack_v1_aligned.png`) and verify Godot engine stability.
   - Step B: Author Attack 1 (Combo 1) in pure 2D matching the exact armor, plume, pauldrons, cyan/white tabard, boots, and broadsword with 100% anatomical connectivity.
   - Step C: Record Attack 1 in actual gameplay at 1280x720 60 FPS.
   - Step D: Submit Attack 1 to `PK_ArtDirector` for independent graphical review. **If Art Review fails, do NOT proceed to Attack 2 and 3.**
   - Step E: Upon Art Approval of Attack 1, apply the identical 2D technique to Attack 2 and Attack 3.
4. **Preserve Combat Architecture:** Retain V3-026's deterministic combat timeline (zero frame 0 damage), scoped `HitPauseCoordinator`, audio layering, and enemy/boss timelines.

---

### Phase 1: Stable Baseline Rollback & Code Verification

1. In `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd`:
   - Point `action_hero_attack_1`, `action_hero_attack_2`, and `action_hero_attack_3` back to `TexAttack` (`attack_v1_aligned.png`, 2x2 = 4 frames) as the safe, clean fallback while new 2D assets are authored.
   - Ensure `hframes = 2, vframes = 2, total_frames = 4` with timeline mapping:
     - `windup_frames = [0]`
     - `active_frames = [1, 2]`
     - `recovery_frames = [3]`
   - Verify timeline controller cleanly steps frames without crashes, out-of-bounds frame index errors, or texture popping.
2. Run automated test suites:
   - `v3_026_timeline_verification.gd`
   - `v3_026_enemy_timeline_verification.gd`
   - `v3_024_r4_sprite_bounding_verification.gd`

---

### Phase 2: Pure 2D Attack 1 (Combo 1) Authoring

1. **Visual Consistency Criteria (Strict Alignment with `idle_v1_aligned.png`):**
   - Helmet: Rounded steel sallet/close-helmet with 5 vertical grill slots, golden ear rivet ring, and rear crest.
   - Pauldrons: Curved steel shoulder armor with polished gold/brass rim.
   - Tabard: Vibrant cyan/teal tunic with clean white outer border.
   - Belt: Brown leather belt with gold hexagonal center buckle.
   - Gauntlets & Limbs: Silver plate gauntlets, solid anatomical connection to forearms. **No floating, detached, or dislocated limbs.**
   - Broadsword: Steel diamond-cross-section blade with golden cylindrical crossguard, brown grip, and golden pommel.
   - Proportions: Exact Chibi/SD scale (~2.2 head-height ratio), 780x780 pixel cell canvas, feet baseline anchored at `(390, 700)`.
2. **Animation Frame Breakdown (Attack 1: Horizontal Slash):**
   - **Frame 0 (Anticipation / Tell):** Knight winds broadsword back, shifting weight onto rear foot; torso coils slightly back; blade angled ready to strike.
   - **Frame 1 (Swing Acceleration):** Sword begins forward arc; body uncoils; arm and shoulder lead the forward thrust.
   - **Frame 2 (Active Slash Apex):** Full horizontal extension of broadsword across target; sharp horizontal blade silhouette at chest height; weight forward.
   - **Frame 3 (Follow-through / Recovery):** Blade decelerates past target line; knight begins recentering balance back to guard stance.

---

### Phase 3: Attack 1 Gameplay Recording & Independent Art Review Gate

1. Integrate new 2D Attack 1 sheet into `side_qv_player.gd` as `TexCombo1`.
2. Record Attack 1 in actual gameplay at 1280x720 60 FPS using Godot Movie Maker.
3. Submit evidence to `PK_ArtDirector` for formal visual review against:
   - 2D character visual identity match
   - Anatomical connectivity (body/arm/weapon unity)
   - Readability against 3D castle background
   - Grounding and footline stability
4. **GATE RULE:** If Art Director score is below 8.5 or issues `ART FIX_REQUIRED`, immediately iterate on Attack 1. Do NOT proceed to Attack 2 and 3 until Attack 1 is approved.
   - **Result:** `PK_ArtDirector` approved Attack 1 with score **9.08 / 10.0** (`ART PASS`).

---

### Phase 4: Attack 2 & Attack 3 Production & Stage 1 Playthrough

1. Using the approved pure 2D pipeline:
   - **Attack 2 (Reverse Rising Slash):** Low-to-high diagonal slash arc with reverse torso rotation.
   - **Attack 3 (Overhead Ground Cleave Finisher):** Two-handed overhead raise, vertical jump impulse, committed ground smash with impact dust.
2. Full Stage 1 playthrough recording at 1280x720 60 FPS (`Stage1_Native2D_Combat_1x.mp4`).
3. Two-Key independent review:
   - `PK_QALead`: **QA PASS** (0 defects across Functional, Visual, Play QA)
   - `PK_GameDirector`: **APPROVED** (Milestone Score: 9.13 / 10.0)
4. Commit and push to `origin/studio/v3-026-r1-rollback-broken-combo-art`.
