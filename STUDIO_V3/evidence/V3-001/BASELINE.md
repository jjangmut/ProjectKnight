# V3-001 — Playable Baseline Audit Report

**Task ID:** `V3-001`  
**Date:** 2026-11-06  
**Audited Source Revision:** `a71223615d0b77e36dd85edb24e138fc67ecc140`  
**Branch:** `studio/v3-001-playable-baseline`  
**Lead Auditor:** PK_ClientLead  
**Producer Authority:** PK_Producer  
**Independent Reviewers:** PK_QALead, PK_GameDirector  

---

## 1. System & Execution Environment

| Environment Parameter | Measured Value | Verification Method |
| :--- | :--- | :--- |
| **Operating System** | Microsoft Windows 11 Pro 64-bit (Build 10.0.26200) | `Get-CimInstance Win32_OperatingSystem` |
| **Processor (CPU)** | AMD Ryzen 9 8945HX with Radeon Graphics (16 Cores, 32 Threads) | `Get-CimInstance Win32_Processor` |
| **Graphics Adapter (GPU)** | NVIDIA GeForce RTX 5060 Laptop GPU (Driver Version: 32.0.16.1047) | `Get-CimInstance Win32_VideoController` |
| **Physical Memory (RAM)** | 24.89 GB (24,886,616,064 bytes) | `Get-CimInstance Win32_ComputerSystem` |
| **Display Mode** | 1920x1200 @ 240 Hz Native Primary Display | Hardware query |
| **Godot Binary** | `D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe` | CLI `--version` check |
| **Godot Build Version** | `4.7.2.stable.official.ed1daf0bf` | Engine banner output |
| **Graphics Backend** | OpenGL 3.3.0 (GL Compatibility Renderer) | Engine runtime log |
| **Target Viewport** | 1280x720 Windowed Mode (Aspect: expand, Stretch: canvas_items) | `CLIENT/Game/project.godot` |
| **Android Performance** | **NOT_TESTED** (PC development environment only) | Explicit protocol requirement |

---

## 2. Gate 0: Headless Import & Script Parse Smoke Test

- **Command Executed:**
  ```powershell
  & "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --editor --path "D:\JUNYPAPA_STUDIO\Projects\ProjectKnight\CLIENT\Game" --quit
  ```
- **Exit Code:** `0` (SUCCESS)
- **Raw Log Artifact:** [`startup_import_raw.log`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/test_logs/startup_import_raw.log) (668 lines, 43,020 characters)
- **Parse Status:**
  - `0` Syntax / GDScript Parse Errors
  - `0` Missing Resource Errors
  - Clean filesystem scan of all 201 engine scripts and class definitions.
  - Working directory cleanliness verified: zero modified game files or tracked code mutations in `CLIENT/Game/`.

---

## 3. Gate 1: Real Graphical Windowed Launch & Campaign Routing

