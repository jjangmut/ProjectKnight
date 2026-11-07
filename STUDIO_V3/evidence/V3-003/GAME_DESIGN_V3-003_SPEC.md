# V3-003 — Game Design Specification & Review
## Stage 1 Gameplay P1 Improvement & 2D Combat Experience Design

**Document ID:** `GD-V3-003-SPEC-01`  
**Governing Task:** `V3-003` (Stage 1 Actual Gameplay P1 Fix & Playable Vertical Slice)  
**Branch:** `studio/v3-003-stage1-p1`  
**Author:** `PK_GameDesign` (Lead Game Designer / Player Experience Owner)  
**Date:** 2026-11-08  
**Status:** **DESIGN CRITERIA SPECIFIED & BASELINE FIX_REQUIRED FOR IMPLEMENTATION**  

---

## 1. Executive Summary & Design Scope

In accordance with `V3-003.md`, `AGENTS.md`, and the Game Quality Director Standard, this document establishes the definitive player experience criteria, combat timing rules, mobile ergonomics, and boss pacing specifications for Stage 1.

### Canonical Defect Scope Addressed:
1. **`ISSUE-V3-001-02` (Option C Gameplay Plane Lock)**:
   - Migration from free 2.5D belt-scroller ($Z \in [-4.4, 4.4]$) to a locked 2D combat plane ($Z = 0.0$) within rich 3D environments.
   - Elimination of depth whiffing while preserving platforming action: Jump, Combo Attack, Dash i-frames, 0.14s Just Parry, and Dive Slam (Down Thrust).
2. **`ISSUE-V3-001-01` (Mobile Touch Controls Integration & Ergonomics)**:
   - Adaptation of `qv_mobile_controls.gd` for 1280×720 landscape mobile target.
   - Elimination of 3D depth joystick steering; implementation of responsive horizontal movement + dedicated 4-action skill deck: Strike, Leap, Parry, Dash.
3. **`ISSUE-V3-001-07` (Boss Sightline & Foreground Pillar Occlusion)**:
   - Resolution of sightline occlusion caused by `Pillar_FrontRight` at $(X=10.5, Z=3.0)$, ensuring 100% visible telegraphs and fair player reaction windows.
4. **`ISSUE-V3-001-05` (Boss Commander Shield Charge Telegraph Polish)**:
   - Expansion of pre-attack telegraph window from legacy 0.35s to $\ge 0.42\text{s}$ for fair touchscreen parry response.

---

## 2. Option C Movement Feel & Action Timings

### 2.1 The Player Experience Problem
In the legacy 2.5D baseline, players experienced constant micro-whiffing: an attack visually appeared to hit an enemy, but because the actors differed by $\Delta Z > 0.3\text{m}$, the 3D hitbox missed. Furthermore, pressing `move_down` in 2.5D moved the character toward the camera, conflicting with core 2D platformer expectations where holding Down in the air triggers a Down Thrust (Dive Slam).

### 2.2 Movement Plane Invariants ($Z = 0.0$)
- **Player, Enemies, and Boss**:
  - `global_position.z` MUST remain strictly $0.0 \pm 0.01\text{m}$.
  - `velocity.z` MUST be explicitly forced to $0.0$ in all states: `IDLE`, `MOVE`, `DASH`, `ATTACK`, `GUARD`, `DIVE_SLAM`, `HURT`, `DEAD`.
  - Collision sweeps and knockback impulses must only exert force along the $X$ and $Y$ axes.
  - Directional facing is strictly binary horizontal: `facing_dir_x = -1.0` (Left) or `+1.0` (Right).

### 2.3 Dive Slam (Down Thrust) Mechanics
- **Player Value**: Provides high-skill aerial offense, instant vertical descent to evade horizontal projectiles, and heavy poise break against shielded foes.
- **Input Condition**:
  - State: `not is_on_floor() and (global_position.y >= 0.35)`.
  - Trigger: `(Input.is_action_pressed("move_down") or touch_down_drag) and attack_buffer_timer > 0.0`.
  - Safe-Guard: If player is in air but height above floor $< 0.35\text{m}$, normal air slash executes to avoid accidental micro-stomps during jump takeoff.
