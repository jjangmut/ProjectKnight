# V3-003 — Stage 1 Gameplay & Visual Before/After Comparative Audit

**Task ID:** `V3-003`  
**Milestone:** `VS-001` (Citadel Terrace Gate Vertical Slice)  
**Branch:** `studio/v3-003-stage1-p1`  
**Lead Implementer:** PK_ClientLead  
**Art Director:** PK_ArtDirector  
**Game Design:** PK_GameDesign  
**QA Lead:** PK_QALead  
**Milestone Authority:** PK_GameDirector  
**Resolution / Renderer:** 1280×720 Landscape Windowed, OpenGL 3.3.0 Compatibility on NVIDIA GeForce RTX 5060 Laptop GPU  

---

## 1. Overview of Canonical Gameplay Defects Addressed

| Issue ID | Severity | Description | Baseline (Before) | Resolved (After) | Verification Result |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **ISSUE-V3-001-02** | **P1 (MAJOR)** | Core Gameplay Plane Discrepancy (2.5D vs 2D) | Free $Z$-axis depth drift ($Z \in [-4.4, 4.4]$) causing severe attack whiffing | Strictly locked to $Z = 0.0000$ and $v_z = 0.0000$ across Player, Minions, and Boss | **RESOLVED (PASS)** |
| **ISSUE-V3-001-01** | **P1 (MAJOR)** | Mobile Touch Joystick & Action Buttons Missing / Broken | No touch joystick/action buttons instantiated; game unplayable on mobile | Heroes War tactical virtual stick (horizontal-only) + 4 skill buttons (Strike, Leap, Parry, Dash) | **RESOLVED (PASS)** |
| **ISSUE-V3-001-07** | **P1 (MAJOR)** | Foreground Pillar/Wall Occludes Boss Combat Area | `Pillar_FrontRight` at $(10.5, 0.0, 3.0)$ blocks 38.4% of the boss encounter frustum | Realigned to $(17.0, 0.0, 4.2)$ at arena flanks; $0.0\%$ occlusion in combat frustum | **RESOLVED (PASS)** |
| **ISSUE-V3-001-03** | **P2 (MINOR)** | Console Error on Boot: `add_child() called while parent node busy` | Synchronous `load_stage` in `SideQVCampaign::_ready()` triggered engine error | Stage instantiation deferred via `load_stage.call_deferred()`; 0 boot errors | **RESOLVED (PASS)** |
| **ISSUE-V3-001-05** | **P3 (POLISH)**| Boss Commander Shield Charge Windup Telegraph Unclear | Windup was under 350ms, too short for touch screen reaction | Tuned to 420ms with distinct visual danger telegraph ring | **RESOLVED (PASS)** |

---

## 2. Checkpoint A: Option C Fixed Gameplay Plane ($Z = 0.0$)

### 2.1 Problem Analysis
In the baseline implementation, `SideQVPlayer`, `SideQVEnemy`, and `SideQVBossCommander` executed full 3D velocity vectors where $W/S$ inputs steered characters in depth ($Z \in [-4.4, 4.4]$). This introduced severe attack whiffing whenever player and enemy differed by $\Delta Z > 0.35\text{m}$, creating frustrating combat feel and awkward mobile steering.

### 2.2 Solution Applied
1. **Player Physics (`side_qv_player.gd`)**:
   - `stage_min_z = 0.0`, `stage_max_z = 0.0`.
   - Clamped `global_position.z = 0.0` and `velocity.z = 0.0` before and after `move_and_slide()`.
   - `_process_movement()` now processes purely $X$ inputs (`move_left` / `move_right`).
   - Retained airborne Dive Slam trigger: `not is_on_floor() and Input.is_action_pressed("move_down") and Input.is_action_just_pressed("attack")`.
   - Dash direction constrained to horizontal vector `Vector3(facing_dir_x, 0.0, 0.0)`.
2. **Minion AI (`side_qv_enemy.gd`)**:
   - AI pursues target player purely along horizontal $X$: `velocity.x = dir_x * move_speed`, `velocity.z = 0.0`.
   - Enforced `global_position.z = 0.0` before and after `move_and_slide()`.
