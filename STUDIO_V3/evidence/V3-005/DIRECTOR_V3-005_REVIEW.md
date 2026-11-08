# ProjectKnight Studio V3 — Game Director Milestone Approval Review
## Task V3-005: Stage 3 Ruined Crossbow Bastion (무너진 성벽) Real-Play Content Implementation

- **Role / Evaluator:** PK_GameDirector (Product and Milestone Authority)
- **Task ID:** V3-005
- **Milestone:** Stage 3 Vertical Slice Content & Option C Mechanics Acceptance
- **Frozen Target Commit SHA:** efa9b82b02fa3efc5a8ae0f8042d5de8c9802cd7
- **Working Branch:** studio/v3-005-stage3-crossbow-bastion
- **Evaluation Date:** 2026-11-08
- **Milestone Determination:** **APPROVED** (Desktop Godot 4.7.2 Vertical Slice Acceptance)

---

## 1. Executive Summary & Quality Bar Audit

As Game Director, I have independently reviewed and audited the deliverables, gameplay evidence, telemetry traces, and 12 synchronized 1280x720 PNG captures for Task V3-005 against commit efa9b82b02fa3efc5a8ae0f8042d5de8c9802cd7.

Stage 3 (Ruined Crossbow Bastion / 무너진 성벽) successfully evolves the ProjectKnight combat experience from Stage 1 (heavy melee fundamentals) and Stage 2 (high-mobility aerial ambush) into a disciplined tactical ranged-zoning and bullet-evasion gauntlet.

The implementation strictly honors the **Option C Z=0.0 plane lock**, ensuring that player, ranged minions, boss commander, explosive bolts, acrobatic leaps, and caltrop traps remain 100% co-planar. The previous foreground combat occlusion caused by Pillar 4 has been cleanly solved by transforming the column into a 1.1m shattered stone stub.

The task satisfies all milestone acceptance gates.

---

## 2. Deliverables & Reproducible Evidence Verification

| Deliverable Artifact | Path | Verification Findings | Status |
|---|---|---|:---:|
| **Design Acceptance Card** | STUDIO_V3/evidence/V3-005/DESIGN_ACCEPTANCE.md | Clear encounter pacing matrix across Stages 1-3, telegraph fairness timings, and counterplay mechanics verified. | **PASS** |
| **Art Visual Review** | STUDIO_V3/evidence/V3-005/ART_VISUAL_REVIEW.md | 10 visual quality categories evaluated; Pillar 4 occlusion fix analyzed; cobalt dusk lighting documented. | **PASS** |
| **Before / After Delta** | STUDIO_V3/evidence/V3-005/BEFORE_AFTER.md | Comprehensive architectural comparison of spawns, trajectories, caltrop meta tracking, and anti-tunneling swept raycast. | **PASS** |
| **Real-Input E2E Result** | STUDIO_V3/evidence/V3-005/STAGE3_REAL_INPUT_E2E_RESULT.json | 100% real GUI click + controller input E2E test passing Title -> Stage 1 -> Stage 2 -> Stage 3 -> Stage 4. | **PASS** |
| **Z Presence Telemetry** | STUDIO_V3/evidence/V3-005/ACTOR_PROJECTILE_Z_PRESENCE.csv | 729 sampled ticks confirm strictly Z=0.0000 and vz=0.0000 across all combat entities. | **PASS** |
| **Boss Timeline Telemetry** | STUDIO_V3/evidence/V3-005/BOSS_SHOT_AND_PHASE_TIMELINE.csv | Monitored HP progression: 30 -> 28 -> 26 -> 22 -> 20 -> 18 -> 15 (Phase 2) -> ... -> 0 (Defeat). | **PASS** |
| **Mechanics Fixture Result** | STUDIO_V3/evidence/V3-005/PROJECTILE_HIT_PARRY_TRAP_TEST.json | Isolated deterministic validation of Fan Volley, Backstep Leap, Caltrops, Rapid Barrage, and Guard/Parry. | **PASS** |
| **Synchronized Captures** | STUDIO_V3/evidence/V3-005/captures/ (12 PNGs) | 12 windowed PNG frames verified at exact 1280x720 resolution; visual clarity confirmed. | **PASS** |