- **Kinematics & Damage Tuning**:
  - Plunge Velocity: $v_y = -22.0\text{ m/s}$ ($v_x = 0.0, v_z = 0.0$).
  - Landing Shockwave Radius: $3.8\text{m}$ along $X$.
  - Damage: $2\times$ base attack damage ($4\text{ damage}$).
  - Poise Reduction: $-4$ poise damage (instant groggy on regular minions, 1/3 of Boss Commander's 12 poise).
  - Game Feel: Camera trauma $0.42$, Hit-stop $0.06\text{s}$ at $0.05\times$ timescale, expanding golden shockwave mesh ring.

### 2.4 Input Buffering & Coyote Time Standards
In accordance with the Game Quality Director Standard:
- **Coyote Time (`COYOTE_TIME = 0.12s` / ~7-8 frames at 60 FPS)**:
  - When the player runs off a platform ledge without pressing jump, they retain jump authority for 0.12s.
  - Timer decrements only when falling without prior jump input (`velocity.y <= 0` and unjumped).
- **Jump Buffer (`JUMP_BUFFER_TIME = 0.14s` / ~8-9 frames at 60 FPS)**:
  - If jump is pressed within 0.14s before touching the floor, the jump executes on the exact frame of landing (`_on_landed_on_floor()`).
  - Eliminates dropped inputs during rapid platforming or air-recovery.
- **Attack Buffer (`ATTACK_BUFFER_TIME = 0.12s` / ~7 frames at 60 FPS)**:
  - **Air-to-Ground Chaining**: If attack is pressed while airborne in descent, upon touching the floor `start_attack()` triggers instantly without dead frames.
  - **Melee Combo Chaining**: Pressing attack within the final 0.12s of Swing 1 or Swing 2 buffers and executes the subsequent combo strike seamlessly.

### 2.5 Defensive Actions (Dash & Just Parry)
- **Shadow Dash**:
  - Duration: $0.22\text{s}$, horizontal speed $14.0\text{ m/s}$.
  - Full invulnerability (`is_invulnerable = true`) for $0.22\text{s}$.
  - Spawns cyan ghost trail (`DashGhost3D`) at $0.04\text{s}$ intervals.
- **Just Parry (Bastion Shield)**:
  - Guard starts instantly ($0.0\text{s}$ delay) on button press.
  - Just Parry Window: First $0.14\text{s}$ of guard state (`guard_elapsed_time <= 0.14s`).
  - Succeeded Parry Rewards:
    1. Zero incoming damage.
    2. Zero player knockback.
    3. Inflicts $-4$ poise damage and staggered recoil on attacker.
    4. Grants 3.0s Counter-Attack Buff ($3\times$ damage on next melee strike).
    5. Hit-stop $0.12\text{s}$, camera trauma $0.35$, radiating cyan runic shield barrier.

---

## 3. Mobile Touch Ergonomics (1280×720 Landscape)

### 3.1 Ergonomic Architecture & Thumb Comfort Zones
Mobile touch play on glass lacks physical tactile edges. The interface must maximize hit tolerance, prevent false-triggering, and support fluid multi-touch coordination.

```text
+-------------------------------------------------------------------------+
| [HP/Soul Bar]                                           [📱 Pad Toggle] |
|                                                                         |
|                                                                         |
|                                                      [▲ LEAP]           |
|                                                      (Jump)             |
|                                             [🛡 PARRY]       [⚔ STRIKE]  |
|                                              (Guard)          (Attack)  |
|      (O) TACTICAL MOVE                               [💨 DASH]          |
|      (Left / Right / Down)                            (Evade)           |
+-------------------------------------------------------------------------+
|<-- Left Thumb Zone: 500x360px -->|   |<-- Right Action Deck: 450x360px -->|
```

### 3.2 Left-Hand Movement Control
- **Component**: Virtual Tactical Stick / Horizontal Slider.
- **Base Anchor**: Center $(X = 145\text{px}, Y = 545\text{px})$, Radius $65\text{px}$.
- **Touch Capture Zone**: Lower-left screen quadrant: $X \in [0, 500\text{px}], Y \in [360, 720\text{px}]$.
- **Axis Response Rules**:
  - Radial Deadzone: $15\%$ ($strength < 0.15 \implies$ neutral).
  - Horizontal Threshold ($|dir.x| > 0.35$):
    - $dir.x < -0.35 \implies$ `Input.action_press("move_left")`.
    - $dir.x > +0.35 \implies$ `Input.action_press("move_right")`.
  - Downward Threshold ($dir.y > 0.50$):
    - $dir.y > 0.50 \implies$ `Input.action_press("move_down")`.
    - *Design Rationale*: On ground, `move_down` causes no movement ($Z=0$). While airborne, holding Down + tapping Strike triggers the Dive Slam!
  - Upward Threshold ($dir.y < -0.50$): Discarded or neutral to prevent accidental jump triggers on joystick drift.

### 3.3 Right-Hand Action Deck Layout & Touch Targets
Each button is sized to ensure a minimum $70\text{px}$ touch target ($>9\text{mm}$ physical finger contact area on a 6-inch phone screen):

| Button | Action Map | Local Position (ActionContainer) | Button Size | Visual Style & Rim Color | Design Function |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **⚔ STRIKE** | `attack` | $(X = +65, Y = +35)$ | **$88 \times 88\text{px}$** | Deep Crimson (`#38141c`), Coral Rim (`#ff3b5c`) | Primary offensive anchor; largest button |
| **▲ LEAP** | `jump` | $(X = -05, Y = -55)$ | **$74 \times 74\text{px}$** | Dark Gold (`#261c0c`), Amber Rim (`#ffb800`) | Easy upward thumb sweep for air combat |
| **🛡 PARRY** | `guard` | $(X = -95, Y = -15)$ | **$74 \times 74\text{px}$** | Deep Navy (`#102638`), Cyan Rim (`#00e5ff`) | Quick-reflex defensive tap for 0.14s parry |
| **💨 DASH** | `dash` | $(X = -85, Y = +65)$ | **$74 \times 74\text{px}$** | Dark Emerald (`#0e2a24`), Mint Rim (`#34d399`) | Mobility and i-frame evasion under thumb |

### 3.4 Multi-Touch & Input Safety Protocols
1. **Independent Touch Ownership**:
   - The virtual joystick tracks its own `drag_touch_index`.
   - Right-side buttons process independent touch pointer indices.
   - Pressing Strike while holding Move Left MUST NOT interrupt or cancel the movement vector.
2. **Fail-Safe Release**:
   - On `InputEventScreenTouch` with `pressed == false` or on scene pause/transition, all simulated actions (`move_left`, `move_right`, `move_down`, `attack`, `jump`, `guard`, `dash`) MUST be released via `Input.action_release()`.
   - Never allow a button or stick state to remain permanently held down upon finger slide-off.
3. **Tactile Visual Feedback**:
   - Buttons scale to $0.92\times$ on press with elevated emission brightness to give immediate visual confirmation of touch registration.

---

## 4. Boss Commander Telegraph & 2D Combat Pacing

### 4.1 Combat Rhythm on a Fixed 2D Plane
In a 2.5D space, players frequently used vertical Z-stepping to bypass boss charges. On a fixed 2D plane ($Z = 0$), combat transforms into an intense rhythm game of footsies, parries, and vertical traversal:
- **Spacing**: Neutral positioning at $X \approx 2.5\text{m} - 3.5\text{m}$ outside the commander's heavy greatsword cleave.
- **Timing Defense**: Executing Just Parry against the Shield Charge or Cleave Combo.
- **Vertical Counterplay**: Jumping over Quake Shockwaves and countering with Dive Slam.
- **Linear Evasion**: Dashing through the boss using $0.22\text{s}$ i-frames when cornered against the arena wall.

### 4.2 Pattern Telegraph Matrix

| Boss Pattern | Startup Telegraph | Active Attack Phase | Recovery / Vulnerability | Player Counterplay & Payoff |
| :--- | :--- | :--- | :--- | :--- |
| **Shield Charge** (`SHIELD_CHARGE`) | **$0.42\text{s}$** (Crimson eye flash, shield raised, red ground circle) | Boss rushes forward at $12.0\text{ m/s}$ along $X$ | $0.60\text{s}$ brake and shield lower | 1. **Just Parry**: Timing shield at contact stops boss, deals $-4$ poise.<br>2. **Dash Through**: Evade via i-frames.<br>3. **Leap & Slam**: Jump over rush, dive slam boss from rear. |
| **Triple Cleave** (`TRIPLE_CLEAVE`) | **$0.32\text{s}$** (Sword drawn back, golden glint) | 3 distinct swings at $0.28\text{s}$ intervals, moving $4.5\text{ m/s}$ forward | $0.80\text{s}$ posture recovery | 1. Cadenced Parries: Parry Swing 1 $\rightarrow$ Strike $\rightarrow$ Parry Swing 3.<br>2. Backdash out of cleave reach. |
| **Quake Ring** (`QUAKE_RING`) | **$0.45\text{s}$** (Boss crouches, heavy red rune pulses on floor) | Ground-level shockwave expands outward to $4.2\text{m}$ radius ($Y \le 0.6\text{m}$) | $0.70\text{s}$ recovery | 1. **Jump**: Clear shockwave vertically ($Y > 0.8\text{m}$).<br>2. **Dive Slam Punish**: Plunge onto boss during recovery for $-4$ poise damage! |

### 4.3 Poise System & Groggy State Tuning
- **Boss Max Poise**: $12$.
- **Poise Damage Values**:
  - Normal Strike: $-1$
  - Combo Finisher (3rd hit): $-2$
  - Sword Beam: $-1$
  - Just Parry: **$-4$**
  - Dive Slam: **$-4$**
- **Groggy Phase**:
  - Trigger: Poise reaches $0$.
  - State Duration: **$3.0\text{s}$** immobilized vulnerability.
  - Presentation: Boss drops shield, golden rotating halo (`GroggyHalo3D`) appears overhead, text popup `"GROGGY!"`.
  - Player Payoff: Guaranteed uninterrupted 3-hit combo string + Sword Beam projectile, dealing high burst damage.

---

## 5. Arena Sightline & Foreground Occlusion (ISSUE-V3-001-07)

### 5.1 The Player Experience Problem
When fighting Boss Commander in the right half of the arena ($X \ge 8.0$), `Pillar_FrontRight` at $(X = 10.5, Z = 3.0)$ stands directly in front of the boss spawn and combat area. Under the side camera angle, this massive stone pillar obstructs up to $40\%$ of the screen, completely blinding the player to the boss's startup telegraphs and leading to unfair, unreadable damage.

### 5.2 Game Design Requirements for Level Architecture
1. **Unobstructed Sightline Invariant**:
   - The player character and Boss Commander MUST remain $100\%$ visible to the camera at all times throughout the fight.
   - Startup animation frames and telegraph cues (crimson eye flashes, ground markers) MUST NOT be occluded by foreground meshes.
2. **Actionable Remediation Options**:
   - **Option 1 (Recommended / Cleanest)**: Reposition `Pillar_FrontRight` along the $X$-axis from $X = 10.5$ to $X = 16.5$ (outside the active combat arena, framing the right edge).
   - **Option 2**: Push the front pillars into the background lane ($Z \le -3.0$).
   - **Option 3**: Add camera proximity dither/transparency to foreground pillars when characters are behind them.

---

## 6. Acceptance Criteria Checklist for Subordinate Agents

### For `PK_ClientLead` (Implementation)
- [ ] Option C Z-lock implemented: `SideQVPlayer.velocity.z == 0.0` and `global_position.z == 0.0` in all states.
- [ ] `SideQVEnemy` and `SideQVBossCommander` constrained strictly to $Z = 0.0$.
- [ ] `qv_mobile_controls.gd` instantiated under Stage 1 UI CanvasLayer (`1280x720`).
- [ ] Virtual joystick adapts to horizontal axis + down threshold ($dir.y > 0.5$) for dive slam.
- [ ] Action buttons (Strike, Leap, Parry, Dash) verified responsive with zero stuck input states.
- [ ] Dive slam triggered exclusively by `airborne + move_down + attack`.
- [ ] Coyote time ($0.12\text{s}$), Jump buffer ($0.14\text{s}$), and Attack buffer ($0.12\text{s}$) verified active.
- [ ] Boss Commander Shield Charge windup set to $\ge 0.42\text{s}$.

### For `PK_ArtDirector` (Visuals & Camera)
- [ ] Reposition or fade `Pillar_FrontRight` at $X = 10.5, Z = 3.0$ to clear boss arena sightline.
- [ ] Preserve all 3D environment assets (flagstone arena, glowing runic seal, parapets, torches, mountain vista).
- [ ] Provide camera-identical Before vs After screenshots verifying zero occlusion at $X \ge 8.0$.

### For `PK_QALead` (Verification)
- [ ] Input-driven playtest: Stage 1 traversed and Boss Commander cleared using touch controls alone.
- [ ] Telemetry log confirms $Z = 0.0$ across all combat states (zero Z drift).
- [ ] Real Godot 4.7.2 1280×720 windowed capture with zero new engine errors.

---

## 7. Game Design Verdict

```text
================================================================================
GAME DESIGN EVALUATION VERDICT: DESIGN PASS (CRITERIA SPECIFIED)
BASELINE CODE STATUS:           DESIGN FIX_REQUIRED (Pending Implementation)
================================================================================
Rationale:
The Option C 2D gameplay plane lock, 1280x720 mobile touch controls, and boss
sightline specifications resolve the core player frustration, input drift, and
occlusion defects identified in V3-001.

Subordinate agents PK_ClientLead and PK_ArtDirector are authorized to implement
these specifications under Task V3-003 Checkpoints A, B, and C.
================================================================================
```

*Signed:*  
**PK_GameDesign — Player Experience Owner**  
*ProjectKnight Studio V3*  
