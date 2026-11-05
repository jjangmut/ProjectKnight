# V3-001 — Playable Baseline Issues Tracker

**Task ID:** `V3-001`  
**Date:** 2026-11-06  
**Audited Source SHA:** `a71223615d0b77e36dd85edb24e138fc67ecc140`  
**Audit Scope:** Real Windowed Godot 4.7.2 Playable Audit (`CLIENT/Game/`)  

---

## Issue Summary Matrix

| Issue ID | Severity | Title | Owner | Status |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-V3-001-01** | **P1 (MAJOR)** | Mobile UI Overlay Lacks Virtual Touch Joystick & Action Buttons in Stage 1 | PK_ClientLead | OPEN |
| **ISSUE-V3-001-02** | **P1 (MAJOR)** | Core Gameplay Motion Model Discrepancy (2.5D Belt-Scroll vs 2D Action Plane) | PK_ClientLead | RESOLVED (Decision: Option C) |
| **ISSUE-V3-001-03** | **P2 (MINOR)** | Script Error on Boot: `add_child()` Called While Node Is Busy Setting Up Children | PK_ClientLead | OPEN |
| **ISSUE-V3-001-04** | **P2 (MINOR)** | Billboard Sprite3D Ground Contact & Elevation Offset during Jump | PK_ArtDirector | OPEN |
| **ISSUE-V3-001-05** | **P3 (POLISH)** | Boss Commander Shield Charge Windup Lacks Sufficient Pre-Attack Telegraph | PK_GameDesign | OPEN |
| **ISSUE-V3-001-06** | **P3 (POLISH)** | Stage Clear Lacks Dedicated Victory / Reward Result Screen in Campaign Loop | PK_GameDesign | OPEN |
| **ISSUE-V3-001-07** | **P1 (MAJOR)** | Foreground Wall / Pillar Severely Occludes Combat Area During Boss Phase | PK_ArtDirector / PK_ClientLead | OPEN |
| **ISSUE-V3-001-07** | **P1 (MAJOR)** | Foreground Wall/Pillar Completely Occludes Combat during Boss Phase | PK_ArtDirector | OPEN |
| **ISSUE-V3-001-07** | **P1 (MAJOR)** | Foreground Wall/Pillar Completely Occludes Combat during Boss Phase | PK_ArtDirector | OPEN |

---

## Detailed Issue Reports

### ISSUE-V3-001-01: Mobile UI Overlay Lacks Virtual Touch Joystick & Action Buttons
- **Severity:** P1 (MAJOR — Critical Blocker for Android Release Target)
- **Component:** `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd` (`_setup_mobile_ui`)
- **Owner:** `PK_ClientLead`
- **Reproduction Steps:**
  1. Boot game with `--path CLIENT/Game`.
  2. Click "DEPLOY 3D QV" on Title Screen to enter Stage 1.
  3. Observe CanvasLayer `SideQVMobileUI`.
- **Expected Behavior:**
  - On mobile target (1280x720), on-screen touch controls (virtual D-pad/joystick and Attack/Jump/Guard/Dash buttons) should be instantiated and visible to allow touch gameplay.
- **Actual Behavior:**
  - `side_qv_stage_base.gd:13` imports `QVMobileControlsClass`, but `_setup_mobile_ui()` only creates `player_hud`, `prog_root`, `boss_health_bar`, `advance_banner`, `ax_btn`, and `combo_hud`. No touch controls are instantiated. The game is unplayable on mobile touchscreens without external hardware keyboard/gamepad.
- **Evidence:**
  - Capture: `STUDIO_V3/evidence/V3-001/captures/originals/01_stage_entry.png`
  - Source: `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd:204-387`
- **Recommended Fix:**
  - Instantiate `MobileControls.tscn` or `QVMobileControlsClass` in `_setup_mobile_ui()` and bind touch button signals to action presses.

---

### ISSUE-V3-001-02: Core Gameplay Motion Model Discrepancy (2.5D Belt-Scroll vs 2D Action Plane)
- **Severity:** P1 (MAJOR — Creative & Architectural Discrepancy)
- **Component:** `SideQVPlayer.gd`, `SideQVCamera.gd`, `SideQVEnemy.gd`
- **Owner:** `PK_ClientLead` / `PK_GameDirector`
- **Reproduction Steps:**
  1. Enter Stage 1.
  2. Press W / S keys to move along Z-axis.
  3. Attempt melee attack against enemy on differing Z-lane.
- **Expected Behavior:**
  - Project specification dictates "Fixed Side-Scrolling Gameplay Plane" for fast, readable melee combat and mobile ergonomics.
- **Actual Behavior:**
  - Player moves freely in $Z$ (`move_speed_z: 4.8 m/s`). In the -32° camera pitch, moving in depth shifts character vertical screen coordinates, causing melee attacks to miss enemies due to Z-offset misalignment.
- **Evidence:**
  - Capture: `STUDIO_V3/evidence/V3-001/captures/originals/03_depth_occlusion.png`
  - Design Document: `STUDIO_V3/evidence/V3-001/DESIGN_DECISION.md`
- **Resolution Status:**
  - **Decided by PK_GameDirector:** Option C (Visually 2.5D with 2D horizontal gameplay plane constraint) selected for `V3-003` implementation.

---

### ISSUE-V3-001-03: Script Error on Boot: `add_child()` Called While Node Busy Setting Up Children
- **Severity:** P2 (MINOR)
- **Component:** `CLIENT/Game/scripts/ui/title_screen.gd:38`, `CLIENT/Game/scripts/audio/audio_manager.gd:47`
- **Owner:** `PK_ClientLead`
- **Reproduction Steps:**
  1. Launch game from `TitleScreen.tscn`.
  2. Check engine console output.
