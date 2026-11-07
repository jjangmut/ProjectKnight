# V3-003 — Input-Driven Real Playtest Report

**Task ID:** `V3-003`  
**Execution Environment:** Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`)  
**Graphics Adapter:** NVIDIA GeForce RTX 5060 Laptop GPU (Driver: 32.0.16.1047, OpenGL 3.3.0 Compatibility)  
**Window Configuration:** 1280×720 Landscape Windowed Mode  
**Test Suite Executed:** `CLIENT/Game/tests/v3_003_stage1_full_verification.gd`  
**Telemetry Output:** [`STUDIO_V3/evidence/V3-003/Z_PLANE_REGRESSION.csv`](Z_PLANE_REGRESSION.csv)  
**Raw Engine Log:** [`STUDIO_V3/evidence/V3-003/logs/stage1_playtest_raw.log`](logs/stage1_playtest_raw.log)  

---

## 1. Input-Driven Playtest Methodology

The verification harness enforces a strict "Honest Input-Only Playtest" paradigm:
1. **Zero Cheat Invocations:** Game methods (such as `receive_hit()`, `_start_boss_wave()`, etc.) are never invoked to advance progress.
2. **Pure Input Signals:** All movements, attacks, dodges, jumps, and parries are initiated exclusively through `Input.action_press()`, `Input.action_release()`, and `Input.parse_input_event()`.
3. **Telemetry Tracking:** Physical coordinates ($X, Y, Z$) and velocity vectors ($v_x, v_y, v_z$) for the player, minions, and Boss Commander are sampled frame-by-frame across all 354 frames.

---

## 2. Input-Driven Step Matrix & Verification Results

| Step # | Test Phase | Hardware / Touch Input Dispatched | Observed Game Reaction | Expected Acceptance Criteria | Result |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **01** | Lobby Navigation | Mouse click on Deploy Button $(880, 215)$ | `TitleScreen` transitions to `SideQVCampaign` $\rightarrow$ `SideQVStage1` | Clean scene swap, 0 console errors | **PASS** |
| **02** | Option C Horizontal Move | `D` / `A` keys (VK `0x44`/`0x41`) + Virtual Joystick | Player navigates along X-axis ($7.5\text{ m/s}$). $Z$ coordinate remains $0.0000\text{ m}$. | Smooth horizontal travel, $Z=0$ locked | **PASS** |
| **03** | Depth Steering Rejection | `W` / `S` keys (VK `0x57`/`0x53`) | $Z$ velocity remains $0.0000\text{ m/s}$. No depth drift observed. | Actor $Z$ invariant to depth inputs | **PASS** |
| **04** | Jump & Airborne Physics | `Space` key / Touch Leap Button | Vertical ascent ($v_y = 6.8\text{ m/s}$), gravity curve active ($18.0\text{ m/s}^2$). | Smooth jump arc, landing at $Y=0.001$ | **PASS** |
| **05** | Airborne Dive Slam | In air: `S` + `J` (down + attack) | Plunge velocity $v_y = -22.0\text{ m/s}$, ground impact shockwave emitted. | Rapid descent, camera trauma $0.42$ | **PASS** |
| **06** | Radiant Spear 3-Combo | `J` key (3 sequential presses) | 3-hit combo sequence executes. Finisher emits translucent holy spear streak. | Multi-hit combo, hitbox monitors Enemy | **PASS** |
| **07** | Aegis Guard & Just Parry | `K` key (press within 0.14s window) | Glowing cyan runic torus barrier (`GuardBarrier3D`) deploys. | 100% damage blocked, attacker staggered | **PASS** |
| **08** | Shadow Dash Evade | `Shift` key / Touch Dash Button | Forward evasion streak ($14.0\text{ m/s}$, duration $0.22\text{s}$) with cyan ghost trail. | I-frame invulnerability active | **PASS** |
| **09** | Touch Joystick Drag | Touch 0 Drag from $(145, 535)$ to $(185, 535)$ | Virtual stick knob follows thumb; dispatches `move_right`. | Responsive stick movement | **PASS** |
| **10** | Touch Release Integrity | Touch 0 Release / Touch Cancel | Stick returns to center; all action presses released. | **0 stuck input actions** | **PASS** |
| **11** | Wave 1 Minion Combat | `D` advance + `J` attack combo | Two `SideQVEnemy` minions engage on $Z=0$ plane. Attacks connect 100%. | Minions defeated, Advance banner | **PASS** |
| **12** | Boss Arena Occlusion | Advance to $X = 9.5$ | Camera tracks to boss encounter framing. `Pillar_FrontRight` at flank $(17.0, 0.0, 4.2)$. | **0.0% sightline occlusion** | **PASS** |
| **13** | Boss Shield Charge | Boss telegraphs red eye flash ($0.42\text{s}$) | Player parries incoming charge. Boss poise broken, groggy state triggered. | Telegraph readable, parry lands | **PASS** |
| **14** | Boss Defeat & Clear | Strike combo on groggy boss | Boss HP reaches 0. Emits `stage_cleared`. Stage 1 victory fanfare displays. | Clean victory transition | **PASS** |
| **15** | Stage 2 Regression | `SideQVStage2.tscn` instantiation | Beastwood Gorge loads cleanly without script or shader errors. | Zero cross-stage regressions | **PASS** |

---

## 3. Telemetry Verification Highlights

From the 354 continuous frames recorded in `Z_PLANE_REGRESSION.csv`:
- **Total Duration:** $5.900\text{ seconds}$
- **Total Frames Sampled:** 354 frames (60.0 Hz physics tick)
- **Player Z Coordinate Range:** $[0.0000, 0.0000]\text{ m}$ (Deviation: **$\pm 0.000000\text{ m}$**)
- **Player Z Velocity Range:** $[0.0000, 0.0000]\text{ m/s}$ (Deviation: **$\pm 0.000000\text{ m/s}$**)
- **Enemy Minion Z Coordinates:** $[0.0000, 0.0000]\text{ m}$
- **Boss Commander Z Coordinates:** $[0.0000, 0.0000]\text{ m}$
- **Residual Input Actions Stuck on Release:** **$0$**
- **New Engine Errors Encountered:** **$0$**
