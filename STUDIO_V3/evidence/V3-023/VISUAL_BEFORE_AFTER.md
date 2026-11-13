# V3-023 Stage 1 Gameplay Polish — Visual Before / After Comparison

## Overview
- **Task**: `V3-023` (`studio/v3-023-stage1-gameplay-polish`)
- **Comparison Scope**: V3-022-R1 baseline captures (`before_v3_022_r1_*.png`) vs. V3-023 polished in-game captures (`after_v3_023_*.png`) inside `STUDIO_V3/evidence/V3-023/captures/`.

---

## 1. Directional Slash Alignment & Floor Ring Cleanup (`V3-023-D1`)

| Aspect | Before (`V3-022-R1`) | After (`V3-023`) |
| :--- | :--- | :--- |
| **Capture Files** | `captures/before_v3_022_r1_melee_stacking.png` | `captures/after_v3_023_attack_dir_right.png`<br>`captures/after_v3_023_attack_dir_left.png`<br>`captures/after_v3_023_attack_dir_up_z_minus.png`<br>`captures/after_v3_023_attack_dir_down_z_plus.png`<br>`captures/after_v3_023_attack_dir_diag.png` |
| **Visual Observation** | Slash arc only appeared in the vertical X plane; landing from a jump with `golem_pauldrons` spawned an oversized solid yellow/white `TorusMesh` under the hero's feet. | Every attack direction (`X+`, `X-`, `Z-`, `Z+`, diagonal) aligns the golden `HeroAimArrow3D` on the cyan `HeroLocatorRing3D`, the 3D `attack_area_3d` hitbox, and the `TexSlashArc` crescent (`slash_visual_3d`), which tilts horizontally (`-76°`) when slicing along `Z-` or `Z+`. Landing shockwaves now use the textured `TexShockwaveRing` decal instead of a solid yellow torus. |
| **Art Limitation Note** | N/A | Flagged `DIRECTIONAL_ART_MISSING`: 2D character sprite sheet only has side views (`flip_h`), compensated by the 3D locator ring, golden aim arrow, and 8-way 3D slash plane. |

---

## 2. Melee Spacing, Depth Sorting & Damage Popup Readability (`V3-023-D2`)

| Aspect | Before (`V3-022-R1`) | After (`V3-023`) |
| :--- | :--- | :--- |
| **Capture Files** | `captures/before_v3_022_r1_melee_stacking.png` | `captures/after_v3_023_zone1_courtyard_spacing.png` |
| **Visual Observation** | Hero and 2–3 enemies stacked within `0.2m–0.4m` at identical coordinates; oversized 42pt/58pt damage numbers piled on top of the sprites, hiding enemy windups. | Minimum player-enemy distance (`>= 1.10m`) and inter-enemy spacing (`>= 1.25m`) keep silhouettes readable; dynamic `Sprite3D.sorting_offset = Z * 0.25` prevents sprite plane flickering; damage popups are smaller (`24pt`/`32pt`), staggered, and capped at `<= 4`. |

---

## 3. Encounter Zone Differentiation (`V3-023-D4`)

| Encounter Zone | Before (`V3-022-R1`) | After (`V3-023`) |
| :--- | :--- | :--- |
| **Zone 1: Outer Courtyard (`X = -15..12`)** | `captures/before_v3_022_r1_corridor_1.png` — Generic grey stone corridor identical to later waves. | `captures/after_v3_023_zone1_courtyard_spacing.png` — Cool blue-slate floor overlay (`Zone1_CourtyardSlateOverlay`) with a physical `Zone1_CourtyardDivider` pillar (`StaticBody3D` Layer 4) creating distinct Z lanes and `0.24s` `EnemyWindupRing3D` telegraphs. |
| **Zone 2: Crossfire Bastion (`X = 12..38`)** | `captures/before_v3_022_r1_corridor_1.png` — Unbroken grey corridor with no cover or lane funneling. | `captures/after_v3_023_zone2_bastion_rampart.png` — Warm amber torchlit floor (`Zone2_BastionAmberOverlay`) with North and South timber-and-iron siege barricades (`Zone2_SiegeBarricade_North/South`) funneling the player into the center channel against Heavy Shield Knights and Crossbowmen (`CrossbowAimLaser3D`). |
| **Zone 3: Royal Approach (`X = 38..68`)** | `captures/before_v3_022_r1_corridor_2.png` — Same grey stone corridor repeated before the boss gate. | `captures/after_v3_023_zone3_royal_terrace.png` — Crimson royal runner carpet (`Zone3_RoyalCrimsonCarpet`) bordered by gold trims and marble colonnade plinths (`Zone3_ColonnadePlinth_North/South`), where dual Heavy Shield Knights enforce Z-lane flanking around their frontal shield bash counters. |

---

## 4. Boss Commander Duel Spacing & Frontal Shield Counterplay (`V3-023-D5`)

| Aspect | Before (`V3-022-R1`) | After (`V3-023`) |
| :--- | :--- | :--- |
| **Capture Files** | `captures/before_v3_022_r1_boss_overlap.png` | `captures/after_v3_023_boss_duel_spacing.png` |
| **Visual Observation** | Hero stood inside the Boss Commander's torso (`dist < 0.5m`), melting the boss in `6.5s` (`28 HP`) before all 3 patterns executed. | Boss (`84 HP`, `30 Poise`) and hero maintain clear duel spacing (`min_dist >= 1.45m` enforced, `1.26m` minimum observed during lunges). Boss raises a golden `BossFrontalShieldVFX` barrier after 2 frontal hits, forcing the hero to flank across Z lanes and engage all 3 patterns (`TRIPLE_CLEAVE`, `SHIELD_CHARGE`, `QUAKE_RING`) over a `~15s` duel (14.95s in verification run, 11.78s in the recorded video run). |

---

## 5. Victory Camera Framing & Kneeling Boss Aftermath (`V3-023-D6`)

| Aspect | Before (`V3-022-R1`) | After (`V3-023`) |
| :--- | :--- | :--- |
| **Capture Files** | `captures/before_v3_022_r1_empty_victory.png` (`frame_055.png`) | `captures/after_v3_023_victory_seq_1.png`<br>`captures/after_v3_023_victory_seq_2.png`<br>`captures/after_v3_023_victory_seq_3.png`<br>`captures/after_v3_023_victory_seq_4.png` |
| **Visual Observation** | Boss was freed (`queue_free()`) and the player walked off-screen to the right (`X > 91`), leaving the camera staring at an empty stone floor with no hero or boss visible. | Player locks into `State.VICTORY` (`enter_victory_pose()`) `2.35m` from the kneeling defeated boss (`BossTextureDefense` frame 4) at foreground `Z in [0.35, 0.85]`. The camera centers smoothly between both characters, and the `STAGE 1 CLEARED!` summary banner sits cleanly at the top (`y = 42`) without covering either character across all 4 aftermath frames. |