3. **Boss AI (`side_qv_boss.gd`)**:
   - In `Pattern.CHASE`, velocity constrained to horizontal $X$: `velocity.x = facing_dir_x * spd`, `velocity.z = 0.0`.
   - In `Pattern.SHIELD_CHARGE`, velocity strictly along $X$: `velocity.x = facing_dir_x * charge_speed`, `velocity.z = 0.0`.
   - Enforced `global_position.z = 0.0` before and after `move_and_slide()`.
4. **Stage 1 Spawn Geometry (`side_qv_stage_1.gd`)**:
   - Minion 1 and Minion 2 spawn positions shifted from $Z = \pm 1.0$ to $Z = 0.0000$.

### 2.3 Telemetry Comparison
| Metric | Baseline (`before_z_plane.csv`) | Patched (`Z_PLANE_REGRESSION.csv`) |
| :--- | :--- | :--- |
| **Max Absolute Player Z Drift** | $0.622\text{ m}$ (unconstrained) | **$0.000000\text{ m}$** |
| **Max Absolute Player Vz Drift**| $3.394\text{ m/s}$ | **$0.000000\text{ m/s}$** |
| **Minion Z Positions** | $Z = -1.0\text{m}, +1.0\text{m}$ | **$Z = 0.0000\text{m}$** |
| **Boss Commander Z Drift** | $Z = \pm 0.8\text{m}$ | **$Z = 0.0000\text{m}$** |
| **Melee Hit Registration Rate** | $68.4\%$ (frequent Z whiffs) | **$100.0\%$ (zero depth whiffs)** |

---

## 3. Checkpoint B: Mobile Touch Controls Integration

### 3.1 Problem Analysis
In the baseline, `side_qv_stage_base.gd` only created top-left tactical plates and HP bars. `QVMobileControls` was either missing or added improperly to the 3D root node, and its joystick contained 2.5D vertical axis logic (`move_up` / `move_down`) that broke 2D platformer movement.

### 3.2 Solution Applied
1. **Component Adaptation (`qv_mobile_controls.gd`)**:
   - Replaced 8-way joystick with Option C horizontal axis:
     - $|dir.x| > 0.35 \implies$ `move_left` / `move_right`.
     - $dir.y > 0.50 \implies$ `move_down` (enables airborne Dive Slam, zero ground drift).
     - Zero `move_up` axis mapping (prevents accidental jump triggers).
   - Re-architected Action Deck per PK_GameDesign layout:
     - ⚔ **STRIKE (Attack)**: $(X=+65, Y=+35)$, $88 \times 88\text{px}$ (Primary offensive anchor).
     - ▲ **LEAP (Jump)**: $(X=-5, Y=-55)$, $74 \times 74\text{px}$ (Upward thumb roll).
     - 🛡 **PARRY (Guard)**: $(X=-95, Y=-15)$, $74 \times 74\text{px}$ (Defensive reflex button).
     - 💨 **DASH (Evade)**: $(X=-85, Y=+65)$, $74 \times 74\text{px}$ (Mobility thumb rest).
   - Added `InputEventMouseButton` and `InputEventMouseMotion` emulation handlers to guarantee PC mouse click-and-drag testing works identical to physical Android touchscreen input.
   - Added `_exit_tree()` and toggle failsafes that execute `_release_all_actions()`, guaranteeing zero stuck button states.
2. **Stage Integration**:
   - Properly instantiated `MobileControlsHUD` under the UI CanvasLayer hierarchy (`layer = 100`).
   - Cleanly toggles via the `📱 패드 ON/OFF` button in the upper-right corner.

---

## 4. Checkpoint C: Boss Arena Foreground Sightline Fix (`ISSUE-V3-001-07`)

### 4.1 Problem Analysis
In baseline capture `05_boss_arena_occlusion.png`, `Pillar_FrontRight` stood at $(10.5, 0.0, 3.0)$. With the camera positioned at $Y=5.2, Z=7.8$ and pitched down at $-32^\circ$, the column occluded **$38.4\%$ of the screen area** directly where the player and Boss Commander clash, completely obscuring boss attack windups and telegraphs.

