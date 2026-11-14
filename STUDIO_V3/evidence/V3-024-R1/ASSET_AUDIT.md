# V3-024-R1 Character Asset & Belt-Scroll Facing Architecture Audit

## 1. Architectural Evolution: V3-024 to V3-024-R1
- **V3-024 Initial Direction**:
  Authored 4-way sprites (Front/Back/Left/Right). However, during gameplay testing, swapping to distinct front-facing (+Z) and back-facing (-Z) sprites during depth navigation proved jarring and unnatural in a side-scrolling quarter-view environment.
- **V3-024-R1 Directive**:
  Adopts classic 2.5D belt-scrolling conventions (e.g. Streets of Rage, Dungeon & Fighter, Dragon's Crown, Guardian Heroes). Characters strictly maintain horizontal facing (`facing_dir_x`: 1.0 = Right, -1.0 = Left) using `flip_h = (facing_dir_x < 0)`.
  When translating along the Z-axis (up/down in depth), characters maintain their side silhouettes, playing authored side walk/run/idle/attack cycles smoothly across the 3D ground plane.

## 2. Character Specification & Active Asset Register

### Hero (Player Knight)
- **Cell Dimension**: Uniform 780x780 pixels per cell, feet pivot at Y=700.
- **Side Spritesheets (Active Gameplay)**:
  - Idle: `res://assets/player_frames/idle_v1_aligned.png` (2x2, 4 frames)
  - Run: `res://assets/player_frames/run_v2_aligned.png` (3x2, 6 frames)
  - Attack: `res://assets/player_frames/attack_v1_aligned.png` (2x2, 4 frames, 3-stage combo)
  - Guard / Parry: `res://assets/player_frames/guard_v1_aligned.png` (3x1, 3 frames)
  - Jump: `res://assets/player_frames/jump_v1.png` (3x1, 3 frames)
  - Dodge / Dash: `res://assets/player_frames/dodge_v1.png` (2x2, 4 frames)
  - Hurt: `res://assets/player_frames/hurt_v1.png` (3x1, 3 frames)
  - Death: `res://assets/player_frames/death_v1.png` (2x2, 4 frames)
- **Floor Locator Overlay**:
  - Distracting 3D direction pointer arrow (`hero_aim_arrow_3d`) and oversized ring (`hero_locator_ring_3d`) disabled.
  - Positioning communicates via grounded character silhouette and `GroundContactShadow` decal ($0.95 \times 0.45\text{m}$, alpha 0.55).

### Melee Grunt (Bronze Axeman)
- **Cell Dimension**: Uniform 512x512 pixels per cell.
- **Active Gameplay Sheet**: `res://assets/enemy_frames/melee_v1.png` (3x2, 6 frames: walk 0..2, recoil/attack 3..5).
- **Facing**: `sprite_3d.flip_h = (diff.x < 0.0)`.

### Heavy Shield Knight (Elite Knight)
- **Active Gameplay Sheet**: `res://assets/enemy_frames/melee_v1.png` + attached 3D Gothic Heater Shield.
- **Facing**: Shield socket and body mirror with horizontal facing (`flip_h`).

### Boss Commander
- **Cell Dimension**: 300x298 pixels per cell.
- **Active Gameplay Sheets**:
  - Normal Stance / Attack: `res://assets/enemy_frames/boss_commander_v2.png` (4x3)
  - Guard Stance / Heavy Armor: `res://assets/enemy_frames/boss_commander_v2_defense.png` (4x3)
- **Facing**: `sprite_3d.flip_h = (facing_dir_x < 0.0)`.
