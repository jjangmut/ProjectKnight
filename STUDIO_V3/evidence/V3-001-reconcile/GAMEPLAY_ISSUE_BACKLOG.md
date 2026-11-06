# ProjectKnight — Canonical Gameplay Issue Backlog

**Origin Task:** `V3-001` (Playable Baseline Audit)  
**Reconciliation Task:** `V3-001-EVIDENCE-RECONCILE`  
**Governing Authority:** `PK_GameDirector` / `PK_Producer`  
**Target Milestone for Resolution:** `V3-003` (Stage 1 Polish & Fix) and beyond  
**Last Reconciled:** 2026-11-07  

---

## 1. Backlog Summary Matrix (7 Unique Issues)

| Issue ID | Severity | Category | Title | Owner | Status | Downstream Target |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **ISSUE-V3-001-01** | **P1 (MAJOR)** | Input / Mobile | Mobile Touch Joystick & Action Buttons Missing | PK_ClientLead | **OPEN** | V3-003 |
| **ISSUE-V3-001-02** | **P1 (MAJOR)** | Architecture | 2.5D Belt-Scroll vs 2D Gameplay Plane Discrepancy | PK_ClientLead | **DECIDED / IMPLEMENTATION_PENDING** | V3-003 (Option C) |
| **ISSUE-V3-001-03** | **P2 (MINOR)** | Stability | Boot Script Error: `add_child()` Called While Node Busy | PK_ClientLead | **OPEN** | V3-003 |
| **ISSUE-V3-001-04** | **P2 (MINOR)** | Visual / Art | Billboard Sprite3D Ground Contact & Elevation Offset | PK_ArtDirector | **OPEN** | V3-003 |
| **ISSUE-V3-001-05** | **P3 (POLISH)** | Design / Feel | Boss Commander Shield Charge Windup Telegraph Unclear | PK_GameDesign | **OPEN** | V3-003 / Polish |
| **ISSUE-V3-001-06** | **P3 (POLISH)** | Design / UI | Stage Clear Lacks Dedicated Victory / Reward Result Screen | PK_GameDesign | **OPEN** | V3-003 / Polish |
| **ISSUE-V3-001-07** | **P1 (MAJOR)** | Camera / Art | Foreground Wall / Pillar Occludes Combat Area During Boss | PK_ArtDirector / PK_ClientLead | **OPEN** | V3-003 |

**Severity Totals:** **3 P1 (MAJOR) | 2 P2 (MINOR) | 2 P3 (POLISH) — Total: 7 Unique Defects**

---

## 2. Detailed Issue Records

### ISSUE-V3-001-01: Mobile Touch Joystick & Action Buttons Missing
- **Severity:** P1 (MAJOR — Blocker for Android release target)
- **Component:** `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd` (`_setup_mobile_ui`)
- **Owner:** `PK_ClientLead`
- **Status:** **OPEN**
- **Observed Behavior:**
  - `side_qv_stage_base.gd:13` preloads `QVMobileControlsClass`, but `_setup_mobile_ui()` only creates HUD info plates, avatar, soul gems, and boss health bars. Zero virtual touch controls (on-screen joystick or buttons for Attack, Jump, Guard, Dash) are instantiated.
  - The game is completely unplayable on mobile devices without external physical keyboard/gamepad.
- **Expected Behavior:**
  - On mobile target (and in desktop touch emulation), on-screen touch controls must be instantiated in CanvasLayer `SideQVMobileUI` and dispatch corresponding action events.
- **Evidence Pointer:**
  - Original Capture: [`01_stage_entry.png`](../V3-001/captures/originals/01_stage_entry.png)
  - Playtest Log: `windowed_playtest_raw.log:22`
- **Remediation Plan:**
  - Instantiate `QVMobileControlsClass` in `_setup_mobile_ui()` and bind touch button signals to action inputs.

---

### ISSUE-V3-001-02: Core Gameplay Motion Model Discrepancy (2.5D vs 2D Plane)
- **Severity:** P1 (MAJOR — Core Architectural Discrepancy)
- **Component:** `SideQVPlayer.gd`, `SideQVCamera.gd`, `SideQVEnemy.gd`, `SideQVBoss.gd`
- **Owner:** `PK_ClientLead`
- **Status:** **DECIDED / IMPLEMENTATION_PENDING** (Option C selected by Director; code changes pending)
- **Observed Behavior:**
  - Current implementation allows free Z-axis movement across $Z \in [-4.4, 4.4]$ via `W`/`S` keys.
  - Melee attack hitboxes (`SlashVisual3D` and hurtbox collision) frequently fail to register when player and enemy Z positions differ by as little as 0.3 units, creating frustration and imprecise combat feel.
  - Mobile virtual joystick control is excessively difficult to balance in 2.5D depth.
- **Decision:**
  - `PK_GameDirector` formally selected **Option C: Visually 2.5D with Fixed 2D Horizontal Gameplay Plane constraint ($Z=0.0$)**.