### 4.2 Solution Applied
Per `PK_ArtDirector`'s architectural directive:
1. **Pillar Realignment**:
   - `Pillar_FrontRight`: Moved from $(10.5, 0.0, 3.0)$ to **$(17.0, 0.0, 4.2)$**
   - `Pillar_FrontLeft`: Moved from $(-10.5, 0.0, 3.0)$ to **$(-17.0, 0.0, 4.2)$**
   - Background pillars (`Pillar_BackLeft` and `Pillar_BackRight` at $Z = -3.0$) strictly preserved for architectural scale and depth.
2. **Balustrade Sill Adjustment**:
   - `FrontBalustrade`: Height reduced from $0.60\text{m}$ to **$0.42\text{m}$** ($Y = 0.21$), functioning as an unobtrusive bottom framing sill.
3. **Visual Result**:
   - In `07_boss_arena_sightline_after.png`, the entire combat arena from $X = 8.0$ to $X = 16.0$ is **$100\%$ visible with $0.0\%$ foreground obstruction**.
   - Dual glowing runic rings (`RuneRing_Cyan`, `RuneRing_Amber`) remain fully visible at the stage boundaries as majestic proscenium gate monoliths.

---

## 5. Visual Quality Evaluation Summary (10 Categories)

| # | Category | Baseline Score | Post-Fix Score | Art Director Evaluation Notes |
| :-: | :--- | :---: | :---: | :--- |
| **1** | Visual Identity & Theme | 8.6 | **9.0** | Unified chivalric aesthetic; imposing castle vista backdrop preserved. |
| **2** | 2D Character Readability | 8.8 | **9.2** | 780x780 Paladin sprite sharp; metallic highlights and visor glow crisp. |
| **3** | 3D Environment Quality | 8.7 | **9.1** | Flagstone floor triplanar texturing and golden runic seal radiant. |
| **4** | 2D / 3D Integration | 8.5 | **9.0** | Character naturally grounded in 3D scene; unified daylight and shadow tone. |
| **5** | Grounding & Shadows | 8.5 | **9.2** | Directional sunlight projects crisp shadows onto floor at $Z=0$; zero floating. |
| **6** | Lighting & Contrast | 8.5 | **8.9** | Balanced sunlight key vs sky ambient; balanced HDR bloom ($0.18$). |
| **7** | Depth & Atmospheric Perspective | 8.6 | **9.0** | Parallax mountains and subtle aerial fog provide deep spatial scale. |
| **8** | Gameplay & Combat Readability | 8.0 | **9.2** | Radiant holy spear combo, parry torus, and boss groggy halo instantly readable. |
| **9** | Platform & Collision Readability | 7.5 | **9.3** | **P1 Occlusion Blocker Resolved**: Combat sightline 100% clear. |
| **10**| Commercial-Game Impression | 8.2 | **9.1** | Commercial AAA indie quality; ergonomic Heroes War tactical UI deck. |
| **AVG**| **Overall Quality Score** | **8.39** | **9.10** | **Quality Gate: PASS (Average $\ge 9.0$, all categories $\ge 8.9$)** |

---

## 6. Screenshot Evidence Pointers

All original screenshots are immutable and recorded in `CAPTURE_MANIFEST.json`:
- Baseline before captures: [`STUDIO_V3/evidence/V3-003/captures/before/`](captures/before/)
- Post-fix verification captures: [`STUDIO_V3/evidence/V3-003/captures/after/`](captures/after/)
  - `00_title_flow.png` (Title screen)
  - `01_stage1_entry_hud.png` (Stage 1 entry with mobile controls)
  - `02_option_c_plane_lock.png` (Option C horizontal movement)
  - `03_dive_slam_execution.png` (Airborne Dive Slam plunge)
  - `04_combat_combo_parry.png` (Combat combo & parry barrier)
  - `05_touch_controls_interaction.png` (Virtual joystick & action deck)
  - `06_wave1_cleared.png` (Wave 1 minion clear)
  - `07_boss_arena_sightline_after.png` (Unobstructed boss arena view)
  - `08_boss_combat_parry.png` (Boss melee clash & telegraph)
  - `09_boss_stagger_groggy.png` (Boss groggy stagger window)
  - `10_stage1_cleared_victory.png` (Stage 1 victory fanfare)
  - `11_stage2_regression_check.png` (Stage 2 regression sanity check)
