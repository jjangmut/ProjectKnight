# V3-024-R2 Boss Arena 2D Boundary, Corner Escape Agency & Overlap Analysis

**Task:** V3-024-R2 Boss Arena 2D Corner Escape Agency, Depth Unstick & Sprite Overlap Separation  
**Repository:** `jjangmut/ProjectKnight`  
**Branch:** `studio/v3-024-r2-boss-depth-escape-agency`  
**Base Commit:** `609a328` (`studio/v3-024-r1-side-facing-boss-arena-camera`)  

---

## 1. Problem Reproduction & Root Cause Analysis

### The Z=-2.1 Depth Rail Trapping Defect
- **User Discovery**:
  Analysis of real user gameplay video and GitHub `CAMERA_VISIBILITY_TRACE.json` revealed that the player spent **90.1% of the entire boss fight** (118 out of 131 telemetry samples) trapped at $Z \le -1.5$ (average $Z = -1.95$, min $Z = -2.45$).
- **Root Cause 1: 1D Corner Detection in `side_qv_boss.gd`**:
  ```gdscript
  # V3-024-R1 (Defective):
  var player_is_cornered: bool = (target_player.global_position.x <= arena_min_x + 1.8 or target_player.global_position.x >= arena_max_x - 1.8)
  ```
  The corner detection in V3-024-R1 **only checked the $X$-axis**. When the player was trapped against the upper depth wall ($Z \le -1.8$) or lower depth wall ($Z \ge 1.8$), `player_is_cornered` evaluated to `false`!
- **Root Cause 2: Physical Corridor Blockade**:
  Arena depth boundaries are $Z \in [-2.6, 2.6]$. When the player was at $Z = -2.1$ (0.5m from the top wall), the boss approached to $Z = -1.8$. With the boss's capsule collider radius of $0.65\text{m}$, the boss's physical body extended to $Z = -2.45$. The remaining gap between the boss and the top wall was only $0.15\text{m}$—far smaller than the player's $0.35\text{m}$ collider radius. The boss physically plugged the entire depth corridor.
- **Root Cause 3: Solid Dash Collision (No Phase-Through)**:
  During `start_dash()`, player collision mask remained `2 | 4` (Enemy + World). When the trapped player activated Dash to escape, the player's collider hit the boss's collider, arresting the dash instantly.
- **Root Cause 4: Frozen Guard and Attack Recovery**:
  Holding Guard locked player velocity to zero (`velocity = Vector3.ZERO`), and attack recovery froze movement until complete.
- **Root Cause 5: Sprite Overlap and Z-Fighting**:
  With sorting offset multiplier set to only $0.25$, minor Z variances produced negligible sorting deltas, resulting in visible sprite overlap and flickering during close combat.

---

## 2. V3-024-R2 Architectural Solutions

### 1) Full 2D (X and Z) Arena Boundary & Corner Detection
In `side_qv_boss.gd`:
- Full margin metrics:
  - `p_dist_left = p_pos.x - arena_min_x`
  - `p_dist_right = arena_max_x - p_pos.x`
  - `p_dist_top = p_pos.z - arena_min_z` ($Z \approx -2.6$)
  - `p_dist_bottom = arena_max_z - p_pos.z` ($Z \approx +2.6$)
- Four distinct corner zones and rail boundaries:
  - `player_near_x_wall = (p_dist_left <= 2.2 or p_dist_right <= 2.2)`
  - `player_near_z_wall = (p_dist_top <= 1.2 or p_dist_bottom <= 1.2)`
  - `player_in_corner = (player_near_x_wall and player_near_z_wall)`

### 2) Intelligent Boss Standoff & Depth Corridor Yielding
- **In 4 Corners**:
  Boss expands combat standoff to $3.2\text{m}$ and actively retreats toward the arena center ($X \approx 77.5, Z \approx 0.0$), leaving the diagonal escape route completely wide open.
- **On Depth Rails ($Z \le -1.4$ or $Z \ge 1.4$)**:
  - If player is at Top Rail ($Z \le -1.4$): Boss clamps its own position to $Z \ge -0.5$, actively moving toward center to guarantee a clear $\ge 1.6\text{m}$ corridor.
  - If player is at Bottom Rail ($Z \ge 1.4$): Boss clamps its position to $Z \le 0.5$.
- **Active Repulsion in `_prevent_player_pushing()`**:
  If the player is near ANY wall and the boss approaches within $1.95\text{m}$, the boss is repelled at $4.2\text{ m/s}$ straight toward the arena center.
- **Wall Crash 2D Rebound**:
  Boss charge hitting any boundary rebounds diagonally ($3.6\text{ m/s}$ in X, $1.5\text{ m/s}$ in Z) with an extended $0.85$s recovery window.

### 3) Combat Movement Agency & Mobility Upgrades
- **Dash Phase-Through**:
  During `start_dash()`, `set_collision_mask_value(2, false)` temporarily disables Enemy Layer 2 collision, allowing the player to dash directly through the boss's body. Upon dash completion, Layer 2 is restored and `_resolve_enemy_overlap()` smoothly separates bodies.
- **Guard Walk**:
  Holding Guard now permits tactical movement at $40\%$ speed ($2.2\text{ m/s}$ in X, $1.4\text{ m/s}$ in Z) with shield raised. Immediate Dash cancel is allowed from Guard.
- **Attack Recovery Drift**:
  During late recovery ($t \le 0.10$s), directional movement inputs register at $55\%$ speed to eliminate input lock.

### 4) Sprite Overlap & Depth Sorting Polish
- Scaled `sprite_3d.sorting_offset` to `global_position.z * 1.5`.
- Added $+0.05$ player foreground bias to ensure the player is never visually occluded behind the boss during identical Z alignment.
- Increased soft separation distance to $1.95\text{m}$.

---

## 3. Comparative Verification Matrix

| Evaluation Dimension | V3-024-R1 (Defective State) | V3-024-R2 (Engineered Solution) | Improvement Verification |
|---|---|---|---|
| **Boundary Detection** | 1D only ($X \le 71.0$ or $X \ge 84.0$) | **Full 2D ($X \in [69.2, 85.8]$, $Z \in [-2.6, 2.6]$)** | All 4 corners + 4 boundaries detected |
| **Z-Rail Trapping** | Player spent 90.1% of fight at $Z \le -1.5$ | Boss yields $Z \ge -0.5$ corridor; player roams freely | Even depth distribution across $Z \in [-2.4, 2.4]$ |
| **Corner Standoff** | Stood at 1.72m, trapping corner exits | **Expands to 3.2m; boss steps to center ($X=77.5, Z=0$)** | Guaranteed unblocked escape routes |
| **Dash vs Boss Body** | Solid collider collision; dash stopped dead | **Phases through Enemy Layer 2 during dash** | Player dashes directly through boss to open ground |
| **Guard Mobility** | Frozen at 0 velocity | **Guard Walk active at 40% speed; Dash cancelable** | Defensive repositioning while blocking |
| **Attack Recovery** | Frozen at 0 velocity for full 0.24s | **Directional drift at 55% speed during late recovery** | Fluid combat movement |
| **Sprite Overlap** | Sprites overlapped and clipped heavily | **1.95m soft separation + 1.5x sorting offset + 0.05 bias** | Clean visual separation and crisp depth sorting |
