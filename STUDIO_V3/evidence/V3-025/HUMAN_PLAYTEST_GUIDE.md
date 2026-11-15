# V3-025 Human Playtest Guide & Operator Checklist

**Classification:** `HUMAN_PLAYTEST_NOT_TESTED`  
**Milestone:** V3-025 Stage 1 Combat Readability & Encounter Pacing  
**Branch:** `studio/v3-025-stage1-combat-readability-pacing`  
**Build Platform:** Windows (Godot 4.7.2 stable, Compatibility Renderer, 1280×720 Landscape)

---

## 1. Operating Status & Audit Honesty Declaration

> [!IMPORTANT]
> **Human Playtest Status: `HUMAN_PLAYTEST_NOT_TESTED`**  
> In strict accordance with `AGENTS.md` Rule 5 ("No PASS without evidence") and `V3-025.md` Section 3 ("Test with actual human operator when available... If no operator: mark `HUMAN_PLAYTEST_NOT_TESTED`, no fake survey or human approval"), this milestone has completed full automated simulated-input E2E testing, frame-by-frame hitbox/telegraph verification, and pacing policy benchmarks.  
> No claims of human playability sign-off or subjective fun score are fabricated. This document provides the complete, working manual launch guide, control mappings, and operator verification checklist for a human tester.

---

## 2. Normal Game Launch Instructions (Zero Developer Console Required)

The game features a fully integrated production launch flow from the main menu and campaign screen:

1. **Direct Godot Execution (Standalone Windows):**
   ```powershell
   & "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path "D:\JUNYPAPA_STUDIO\Worktrees\ProjectKnight\V3-025\CLIENT\Game"
   ```
2. **Campaign Navigation:**
   - Launching starts at `res://scenes/SideQVTitle.tscn` or directly loads `res://scenes/side_quarter_view/SideQVStage1.tscn`.
   - From Campaign / Stage Selection, choose **Stage 1: Citadel Approach**.
   - No developer console commands, coordinate hacks, or cheat flags are required or enabled by default.

---

## 3. Control Scheme (Keyboard & Gamepad)

| Action | Primary Keyboard | Secondary / Alternate | Gamepad (Standard XInput) | Gameplay Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Move Left / Right** | `A` / `D` | `Left` / `Right` Arrow | Left Stick / D-Pad Left-Right | Main horizontal traversal plane |
| **Move Up / Down (Z-Depth)** | `W` / `S` | `Up` / `Down` Arrow | Left Stick / D-Pad Up-Down | **Belt-scroll Z-depth lane shifting** for flanking and evasion |
| **Attack (3-Hit Combo)** | `J` | `C` / Space | X / Square | Standard melee attack. Whiff punishable during recovery |
| **Guard / Just Parry** | `K` | `V` / Left Shift | LB / Left Bumper | Hold to block; tap $\le 0.14\text{s}$ before hit for **Just Parry** (spark + 3x counter) |
| **Dash (Evade)** | `L` | `B` | RB / Right Bumper | Quick directional burst with invulnerability frames |
| **Jump** | `Space` | `W` (if mapped) | A / Cross | Vertical leap over ground obstacles or shockwaves |
| **Controls Guide Toggle** | `Tab` / `H` | - | Back / Select | Toggles on-screen control cheat-sheet |
| **Tactical Pause Menu** | `Esc` | - | Start / Menu | Opens modal: Resume, Restart Stage, Return to HQ |
| **Debug Telemetry Overlay** | `F1` | - | - | Non-invasive HUD: FPS, input state, HP, encounter timers |

---

## 4. Human Operator Verification Checklist (2 Test Attempts Minimum)

When a human tester is seated at the controls, follow this standard test protocol across two consecutive runs:

### Run 1: Onboarding & Mechanical Discovery
- [ ] **Controls Guide (`[TAB]` / `[H]`):** Does pressing `Tab` display the on-screen control mapping clearly without obscuring the hero?
- [ ] **Encounter 1 (Melee Grunts - Spacing & Whiff Punish):**
  - [ ] Do grunts display a distinct amber sweeping arc (`TexSlashArcAmber`) during their 0.28s windup?
  - [ ] Can the player step back outside the arc, wait for the swing to complete, and punish the grunt during its 0.22s recovery opening?
- [ ] **Encounter 2 (Crossbowman - Ranged Beam & Z-Sidestep / Parry):**
  - [ ] Does the crossbowman project a narrow amber laser beam along the ground indicating exact line of fire?
  - [ ] Does the beam lock into a crimson flash 0.14s prior to firing?
  - [ ] Can the player either sidestep along the Z-axis (`[W]` / `[S]`) or time a Just Parry (`[K]`) to reflect/clash the bolt?
- [ ] **Encounter 3 (Heavy Shield Knight - Shield Guard & Flanking):**
  - [ ] Does the shield knight block head-on attacks with a metallic clashing sound and spark VFX?
  - [ ] Can the player maneuver into a flanking Z-lane ($|\Delta Z| \ge 0.45\text{m}$) and land hits from the side?
  - [ ] When the shield knight performs his runic shield bash, does dodging allow punishing his 0.42s lowered-guard recovery?
- [ ] **Pause Modal (`[ESC]`):**
  - [ ] Does pressing `Esc` pause game time cleanly?
  - [ ] Does clicking "Resume" restore gameplay smoothly?
  - [ ] Does "Restart Stage" reset the hero to the start without memory leaks or dangling nodes?

### Run 2: Boss Arena Duel & Pacing Flow
- [ ] **Sanctuary Gate Entry:** Does the gate dissolve and transition cleanly into the Boss Sanctuary?
- [ ] **Dual Camera Tracking:** Do both the player and the boss remain on-screen throughout all phases without clipping out of view?
- [ ] **Boss Telegraphs & Z-Dodge:**
  - [ ] **Shield Charge:** Does the glowing runway strip indicate the charge lane clearly? Can the player sidestep along Z to avoid it?
  - [ ] **Ground Fissure:** Is the linear fissure tell distinguishable from the charge?
  - [ ] **Quake Ring:** Does the expanding ground ring telegraph provide clear jump or retreat timing?
- [ ] **Corner & Depth Escape:** Can the player escape if backed toward the arena boundary without getting pinned indefinitely?
- [ ] **Defeat & Victory Flow:**
  - [ ] Upon player death: Does the defeat modal appear offering immediate "Retry Stage" or "Return to HQ"?
  - [ ] Upon boss victory: Does the victory fanfare trigger with both combatants properly staged on-screen?

---

## 5. Qualitative Feedback Log (Template for Human Review)

| Field | Operator Attempt 1 | Operator Attempt 2 |
| :--- | :--- | :--- |
| **Tester Name / ID** | *Pending Human Playtest* | *Pending Human Playtest* |
| **Clear / Defeat Status** | *Pending* | *Pending* |
| **Duration (mm:ss)** | *Pending* | *Pending* |
| **Encounter 1 Readability** | (Rate 1-5: telegraph clarity, whiff window) | (Rate 1-5) |
| **Encounter 2 Crossbow Fair** | (Rate 1-5: beam noticeability, parry feel) | (Rate 1-5) |
| **Encounter 3 Shield Flank** | (Rate 1-5: frontal block feedback, flank feel) | (Rate 1-5) |
| **Boss Duel & Camera** | (Rate 1-5: visibility, pattern fairness) | (Rate 1-5) |
| **Controls & Responsiveness** | (Rate 1-5: Z-movement feel, attack buffer) | (Rate 1-5) |
| **Subjective Fun & Pacing** | (Notes on dead time, intensity, satisfaction) | (Notes) |
