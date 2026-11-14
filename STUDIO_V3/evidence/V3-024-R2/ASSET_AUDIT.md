# V3-024-R2 Asset & Collision Geometry Audit

## 1. Character Dimensions and Collision Geometry

### Hero (Player Knight)
- **Visual Scale**: Calibrated to ~1.77m human scale (`pixel_size = 0.00282`).
- **Collision Capsule**:
  - `radius = 0.35m`
  - `height = 1.70m`
  - `col.position.y = 0.85m`
  - `collision_layer = 1` (Player)
  - `collision_mask = 2 | 4` (Enemy | World) — dynamically drops Layer 2 during Dash.
- **Sorting Offset**:
  - `sprite_3d.sorting_offset = clampf(global_position.z * 1.5 + 0.05, -3.0, 3.0)`

### Boss Commander (Gate Sanctuary Guardian)
- **Visual Scale**: 2.45m tall (`pixel_size = 0.0082`).
- **Collision Capsule**:
  - `radius = 0.65m`
  - `height = 2.40m`
  - `col.position.y = 1.20m`
  - `collision_layer = 2` (Enemy)
  - `collision_mask = 1 | 4` (Player | World)
- **Sanctuary Arena Boundaries**:
  - $X \in [69.2, 85.8]$
  - $Z \in [-2.6, 2.6]$
- **Sorting Offset**:
  - `sprite_3d.sorting_offset = clampf(global_position.z * 1.5, -3.0, 3.0)`

### Melee Grunt & Elite Shield Knight
- **Collision Capsule**:
  - `radius = 0.45m`
  - `height = 1.80m`
- **Sorting Offset**:
  - `sprite_3d.sorting_offset = clampf(global_position.z * 1.5, -3.0, 3.0)`

---

## 2. Spatial Corridor Math & Separation Clearances

- **Combined Collision Radii**: $r_{player} + r_{boss} = 0.35 + 0.65 = 1.00\text{m}$.
- **Soft Repulsion Radius**: $1.95\text{m}$ (maintains $\ge 0.95\text{m}$ visual separation between sprite boundaries).
- **Depth Rail Clearance**:
  - Arena Half-Depth: $2.6\text{m}$.
  - Top Wall at $Z = -2.6\text{m}$.
  - When Player is at $Z \le -1.4\text{m}$, Boss is clamped to $Z \ge -0.5\text{m}$.
  - Open Clearance Corridor: $|-1.4 - (-0.5)| = 0.9\text{m}$ to $1.9\text{m}$ of unimpeded Z-space.
- **Corner Standoff Distance**: $3.2\text{m}$ (exceeds boss blade reach of $1.72\text{m}$ and allows diagonal escape).