- **Expected Behavior:**
  - Clean startup with zero GDScript errors or warnings.
- **Actual Behavior:**
  - Engine logs: `ERROR: Parent node is busy setting up children, add_child() failed. Consider using add_child.call_deferred(child) instead. at: add_child (scene/main/node.cpp:1721). Backtrace: ensure_manager (audio_manager.gd:47), _ready (title_screen.gd:38)`.
- **Evidence:**
  - Log: `STUDIO_V3/evidence/V3-001/test_logs/startup_import_raw.log` (lines 9-13)
- **Recommended Fix:**
  - Change `parent.add_child(manager)` to `parent.add_child.call_deferred(manager)` in `audio_manager.gd`.

---

### ISSUE-V3-001-04: Billboard Sprite3D Ground Contact & Elevation Offset during Jump
- **Severity:** P2 (MINOR — Visual Grounding)
- **Component:** `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd:147-160`
- **Owner:** `PK_ArtDirector`
- **Reproduction Steps:**
  1. Run near the front curb boundary ($Z \approx 4.0$).
  2. Execute Jump (Space).
- **Expected Behavior:**
  - Sprite3D feet maintain flush contact with flagstone floor without clipping or floating.
- **Actual Behavior:**
  - With `billboard = BaseMaterial3D.BILLBOARD_FIXED_Y`, perspective tilting causes sprite feet to slightly penetrate floor polygons when near viewport bottom, or float slightly when moving to rear balustrade.
- **Evidence:**
  - Capture: `STUDIO_V3/evidence/V3-001/captures/originals/04_jump.png`
- **Recommended Fix:**
  - Adjust Sprite3D vertical offset from `0.874` to `0.85` or use custom Y-billboard shader with depth-offset compensation.

---

### ISSUE-V3-001-05: Boss Commander Shield Charge Windup Lacks Sufficient Pre-Attack Telegraph
- **Severity:** P3 (POLISH — Combat Readability)
- **Component:** `CLIENT/Game/scripts/side_quarter_view/side_qv_boss.gd:SHIELD_CHARGE`
- **Owner:** `PK_GameDesign` / `PK_ArtDirector`
- **Reproduction Steps:**
  1. Trigger Wave 2 Boss Commander encounter.
  2. Observe transition into `SHIELD_CHARGE` pattern.
- **Expected Behavior:**
  - Distinct anticipation pose (flashing eyes/shield glow) for ~0.4s prior to high-speed dash (12 m/s).
- **Actual Behavior:**
  - Charge begins abruptly, requiring near-instantaneous parry reaction without sufficient visual warning cue.
- **Evidence:**
  - Capture: `STUDIO_V3/evidence/V3-001/captures/originals/08_boss_telegraph.png`
- **Recommended Fix:**
  - Add 0.35s charge windup state with crimson shield flash before physics velocity is applied.

---

### ISSUE-V3-001-06: Stage Clear Lacks Dedicated Victory / Reward Result Screen in Campaign Loop
- **Severity:** P3 (POLISH — Flow & Progression)
- **Component:** `CLIENT/Game/scripts/side_quarter_view/side_qv_campaign.gd:87-100`
- **Owner:** `PK_GameDesign`
- **Reproduction Steps:**
  1. Defeat Boss Commander in Stage 1.
  2. Wait for stage resolution.
- **Expected Behavior:**
  - Modal victory fanfare, score summary, soul shard acquisition, and button to advance to Stage 2.
- **Actual Behavior:**
  - `_on_stage_cleared` prints log message and automatically loads Stage 2 after 1.8 seconds without player acknowledgment or reward display.
- **Evidence:**
  - Capture: `STUDIO_V3/evidence/V3-001/captures/originals/10_stage_result.png`
- **Recommended Fix:**
  - Implement a dedicated Stage Clear Result Modal with reward summary and "Continue to Next Operation" button.

---

### ISSUE-V3-001-07: Foreground Wall/Pillar Completely Occludes Combat during Boss Phase
- **Severity:** P1 (MAJOR — Visual Quality Gate Blocker)
- **Component:** CLIENT/Game/scenes/side_quarter_view/SideQVStage1.tscn / SideQVCamera.gd
- **Owner:** PK_ArtDirector / PK_ClientLead
- **Reproduction Steps:**
  1. Advance into Wave 2 Boss Arena ($X > 8.0).
  2. Engage Boss Commander.
  3. Observe foreground camera framing.
- **Expected Behavior:**
  - Foreground scenery (pillars, walls, parapets) must never obstruct the player's view of combat. Foreground meshes should have camera dither/transparency fade, or the camera path/stage geometry should keep foreground walls out of the line of sight.
- **Actual Behavior:**
  - In 08_boss_telegraph.png, 09_boss_combat.png, and 10_stage_result.png, a massive foreground stone architectural pillar/wall blocks 35–40% of the screen center/right, completely obscuring the player and boss during combat.
- **Evidence:**
  - Captures: STUDIO_V3/evidence/V3-001/captures/originals/08_boss_telegraph.png, 09_boss_combat.png, 10_stage_result.png
- **Recommended Fix:**
  - Add dither transparency shader (StandardMaterial3D distance fade / proximity fade) or adjust camera horizontal/pitch offset to eliminate foreground occlusion.

---

*Verified by PK_Producer & PK_GameDirector on 2026-11-06*
