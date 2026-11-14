# V3-024 Animation Asset & Technical Manifest

## 1. Scope & Technical Architecture
ProjectKnight V3-024 introduces authentic 4-directional 2.5D character rendering and animation synchronization. It resolves defect `DIRECTIONAL_ART_MISSING` (tracked since V3-023-L1) by removing artificial pitch-tilting (`rotation_degrees.x = -aim_z * 9.0`) and floor directional arrows, replacing them with hand-crafted, pixel-aligned sprite sheets for South (+Z Front) and North (-Z Back) orientations, complementing East and West side views.

---

## 2. Sprite Asset Inventory & Technical Specifications

| Actor | Action / Direction | Source File | Cell Size | Foot Anchor (Y) | Grid (Col x Row) | Pixel Size (3D World) |
|---|---|---|---|---|---|---|
| **Hero (Paladin)** | Side Idle (East/West) | `player_frames/idle_v1_aligned.png` | 780x780 | 700 | 2x2 (4 frames) | 0.00282 |
| **Hero (Paladin)** | Side Run (East/West) | `player_frames/run_v2_aligned.png` | 780x780 | 700 | 3x2 (6 frames) | 0.00282 |
| **Hero (Paladin)** | Side Attack (East/West) | `player_frames/attack_v1_aligned.png` | 780x780 | 700 | 2x2 (4 frames) | 0.00282 |
| **Hero (Paladin)** | Front Walk / Idle (+Z) | `player_frames/directional/hero_front_walk_aligned.png` | 780x780 | 700 | 2x2 (4 frames) | 0.00282 |
| **Hero (Paladin)** | Front Attack Combo (+Z) | `player_frames/directional/hero_front_attack_aligned.png` | 780x780 | 700 | 2x2 (4 frames) | 0.00282 |
| **Hero (Paladin)** | Back Walk / Idle (-Z) | `player_frames/directional/hero_back_walk_aligned.png` | 780x780 | 700 | 2x2 (4 frames) | 0.00282 |
| **Hero (Paladin)** | Back Attack Combo (-Z) | `player_frames/directional/hero_back_attack_aligned.png` | 780x780 | 700 | 2x2 (4 frames) | 0.00282 |
| **Hero (Paladin)** | Guard / Shield Stance | `player_frames/guard_v1_aligned.png` | 780x780 | 700 | 3x1 (3 frames) | 0.00282 |
| **Hero (Paladin)** | Jump / Air Dive | `player_frames/jump_v1.png` | 780x780 | 700 | 3x1 (3 frames) | 0.00282 |
| **Hero (Paladin)** | Dodge / Dash | `player_frames/dodge_v1.png` | 780x780 | 700 | 2x2 (4 frames) | 0.00282 |
| **Hero (Paladin)** | Hurt / Recoil | `player_frames/hurt_v1.png` | 780x780 | 700 | 3x1 (3 frames) | 0.00282 |
| **Hero (Paladin)** | Defeat / Death | `player_frames/death_v1.png` | 780x780 | 700 | 2x2 (4 frames) | 0.00282 |
| **Melee Minion** | Side Walk / Attack (E/W) | `enemy_frames/melee_v1.png` | 512x512 | 489 | 3x2 (6 frames) | 0.00310 |
| **Melee Minion** | Front (+Z) & Back (-Z) | `enemy_frames/directional/melee_directional_aligned.png` | 512x512 | 489 | 3x2 (6 frames) | 0.00310 |
| **Boss Commander** | Side Walk / Combat (E/W) | `enemy_frames/boss_commander_v2.png` | 300x298 | 294 | 4x3 (12 frames) | 0.00820 |
| **Boss Commander** | Side Defense / Stun | `enemy_frames/boss_commander_v2_defense.png` | 300x298 | 294 | 4x3 (12 frames) | 0.00820 |
| **Boss Commander** | Front (+Z) & Back (-Z) | `enemy_frames/directional/boss_directional_aligned.png` | 300x298 | 294 | 3x2 (6 frames) | 0.00820 |

---

## 3. Pivot Alignment & Anti-Jitter Pipeline
All directional sheets were processed with the programmatic sprite pipeline tool (`tools/sprite_pipeline/build_directional_sheet.py`):
1. **Background Removal**: Border-connected flood-fill and enclosed alpha pocket cleaning down to 32-bit RGBA.
2. **Component Filtering**: Small stray noise particles removed, preserving armor crests, capes, and weapon silhouettes.
3. **Leg/Foot Pivot Grounding**: Automatic anchor detection locks the lowest contact pixels to the exact target baseline ($Y = 700$ for Hero, $Y = 489$ for Minion, $Y = 294$ for Boss).
4. **Uniform Scale**: All frames within each sheet share identical scale, preventing character resizing during directional transitions.

---

## 4. Frame Synchronization Verification
- **Melee Attack Timing**:
  - Frame 0 (Progress 0.00 - 0.25): Windup stance, weapon raised. Hitbox inactive.
  - Frame 1 (Progress 0.25 - 0.65): Full blade swing, `slash_visual_3d` visible at peak arc. Hitbox active, damage checked.
  - Frame 2/3 (Progress 0.65 - 1.00): Recovery and follow-through. Hitbox de-registered.
- **Directional Alignment**:
  - When attacking in +Z (South), `slash_visual_3d` sweeps across the front quadrant with a 68-degree tilt for maximum readability from the side-quarter camera.
  - When attacking in -Z (North), `slash_visual_3d` sweeps into depth.
  - Side attacks sweep along X with `facing_dir_x` flipping.
