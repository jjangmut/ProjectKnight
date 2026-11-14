# V3-024 Visual Comparison: Directional Animation Art vs V3-023 Heritage

## 1. Executive Summary
In V3-023, ProjectKnight added depth-plane movement and combat in 2.5D, but was constrained by 2D side-view sprites. The system attempted to simulate depth using:
- Artificial pitch-tilting of 2D sprites on the X axis (`sprite_3d.rotation_degrees.x = -aim_z * 9.0`).
- Ground indicator rings with pointer arrows (`HeroLocatorRing3D` and `HeroAimArrow3D`).
- Artificial sprite tilting during jump and dash maneuvers.

V3-024 completely replaces these workarounds with authentic 4-directional character sprite sheets.

---

## 2. Before / After Comparison Matrix

| Evaluation Dimension | V3-023 Heritage (Baseline) | V3-024 Authentic Directional Art | Improvement Impact |
|---|---|---|---|
| **Front Facing (+Z / South)** | Side-view sprite mechanically pitched downward by -9°; looks flat and distorted. | Authored Front Walk & Attack sheets showing full front plate armor, tabard, and downward blade cleaves. | **High**: Natural, believable frontal stance matching 2.5D camera plane. |
| **Back Facing (-Z / North)** | Side-view sprite pitched upward by +9°; character appears walking backwards into the wall. | Authored Back Walk & Attack sheets showing cape, back plate harness, and upward overhead strikes. | **High**: True three-quarter/depth immersion without silhouette breakage. |
| **Ground Arrow Dependency** | Required explicit floor directional arrows so the player could tell which way they were facing. | Floor arrow removed; character body, feet, and weapon posture clearly indicate facing direction. | **High**: Clean, professional screen presentation without immersion-breaking UI crutches. |
| **Melee Combat Synchronization** | Hitbox moved along vector, but character swing animation was locked to East/West orientation. | Swing animation matches attack vector (Front downward slash, Back upward slash, Side sweep) synchronized with `slash_visual_3d`. | **High**: Attack telegraph and hit confirmation align frame-by-frame. |
| **Enemy Flanking Readability** | Minions slid sideways when approaching the player from above or below in Z depth. | Minions turn to face South or North with dedicated frontal/back silhouettes. | **Medium**: Player immediately recognizes flanking attacks from Z depth. |
| **Boss Duel Readability** | Boss Commander charged and stomped while always facing Left or Right regardless of player position. | Boss turns to face South or North when tracking player across depth lanes during Cleave and Charge windups. | **High**: 2.5D arena combat feels dynamic and reactive. |

---

## 3. Evidence Artifacts
- `01_hero_4way_idle.png`: 4-way comparison of Hero Idle stances (West, East, South, North).
- `02_hero_4way_walk.png`: 4-way comparison of Hero Walk/Run loops.
- `03_hero_4way_attack.png`: 4-way comparison of Hero Attack animations with synchronized slash arcs.
- `04_enemy_4way_stances.png`: 4-way comparison of Melee Minions in neutral and attack poses.
- `05_boss_4way_combat.png`: 4-way comparison of Boss Commander executing Cleave, Charge, and Quake patterns.
- `ANIMATION_MATRIX.json`: Exhaustive verification log of textures, frames, and orientations.
- `FRAME_SYNC_TRACE.json`: Precision telemetry verifying 0.00 pitch tilt and exact hitbox/VFX synchronization.
