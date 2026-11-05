# V3-001 — Gameplay Plane Design Decision

**Task ID:** `V3-001`  
**Date:** 2026-11-06  
**Audited Source Revision:** `studio/v3-001-playable-baseline@a71223615d0b77e36dd85edb24e138fc67ecc140`  
**Decision Authority:** PK_GameDirector  

---

## 1. Background & Context

In the initial ProjectKnight project specification, the game was defined as:
```text
3D Background + 2D Character + Side Scrolling Action
Target: Mobile Android 1280x720 Landscape
Fixed Side-Scrolling Gameplay Plane
```

However, the current implementation in `CLIENT/Game/scripts/side_quarter_view/`:
- `SideQVPlayer.gd` is a `CharacterBody3D` with **free 3D belt-scrolling movement**:
  - Horizontal movement: $X$ (`move_speed_x: 7.5 m/s`)
  - In/out depth movement: $Z$ (`move_speed_z: 4.8 m/s`) across depth lane $Z \in [-4.4, 4.4]$
  - Vertical movement: $Y$ (`jump_velocity: 6.8 m/s`, `gravity: 18.0 m/s²`)
- `SideQVCamera.gd` uses a side-quarter view camera with **-32° pitch tilt**.
- `SideQVEnemy.gd` and `SideQVBoss.gd` pathfind and attack across both $X$ and $Z$.

This audit formally measures and compares the three gameplay plane architectures to establish the definitive production direction for Milestone VS-001 and Stages 1–5.

---

## 2. Comparative Evaluation Matrix

| Metric / Dimension | Option A: Strict 2D Side-Scroller | Option B: Current 2.5D Belt-Scroller | Option C: 2.5D Visuals + 2D Plane Lock |
| :--- | :--- | :--- | :--- |
| **Motion Model** | Pure $X$ (left/right) + $Y$ (jump); $Z = 0$ strictly locked | Free $X$ (left/right) + $Z$ (depth) + $Y$ (jump) | 3D environment rendered, but player & enemy physics locked to single $Z$ plane |
| **Camera View** | Pure Side-scroller ($0^\circ$ pitch, orthographic or perspective) | Side Quarter-View ($-32^\circ$ pitch, $0^\circ$ yaw) | Side-angle with subtle perspective depth ($-15^\circ \sim -25^\circ$ pitch) |
| **Combat Readability** | **Highest (9.5/10)**: Hitbox overlap is purely 2D $(X, Y)$; zero Z-axis whiffing | **Moderate (6.5/10)**: Attacks frequently whiff if player/enemy differs by $\Delta Z > 0.4\text{m}$ | **High (9.0/10)**: All hitboxes resolved on common 2D combat plane; zero Z-whiffing |
| **Tactile Feel & Rhythm** | Crisp action platformer (Dead Cells / Hollow Knight style) | Belt-scroll brawler (Streets of Rage / DFO style) | High-speed parry & slash platformer with cinematic 3D depth |
| **Mobile Controls (Touch)** | **Optimal**: 4-button layout (Left, Right, Jump, Attack, Dash) | **High Friction**: Requires 8-way floating virtual joystick, prone to input drift on glass | **Optimal**: Clean 4-button mobile layout; zero depth steering errors |
| **3D Environment Reuse** | Requires flattening or discarding 3D depth arenas | Reuses existing 3D flagstone arenas, curbs, and pillars | **100% Reuse**: Retains all existing 3D meshes, runic circles, dynamic lighting, and background vistas |
| **Enemy AI & Boss Patterns** | Requires rewriting 3D pathfinding to 2D platformer AI | AI already exists, but boss charge often misses off-axis | Simplifies AI to linear spatial pressure, telegraphs become 100% readable |
| **Rework Risk & Cost** | **High**: Major rework of existing 5 3D stages and collision boundaries | **Low initially, High ongoing**: Hitbox tuning across depth, mobile joystick ergonomics | **Low / Minimal**: Clamp $Z=0$ in `_physics_process()`, adjust camera framing |

---

## 3. Deep-Dive Tradeoff Analysis

### Option A: Strict 2D Side-Scroller
- **Advantages:** Complete alignment with classic 2D action platformers. Simplest mobile controls.
- **Drawbacks:** Discards the unique aesthetic appeal of the 3D environments, flagstone floors, and runic seals created in Stages 1–5. High cost to convert existing 3D stages into 2D collision geometry.

### Option B: Current 2.5D Belt-Scroller
- **Advantages:** Allows dodging around boss attacks in depth ($Z$-axis evasion). Retains current codebase as-is.
- **Drawbacks:** On mobile touchscreens (1280x720), steering in depth while trying to execute 0.14s just-parry and attack combos introduces severe input friction. Furthermore, in the side-quarter camera angle (-32° pitch), character vertical screen position changes when moving in $Z$, confusing jump timing and telegraph recognition.

### Option C: 2.5D Visual Environment with Fixed 2D Gameplay Plane *(Recommended)*
- **Advantages:**
  1. **Visual Richness:** Preserves 100% of the 3D background architecture, distant panoramic castle vista, real-time sunlight shadows, and glowing runic decals.
  2. **Combat Precision:** Locking gameplay movement to a single $Z$ plane ($Z = 0$) eliminates all Z-axis attack whiffing and ensures that melee collisions, hitboxes, and telegraphs are crisp, punchy, and readable.
  3. **Mobile Ergonomics:** Perfectly matches the 1280x720 mobile landscape touch layout. Eliminates the need for a cumbersome 8-way analog stick.
  4. **Smooth Transition:** Requires minimal technical changes: lock player and enemy $Z$-velocity to 0, clamp $Z=0.0$, and refine camera framing.

---

## 4. Director Decision Verdict

**Decision:** **OPTION C — Visually 2.5D with Fixed 2D Gameplay Plane**

### Formal Directive:
1. In subsequent implementation milestones (beginning with `V3-003`), client programming (`PK_ClientLead`) shall constrain player and enemy motion to the primary $X/Y$ combat plane ($Z=0.0$).
2. The 3D environments, flagstone floor, runic seals, parallax mountains, and DirectionalLight3D real-time shadows shall be strictly preserved and expanded.
3. Mobile controls shall be designed around crisp horizontal movement and dedicated action buttons (Jump, Attack, Guard/Parry, Dash).
4. No code modifications shall be made during this audit task (`V3-001`). Implementation will take place in authorized follow-up tasks.

---

**Signed:**  
*PK_GameDirector — Product & Milestone Authority*  
*ProjectKnight Studio V3*