- **Execution Mode:** Genuine graphical window (HWND: `37094300`, Window Class: `Engine`), running on NVIDIA RTX 5060 Laptop GPU.
- **Client Resolution:** Resized to exact $1280 \times 720$ viewport via Win32 `SetWindowPos`.
- **Title Flow Progression:**
  1. Window boots into default configured scene: `res://scenes/ui/TitleScreen.tscn`.
  2. Captured unedited original screenshot: [`00_title.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/captures/originals/00_title.png) (18,295 unique colors).
  3. Win32 `PostMessageW` mouse click dispatched to Deploy Button at client coordinates $(880, 215)$.
  4. Scene manager transitions cleanly: `TitleScreen` $\rightarrow$ `res://scenes/side_quarter_view/SideQVCampaign.tscn` $\rightarrow$ `res://scenes/side_quarter_view/SideQVStage1.tscn`.
  5. Console outputs confirmation: `>>> [CAMPAIGN] Loaded Stage 1: 성문 외곽 (Citadel Terrace Gate) <<<`.
  6. Captured unedited original screenshot: [`01_stage_entry.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/captures/originals/01_stage_entry.png) (134,826 unique colors).
- **Gate 1 Verdict:** **PASS (VERIFIED)**

---

## 4. Gate 2: Input-Driven Gameplay Inspection Matrix

All test actions executed via hardware scan-code messages dispatched to the running Godot client window:

| Action ID | Matrix Item | Input Tested | Observed Behavior | Expected Behavior | Gate Result | Primary Evidence |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **ACT-A** | Horizontal Movement (X) | `D` / `A` keys (VK `0x44`/`0x41`, Scan `0x20`/`0x1E`) | Character runs horizontally along X-axis (`7.5 m/s`). Sprite3D updates running animation frames. Camera smoothly tracks player. | Responsive horizontal movement with ground contact and camera follow. | **PASS** | [`02_idle_run.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/captures/originals/02_idle_run.png) |
| **ACT-B** | Z-Depth Movement | `W` / `S` keys (VK `0x57`/`0x53`, Scan `0x11`/`0x1F`) | Character navigates in/out across depth lane ($Z \in [-4.4, 4.4]$). Collides firmly with rear balustrade and front curb. | Free Z-movement observed; highlights design discrepancy with 2D genre. | **PASS (Observed)** | [`03_depth_occlusion.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/captures/originals/03_depth_occlusion.png) |
| **ACT-C** | Jump & Airborne Physics | `Space` key (VK `0x20`, Scan `0x39`) | Player elevates vertically along Y-axis (`jump_velocity: 6.8 m/s`). Real-time DirectionalLight3D shadow projects onto runic floor decal. | Clean jump curve, coyote time active, smooth landing. | **PASS** | [`04_jump.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/captures/originals/04_jump.png) |
| **ACT-D** | Melee Attack 3-Combo | `J` key (VK `0x4A`, Scan `0x24`) | 3-hit combo triggers in sequence. Finisher emits translucent holy spear thrust visual VFX streak (`SlashVisual3D`). Hitbox monitors Enemy layer. | Multi-hit combo with distinct windup, impact VFX, and cooldown. | **PASS** | [`05_attack_impact.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/captures/originals/05_attack_impact.png) |
| **ACT-E** | Guard Barrier & Dash | `K` / `Shift` keys (VK `0x4B`/`0x10`) | Guard displays glowing cyan-blue runic torus barrier (`GuardBarrier3D`). Dash executes forward evasion streak (`14.0 m/s`). | Active guard defense state and i-frame dash evasion. | **PASS** | [`06_guard_dash.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/captures/originals/06_guard_dash.png) |
| **ACT-F** | Minion Combat (Wave 1) | `D` advance + `J` attack | Two `SideQVEnemy` melee minions at $X=2.0, 4.0$ track player. Attacks hit, reducing overhead HP bar (HP 4 $\rightarrow$ 0) and triggering defeat signal. | Enemies engage, take damage, show hit feedback, and perish upon 0 HP. | **PASS** | [`07_enemy_wave.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/captures/originals/07_enemy_wave.png) |
| **ACT-G** | Boss Wave & Combat | Stage Progression + `J`/`K` | Wave 1 clear triggers `AdvanceBanner` ("ADVANCE ▶▶▶"). Advancing to $X > 8.0$ spawns `SideQVBossCommander` (HP 24). Boss executes attacks. Combat resolves with Boss defeat. | Boss spawns with Gothic health bar, telegraphs attacks, and transitions on defeat. | **PASS** | [`08_boss_telegraph.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/captures/originals/08_boss_telegraph.png), [`09_boss_combat.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/captures/originals/09_boss_combat.png) |
| **ACT-H** | Mobile UI Overlays | Touch / CanvasLayer inspection | HUD displays Tactical Unit Plate (Avatar, SSR rank, 8 soul gems, HP label), Stage Progress Bar, Combo HUD, and AX Data button. **NO virtual D-pad or action buttons exist.** | Mobile layout should provide touch controls on mobile target. | **FAIL (Defect Filed)** | [`01_stage_entry.png`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/captures/originals/01_stage_entry.png), `ISSUE-V3-001-01` |

---

## 5. Gate 3: Concrete Visual Quality Audit

Evaluated against actual rendered pixels at $1280 \times 720$ resolution:

1. **Sprite Sharpness & Pivot Alignment:**
   - Paladin Sprite3D is rendered from high-resolution $780 \times 780$ frames with `pixel_size: 0.00282` (~1.77m scale). Sprite lines are crisp, without noticeable bilinear blur or pixel shimmer.
   - Ground pivot aligns well at $Y=0.0$, but minor perspective tilt under `BILLBOARD_FIXED_Y` creates slight ground intersection near the extreme front curb (documented in `ISSUE-V3-001-04`).
2. **Environment & 3D Layering:**
   - 3D flagstone floor utilizes triplanar mapping (`TexFlagstone`) with visible surface roughness.
   - Glowing golden runic floor seal decal (`CentralRunicSeal`) emits emissive HDR bloom ($2.4 \times$).
   - Distant mountain vista quad (`PanoramicCastleBackdrop`) provides strong atmospheric perspective and sense of scale.
3. **Lighting & Real-Time Shadows:**
   - Directional sunlight (energy $1.45$, angle $-46^\circ, -32^\circ$) casts sharp, real-time directional shadows from the 2D character sprite onto the 3D floor geometry.
   - WorldEnvironment provides subtle fog ($0.012$ density, light blue hue) and balanced bloom ($0.18$).
4. **Combat Feedback & VFX Readability:**
   - Holy spear thrust (`SlashVisual3D`) is prominent with golden-white emissive glow ($4.2 \times$).
   - Guard barrier torus is instantly readable with cyan emission ($4.0 \times$).
   - Boss Commander crimson aura ring and groggy halo provide unmistakable state indicators.
5. **HUD Composition:**
   - Heroes War tactical command aesthetic gives a professional, commercial impression.
   - Stage progress bar, soul gems, and combo counter are well-proportioned for 1280x720 landscape.

---

## 6. Gate 4: Measured PC Performance Profile

Captured over **14,404 continuous frames** (240.0 seconds total, 60.0s per sector) in windowed 1280x720 GL Compatibility mode:

```text
================================================================================
Sector Breakdown (60.0 Seconds Each):
--------------------------------------------------------------------------------
Sector 1 (Idle):          Mean FPS: 60.10 | 1% Low: 59.36 | P95: 16.76 ms | Draws: 225 | Mem: 76.0 MB
Sector 2 (Walking):       Mean FPS: 60.00 | 1% Low: 59.44 | P95: 16.76 ms | Draws: 225 | Mem: 79.7 MB
Sector 3 (Normal Combat): Mean FPS: 60.00 | 1% Low: 59.53 | P95: 16.76 ms | Draws: 225 | Mem: 83.4 MB
Sector 4 (Boss Combat):   Mean FPS: 60.00 | 1% Low: 59.48 | P95: 16.76 ms | Draws: 225 | Mem: 87.1 MB
--------------------------------------------------------------------------------
Overall Performance Summary:
  Target Framerate:       60.0 FPS
  Mean Framerate:         60.03 FPS
  Median Framerate:       240.0 FPS (Physics Tick / VSync sync)
  1% Low Framerate:       59.46 FPS (Rock Solid!)
  Mean Frame Time:        16.66 ms
  P95 Frame Time:         16.76 ms
  P99 Frame Time:         16.82 ms
  Mean Process Time:      4.43 ms (Over 11.5 ms frame headroom)
  Mean Physics Time:      0.63 ms
  Draw Calls:             225 (Max: 228)
  Active Scene Nodes:     155 nodes
  Static Memory:          81.56 MB (Peak: 87.10 MB)
  Stutter Spikes (>33ms): 2 (startup initialization only; 0 in combat)
  Scene Load Latency:     0.065 ms
  PC Performance Gate:    PASS
  Android Device Status:  NOT_TESTED
================================================================================
```

Raw data artifacts:
- Structured Metrics: [`performance.json`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/performance/performance.json)
- Per-Frame Samples: [`raw_frames.csv`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/performance/raw_frames.csv) (14,405 rows)

---

## 7. Gate 5: Movement Plane Decision Summary

- Evaluated Option A (Strict 2D Side-scroller), Option B (Current 2.5D Belt-scroller), and Option C (2.5D Visuals + 2D Horizontal Plane Lock).
- **Formal Verdict:** **Option C selected by PK_GameDirector**.
- Complete rationale and implementation guidance documented in [`DESIGN_DECISION.md`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/DESIGN_DECISION.md).

---

## 8. Gate 6: Open Defects & Action Items

Total Open Issues Identified: **6**
- **P1 (Major / Blocker for Release):** 2 (`ISSUE-V3-001-01` Mobile UI lacks touch buttons, `ISSUE-V3-001-02` Z-depth motion model)
- **P2 (Minor Bug / Visual):** 2 (`ISSUE-V3-001-03` Boot audio error, `ISSUE-V3-001-04` Sprite3D ground contact)
- **P3 (Polish):** 2 (`ISSUE-V3-001-05` Boss charge telegraph, `ISSUE-V3-001-06` Stage result screen)
- Complete issue registry: [`ISSUES.md`](file:///D:/JUNYPAPA_STUDIO/Projects/ProjectKnight/STUDIO_V3/evidence/V3-001/ISSUES.md).

---

*Report submitted by PK_ClientLead & PK_Producer on 2026-11-06*