- **Pending Implementation:**
  - Constrain `SideQVPlayer` and all enemies to $Z=0.0$.
  - Adjust attack hitboxes to full 2D combat plane coverage.
  - Maintain 3D background geometry, lighting, and camera perspective tilt.
  - Must remain `IMPLEMENTATION_PENDING` until code is implemented and verified in gameplay.
- **Evidence Pointer:**
  - Original Capture: [`03_depth_occlusion.png`](../V3-001/captures/originals/03_depth_occlusion.png)
  - Design Document: [`DESIGN_DECISION.md`](../V3-001/DESIGN_DECISION.md)

---

### ISSUE-V3-001-03: Script Error on Boot: `add_child()` Called While Node Is Busy
- **Severity:** P2 (MINOR — Console Error / Timing Hazard)
- **Component:** `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd`
- **Owner:** `PK_ClientLead`
- **Status:** **OPEN**
- **Observed Behavior:**
  - During scene transition from TitleScreen to Stage 1, console outputs:
    `ERROR: Can't add child '...' while parent is setting up children.`
  - Caused by synchronous node tree instantiation during `_ready()` callbacks before scene tree setup finishes.
- **Expected Behavior:**
  - Clean startup log with zero Godot engine errors or warnings.
- **Remediation Plan:**
  - Refactor child node additions to use `call_deferred("add_child", ...)` or defer initialization to first process frame.
- **Evidence Pointer:**
  - Startup Log: `windowed_playtest_raw.log:17`

---

### ISSUE-V3-001-04: Billboard Sprite3D Ground Contact & Elevation Offset during Jump
- **Severity:** P2 (MINOR — Visual Coherence)
- **Component:** `SideQVPlayer.gd` / Sprite3D Configuration
- **Owner:** `PK_ArtDirector`
- **Status:** **OPEN**
- **Observed Behavior:**
  - The 2D Paladin Sprite3D uses a fixed billboard perspective tilt. Under extreme camera angles or when jumping, the pivot point creates an apparent floating gap between the sprite's feet and the 3D floor shadow.
- **Expected Behavior:**
  - Sprite pivot and shadow caster must maintain seamless ground contact contact line during idle/run, and project realistic ground distance during jumps.
- **Evidence Pointer:**
  - Original Capture: [`04_jump.png`](../V3-001/captures/originals/04_jump.png)

---

### ISSUE-V3-001-05: Boss Commander Shield Charge Windup Lacks Sufficient Pre-Attack Telegraph
- **Severity:** P3 (POLISH — Combat Readability)
- **Component:** `SideQVBoss.gd`
- **Owner:** `PK_GameDesign`
- **Status:** **OPEN**
- **Observed Behavior:**
  - Boss Commander shield charge windup transition duration is under 200 ms, leaving insufficient reaction time for player guard/parry on mobile touch controls.
- **Expected Behavior:**
  - Clear telegraph: minimum 400 ms windup with visual cue (crimson eye flash or distinct audio cue) before collision hitbox activates.
- **Evidence Pointer:**
  - Original Capture: [`08_boss_telegraph.png`](../V3-001/captures/originals/08_boss_telegraph.png)

---

### ISSUE-V3-001-06: Stage Clear Lacks Dedicated Victory / Reward Result Screen
- **Severity:** P3 (POLISH — User Experience)
- **Component:** `SideQVCampaign.gd` / `SideQVStageBase.gd`
- **Owner:** `PK_GameDesign`
- **Status:** **OPEN**
- **Observed Behavior:**
  - Upon defeating Boss Commander, stage emits `stage_cleared` and displays brief banner, but lacks a dedicated victory screen showing combat score, clear time, soul shards acquired, and Next Stage button.
- **Expected Behavior:**
  - Rich tactical results modal presenting clear grade, rewards tally, and seamless navigation to Stage 2.
- **Evidence Pointer:**
  - Original Capture: [`10_stage_result.png`](../V3-001/captures/originals/10_stage_result.png)

---

### ISSUE-V3-001-07: Foreground Wall / Pillar Occludes Combat Area During Boss Phase
- **Severity:** P1 (MAJOR — Critical Gameplay Visibility Blocker)
- **Component:** `SideQVStage1.tscn` / `SideQVCamera.gd`
- **Owner:** `PK_ArtDirector` / `PK_ClientLead`
- **Status:** **OPEN**
- **Observed Behavior:**
  - When the player advances past $X > 8.0$ into the boss arena, a massive 3D foreground stone wall, battlement, and pillar structure directly between the camera and the gameplay plane occludes 35–40% of the screen center-right.
  - Player character and Boss Commander are repeatedly hidden behind solid masonry during active melee combat.
- **Expected Behavior:**
  - Unobstructed camera sightline during combat. Foreground geometry must either use dynamic camera see-through transparency (dither / alpha fade) or be re-architected outside the combat camera frustum.
- **Evidence Pointer:**
  - Original Capture: [`09_boss_combat.png`](../V3-001/captures/originals/09_boss_combat.png)
- **Remediation Plan:**
  - Implement material dither fade on foreground obstacles or adjust camera angle / stage geometry in V3-003.