---

## 3. Core Evaluation Dimensions

### 1) Player Experience Goals: Ranged Zoning & Bullet Telegraphs
- **Encounter Escalation:** Stage 3 provides a necessary shift in combat tempo. Rather than rushing headlong into melee, the player is forced to read projectile vectors, time leaps over floor caltrops, and utilize guard/dash invulnerability frames.
- **Minion Wave:** The two hooded Crossbow Minions maintain an authentic 5.2m standoff distance along the Z=0.0 line. Their horizontal retreat/advance AI feels organic and prevents cheap swarming.

### 2) Option C Z=0.0 Plane Believability & Cohesion
- Across 729 telemetry samples, zero depth drift was observed.
- The Fan Volley now rotates around Vector3(0, 0, 1) in the 2D X/Y vertical plane at +-18 degrees, completely curing the defect where bolts previously spread into background depth.
- Directional moonlight (TwilightMoonLight) at rotation (-45 deg, 38 deg, 0 deg) casts sharp contact shadows from 2D sprites onto the 3D ground, grounding sprites firmly without creating a 'pasted-on' look.

### 3) Telegraph Fairness & Counterplay Matrix
- **Minion Aim (0.35s):** Sprite locks to Aim Stance (Frame 1) for 0.35s. Player can interrupt with a dash-strike, deflect with a just-parry (0.15s window) to stun the shooter for 2.0s, or jump cleanly over horizontal bolts (Y=0.8m).
- **Fan Crossbow Volley (0.40s):** Floor-projected glowing red indicator line and kneeling aim pose allow positioning between the +-18 deg spread or raising the runic guard barrier.
- **Acrobatic Backstep Leap:** Executed as a pure 2D parabolic arc (vx = -8.5 m/s, vy = 8.0 m/s, vz = 0.0 m/s) with an airborne shot at the apex (t=0.26s). The 0.40s post-landing recovery delay provides a fair window to punish.
- **In-Lane Caltrop Traps:** Dropped sequentially at Z=0.0 (X offsets: +2.0, +3.2, +4.4, +5.6m). High-emission red spikes (Color(1.8, 0.3, 0.2)) make them immediately readable. A standard leap (Y >= 1.4m) bypasses them easily.
- **Phase 2 Rapid Barrage (5-Shot Burst at HP <= 15):** Triggered by an expanding floor danger ring and cobalt aura ring pulse (0.35s warning). Fired in 0.14s rapid succession.

### 4) Pillar 4 Combat Sightline Occlusion Solution
- In baseline layouts, Pillar 4 stood 3.2m tall at X=11.0, Z=+3.2, directly occluding the boss engagement area due to the camera's -32 deg pitch and elevated position.
- In commit efa9b82b02fa3efc5a8ae0f8042d5de8c9802cd7, Pillar 4 was lowered to a 1.1m ruined masonry column stub (Vector3(11.0, 0.55, 3.2) with size Vector3(1.1, 1.1, 1.1)).
- Inspection of `04_stage3_boss_spawn.png and `08_stage3_boss_backstep_shot.png proves that the stub remains well below the player and boss waistline, providing 100% unobstructed visibility across the entire boss lane (X=8.0 ~ 18.0).

---

## 4. Visual Quality Scorecard (Director Gate Evaluation)

