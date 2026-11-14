# V3-024 Character Asset & Directional Animation Audit

## 1. Baseline State (V3-023 Heritage)
In V3-023, ProjectKnight established a 2.5D X/Z gameplay plane, but directional animation art was explicitly tracked as missing (`DIRECTIONAL_ART_MISSING` in `V3-023-L1`). Characters utilized 2D side-view sprite sheets mirrored via `Sprite3D.flip_h` for left/right movements, while +Z (front/down) and -Z (back/up) motions relied on:
- Pitch tilting `Sprite3D.rotation_degrees.x = -aim_z * 9.0`
- 3D floor indicator rings (`HeroLocatorRing3D`) and 3D pointer arrows (`HeroAimArrow3D`)
- X-axis tilted slash VFX planes (`slash_visual_3d`)

As requested in the user prompt and `STUDIO_V3/tasks/V3-024.md`, temporary ground arrows and 3D tilting do NOT substitute for true directional 2.5D character sprite art. V3-024 replaces these placeholders with dedicated, authored 4-directional sprite assets.

## 2. Character Specification & Directional Matrix

### Hero (Player Knight)
- **Cell Dimension**: Uniform 780x780 pixels per cell, feet pivot at Y=700.
- **Side Views (East / West)**:
  - Idle: `res://assets/player_frames/idle_v1_aligned.png` (2x2)
  - Run: `res://assets/player_frames/run_v2_aligned.png` (3x2)
  - Attack: `res://assets/player_frames/attack_v1_aligned.png` (2x2)
  - Guard / Parry: `res://assets/player_frames/guard_v1_aligned.png` (3x1)
  - Jump: `res://assets/player_frames/jump_v1.png` (3x1)
  - Dodge / Dash: `res://assets/player_frames/dodge_v1.png` (2x2)
  - Hurt: `res://assets/player_frames/hurt_v1.png` (3x1)
  - Death: `res://assets/player_frames/death_v1.png` (2x2)
- **Front Views (South / +Z Direction)**:
  - Walk & Idle: `res://assets/player_frames/directional/hero_front_walk_aligned.png` (2x2)
  - Attack Combo: `res://assets/player_frames/directional/hero_front_attack_aligned.png` (2x2)
- **Back Views (North / -Z Direction)**:
  - Walk & Idle: `res://assets/player_frames/directional/hero_back_walk_aligned.png` (2x2)
  - Attack Combo: `res://assets/player_frames/directional/hero_back_attack_aligned.png` (2x2)

### Melee Grunt (Bronze Axeman)
- **Cell Dimension**: Uniform 512x512 pixels per cell.
- **Side Views (East / West)**: `res://assets/enemy_frames/melee_v1.png` (3x2)
- **Front & Back Views (South / North)**: `res://assets/enemy_frames/directional/melee_directional_aligned.png` (3x2)

### Boss Commander
- **Cell Dimension**: 300x298 pixels per cell.
- **Side Views (East / West)**: `res://assets/enemy_frames/boss_commander_v2.png` (4x3), `res://assets/enemy_frames/boss_commander_v2_defense.png` (4x3)
- **Front & Back Views (South / North)**: `res://assets/enemy_frames/directional/boss_directional_aligned.png` (3x2)

## 3. Directional State Mapping Policy
To seamlessly transition between directional sprites without oscillation, the animation controller maps the normalized 2D movement/aim vector `(dx, dz)` into 4 primary quadrants with hysteresis:
- `abs(dx) >= abs(dz)`: Side facing (East if `dx > 0`, West via `flip_h` if `dx < 0`)
- `dz > abs(dx)`: Front facing (South / +Z toward camera)
- `dz < -abs(dx)`: Back facing (North / -Z into depth)