| # | Visual Category | Score | Game Director Evaluation & Justification |
|:---:|---|:---:|---|
| 1 | **2D Character Readability** | **9.1 / 10** | Silver-armored Paladin and crimson-caped Crossbow Commander silhouettes stand out crisply against the cobalt stone ground. |
| 2 | **3D Environment Quality** | **9.0 / 10** | High-resolution flagstone flooring, weathered stone battlements, and levitating mystic stone shards with smooth bobbing motion. |
| 3 | **2D / 3D Integration** | **9.0 / 10** | Strict Z=0.0 plane lock combined with BILLBOARD_FIXED_Y creates seamless unity between 2D pixel sprites and 3D depth. |
| 4 | **Grounding & Contact Shadows** | **9.0 / 10** | Directional moonlight produces crisp, realistic diagonal ground shadows anchoring all actors and traps. |
| 5 | **Lighting & Cobalt Ambiance** | **9.1 / 10** | Atmospheric cobalt dusk fog (0.015 density) contrasted with high-emission warm orange and azure HDR bloom sparks. |
| 6 | **Depth & Spatial Hierarchy** | **9.0 / 10** | Clear 3-tier layering: foreground ruined pillar stub (Z=+3.2), gameplay combat plane (Z=0.0), distant backdrop panorama (Z=-6 ~ -20). |
| 7 | **Gameplay & Combat Readability** | **9.2 / 10** | 0.40s floor aim lines, bright cyan projectile cores, red glowing caltrops, and cobalt aura pulse eliminate gameplay ambiguity. |
| 8 | **Platform & Battlement Readability**| **9.0 / 10** | Clear battlements define arena perimeter; walkable floor bounds are immediately intuitive. |
| 9 | **Composition & Camera Presentation**| **9.0 / 10** | Stable -32 deg side-quarter camera tracking; top Tactical Unit HUD frames the scene cleanly; zero foreground occlusion. |
| 10| **Commercial-Game Impression** | **9.1 / 10** | Ornate boss health bar, stylized defeat fanfare (+30 Soul Shards), and seamless transition to Stage 4 convey commercial polish. |
|---|---|:---:|---|
| **TOTAL** | **OVERALL AVERAGE SCORE** | **9.05 / 10** | **PASS** (Approval Gate: Average >= 8.50, All Categories >= 8.00) |

---

## 5. Technical Observations & Polish Backlog (P2)

The milestone passes all critical acceptance gates, but the following minor edge cases are noted for the polish backlog:
1. **[P2] Caltrop Trap set_monitoring Deferred Call:**
   - In side_qv_caltrop_trap.gd line 93, monitoring = false is called directly inside _on_body_entered. Godot engine warns: Function blocked during in/out signal. Use set_deferred("monitoring", true/false).
   - *Fix Request for Polish Pass:* Change line 93 to set_deferred("monitoring", false).
2. **[P2] Caltrop Flash Transform Hierarchy:**
   - In side_qv_caltrop_trap.gd line 138, flash.global_position is accessed when flash is created. Ensure flash.position or add_child occurs safely before querying global transforms.
3. **[P3] Isolated Test Camera Lead:**
   - In v3_005_stage3_projectile_and_plane.gd, screenshots 05, 06, 09 were captured while camera remained anchored to the starting player position (X=-8.0). In future isolated test scripts, the camera target or position should explicitly pan to the action focal point before capturing. (Note: E2E playthrough captures 01, 02, 03, 04, 07, 08, 10, 11 contain complete in-frame character action).

---

## 6. Regression Verification

All previous milestone regressions were independently executed and passed with zero errors:
1. tests/v3_003_real_touch_ui.gd: **PASS** (Exit Code: 0) — Real engine-routed touch events and multi-touch safety confirmed.
2. tests/v3_003_boss_charge_timing.gd: **PASS** (Exit Code: 0) — Boss charge windup measured at 0.4333s (>= 0.42s), 0.0m displacement.
3. tests/v3_004_stage2_plane_and_combat.gd: **PASS** (Exit Code: 0) — Stage 2 Beastwood Option C plane and Chieftain mechanics verified.
4. tests/v3_005_stage3_projectile_and_plane.gd: **PASS** (Exit Code: 0) — Stage 3 isolated projectile, trap, guard, and plane fixture verified.
5. tests/v3_005_stage3_real_input_e2e.gd: **PASS** (Exit Code: 0) — Full Title -> Stage 1 -> Stage 2 -> Stage 3 -> Stage 4 playthrough verified.

---

## 7. Scope Discipline & Final Milestone Determination

- **Target Commit SHA:** efa9b82b02fa3efc5a8ae0f8042d5de8c9802cd7
- **Milestone Scope:** Desktop Godot 4.7.2 Stage 3 Vertical Slice
- **Android Physical Hardware:** NOT_TESTED (honestly declared)
- **Commercial Game Release:** NOT_APPROVED (Vertical slice acceptance only)
- **Final Determination:** **APPROVED**
