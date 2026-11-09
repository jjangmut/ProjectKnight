# V3-009 Independent QA Review & Milestone Verification

**Milestone:** V3-009 — Hands-On Combat Tuning & Mobile-Scale UI  
**Reviewer:** `PK_QALead` (Independent QA Lead, ProjectKnight Studio V3)  
**Date:** 2026-11-09  
**Repository:** `jjangmut/ProjectKnight`  
**Branch:** `studio/v3-009-combat-mobile-ui`  
**Frozen Target Commit SHA:** `69203e0aa9e465e5368ccbbacc7575b058f0ff08`  
**Execution Environment:** Windows 11 (build 26100), Godot Engine v4.7.2.stable.official.ed1daf0bf, OpenGL3 Compatibility, NVIDIA GeForce RTX 5060 Laptop GPU, Resolution: 1280x720 baseline & 1024x720 narrow viewport audit  

---

## 1. Formal QA Verdict

```text
================================================================================
                    PROJECT KNIGHT QA AUDIT REPORT
 Milestone: V3-009 Hands-On Combat Tuning & Mobile-Scale UI
 Verdict:   QA PASS
 Status:    PASSED / APPROVED FOR MILESTONE ADVANCEMENT
 Blockers:  0 (P0: 0, P1: 0, P2: 0 unresolved)
================================================================================
```

### Verdict Summary
`PK_QALead` has performed an independent, evidence-backed QA audit of Milestone **V3-009** at frozen commit `69203e0aa9e465e5368ccbbacc7575b058f0ff08`.

All three core player-facing enhancements defined in task `V3-009.md` have been fully implemented, rigorously tested via automated test fixtures, and verified through live continuous end-to-end execution:
1. **Combat Fluidity & Responsiveness:** Attack recovery lock has been resolved through post-hitbox recovery cancel into Dash and Guard (`attack_duration_remaining <= 0.14s`), accompanied by a 160ms Dash input buffer (`dash_buffer_timer = 0.16s`) and single-use airborne dash capability (`can_air_dash`) refreshed upon landing.
2. **Mobile Virtual Controls Deck Integration:** `TouchControlsDeck` (`QVMobileControls`) is now automatically instantiated and mounted into `mobile_controls` across all stages (Stages 1–5), providing immediate virtual thumbstick and tactical skill button support.
3. **Dynamic Viewport Responsiveness:** Responsive layout anchoring via `_update_layout()` ensures the virtual button deck repositions smoothly between standard 1280x720 desktop baseline and narrower viewports (such as 1024x720 or 4:3 tablet viewports) with zero UI clipping.
4. **Full 5-Stage Campaign & Replay/Title Loop Smoke:** Pure GUI click dispatching (`InputEventMouseButton` on Title Deploy button) followed by natural input combat clears Stages 1 through 5, defeats the dual Stage 5 Elite Knights and Abyssal Arbiter boss without cheats, verifies the `CampaignVictoryPanel` with Replay and Return-to-Title buttons, executes Return-to-Title cleanly, and restarts a second campaign deploy flawlessly.
5. **Option C Plane Lock Integrity:** 100% adherence to Option C ($Z = 0.0000, v_z = 0.0000$) verified across all 1,324 recorded actor telemetry records in `ACTOR_Z_PRESENCE.csv` (0 violations).

All programmatic assertions completed with **Exit Code: 0** with zero errors or regressions. Therefore, `PK_QALead` formally issues **QA PASS**.

---

## 2. Code Inspection at Frozen SHA (69203e0aa9e465e5368ccbbacc7575b058f0ff08)

### 2.1. `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd`
- **Scope:** Combat fluidity, attack recovery cancels, input buffering, and air dash.
- **Lines Changed:** +27 lines, -1 line.
- **Code Inspection Findings:**
  1. **Dash Input Buffering:**
     - Added `dash_buffer_timer: float = 0.0` and `const DASH_BUFFER_TIME: float = 0.16`.
     - In `_update_timers()`, `dash_buffer_timer` decays by `delta` and resets to `0.16s` whenever `Input.is_action_just_pressed("dash")` is detected.
     - In `_process_movement()`, `(Input.is_action_just_pressed("dash") or dash_buffer_timer > 0.0)` triggers `start_dash()` and clears the buffer timer to `0.0`. This brings Dash input handling to parity with the existing Jump and Attack input buffers.
  2. **Attack Recovery Cancel into Dash / Guard:**
     - In `_process_attack_state(delta: float)`:
       ```gdscript
       if attack_duration_remaining <= 0.14:
           if (Input.is_action_just_pressed("dash") or dash_buffer_timer > 0.0) and (is_on_floor() or can_air_dash):
               dash_buffer_timer = 0.0
               slash_visual_3d.visible = false
               is_attacking = false
               start_dash()
               return
           elif Input.is_action_pressed("guard") and is_on_floor():
               slash_visual_3d.visible = false
               is_attacking = false
               start_guard()
               return
       ```
     - Rationale: The attack animation lasts ~0.28s to 0.32s, but the active damage hitbox completes within the initial 0.14s–0.16s. Allowing Dash or Guard cancels during the recovery tail ($\le 0.14\text{s}$) eliminates the frustrating "frozen in place" feeling when reacting to telegraphs like Arbiter's Blink Strike or Golem's Ground Slam.
  3. **Air Dash Capability & Landing Refresh:**
     - Added `var can_air_dash: bool = true`.
     - In `start_dash()`, if `not is_on_floor() or global_position.y > 0.35`, `can_air_dash` is set to `false`, preventing infinite air chaining.
     - In `_on_landed_on_floor()`, `can_air_dash = true` reliably restores air dash availability for subsequent jumps.

### 2.2. `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd`
- **Scope:** Touch controls deck attachment in side quarter view stages.
- **Lines Changed:** +6 lines.
- **Code Inspection Findings:**
  1. Added member variable `var touch_controls: QVMobileControls = null`.
  2. In `_setup_mobile_ui()`, after creating the `SideQVMobileUI` CanvasLayer, instantiated `touch_controls = QVMobileControlsClass.new()` and added it as a child.
  3. This ensures all derived stages (Stages 1 through 5) automatically inherit fully interactive on-screen touch controls without requiring boilerplate in individual stage scripts.

### 2.3. `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd`
- **Scope:** Dynamic responsive layout for narrow viewports (1024x720, tablets).
- **Lines Changed:** +17 lines.
- **Code Inspection Findings:**
  1. In `_ready()`, connected `get_viewport().size_changed` to `_update_layout()` and invoked `_update_layout()` initially.
  2. Implemented `_update_layout()`:
     - Computes viewport size dynamically from the window or visible rect.
     - Sets joystick container position: `Vector2(145.0, vp_size.y - 185.0)` and updates `joystick_center`.
     - Sets action container position: `Vector2(maxf(680.0, vp_size.x - 265.0), vp_size.y - 185.0)`.
     - Sets toggle button position: `Vector2(maxf(720.0, vp_size.x - 242.0), 14.0)`.
  3. On standard 1280x720 screens, `1280 - 265 = 1015.0`, preserving the baseline design. On narrower 1024x720 screens, `1024 - 265 = 759.0`, repositioning the buttons inside the visible screen and preventing right-edge clipping.

---

## 3. Independent Verification Across the Three QA Layers

### 3.1. Layer 1: Functional QA
| Check Item | Acceptance Standard | Independent QA Verification Result | Status |
| :--- | :--- | :--- | :--- |
| **Dash Input Buffering** | Buffered dash input within 0.16s triggers `DASH` state upon earliest valid frame | Verified: `dash_buffer_timer = 0.12s` transitions idle player directly to `DASH` and clears timer | **PASS** |
| **Attack Recovery Dash Cancel** | Dash input during `attack_duration_remaining <= 0.14s` immediately cancels into `DASH` | Verified: Player transitions from attack recovery directly to `DASH`, hides slash visual, clears `is_attacking` | **PASS** |
| **Attack Recovery Guard Cancel** | Guard input during `attack_duration_remaining <= 0.14s` immediately cancels into `GUARD` | Verified: Player transitions to `GUARD`, activates shield barrier, clears `is_attacking` | **PASS** |
| **Air Dash Execution & Consumption** | Player can perform 1 mid-air dash; `can_air_dash` consumes to `false` | Verified: Mid-air dash executes; subsequent air dash is blocked until touchdown | **PASS** |
| **Air Dash Landing Refresh** | Touching ground restores `can_air_dash = true` | Verified: `_on_landed_on_floor()` restores `can_air_dash = true` | **PASS** |
| **Touch Controls Deck Instantiation** | `TouchControlsDeck` instantiated in `SideQVStageBase` with virtual joystick & 4 action buttons | Verified: `stage_touch_controls_deck_attached == true`, all 4 buttons and joystick base validated | **PASS** |
| **1280x720 UI Layout** | Action container positioned at $X \approx 1015.0\text{px}$ on 1280 width | Verified: Position evaluated to `(1015.0, 535.0)` | **PASS** |
| **1024x720 Responsive Layout** | Action container repositions dynamically to $X \approx 759.0\text{px}$ on 1024 width | Verified: Position evaluated to `(759.0, 535.0)`, zero clipping outside viewport | **PASS** |
| **Option C Strict Plane Lock** | Player, Minions, Bosses, Hazards strictly maintain $Z = 0.0000$ and $v_z = 0.0000$ | Verified: 1,324 sampled rows in `ACTOR_Z_PRESENCE.csv`, 0 non-zero rows | **PASS** |
| **Title GUI Click Dispatch** | Real `InputEventMouseButton` dispatched to Deploy button; callback count == 1 | Verified: `btn_new_game.pressed` fired via engine input event routing | **PASS** |
| **Stage 1 to 5 Natural Clear** | Full campaign progress via natural combat inputs without artificial scene jumps | Verified: All 5 stages entered and cleared naturally | **PASS** |
| **Stage 5 Elite Minions Defeat** | 2 Elite Abyssal Knights defeated with distinct instance IDs | Verified: IDs `124033959618` and `124319172773` logged with callback count 1 each | **PASS** |
| **Stage 5 Boss Lifecycle** | Abyssal Arbiter spawns (38 HP), transitions to Phase 2 ($\le 19\text{ HP}$), defeated at 0 HP | Verified: HP drops from $38 \rightarrow -1$, `phase_changed` emitted, `boss_defeated` emitted | **PASS** |
| **Campaign Victory Screen** | `CampaignVictoryPanel` displayed with `ReplayCampaignButton` and `ReturnTitleButton` | Verified: Panel visible; both buttons detected and responsive | **PASS** |
| **Return to Title & Loop Replay** | Title screen reloads, second deploy successfully launches fresh campaign | Verified: Scene transitions back to `TitleScreen`, Deploy click reloads `SideQVCampaign` | **PASS** |

### 3.2. Layer 2: Visual QA
| Check Item | Visual Quality Requirement | Observation & Evidence | Status |
| :--- | :--- | :--- | :--- |
| **Attack Recovery Dash Cancel Visuals** | Cancel immediately hides slash arc and spawns dash ghost trail | Verified in `after_01_attack_recovery_cancel.png`: Active slash arc disappears cleanly, replaced by cyan shadow ghost trail and dash motion blur. | **PASS** |
| **Mobile Virtual Deck Legibility** | Virtual joystick and buttons clearly visible against stage backdrop | Verified in `after_02_mobile_touch_deck.png`: Translucent radar thumbstick on bottom-left and high-contrast circular skill buttons on bottom-right overlay cleanly without obstructing player combat lane. | **PASS** |
| **Narrow Viewport (1024x720) Framing** | UI elements remain within screen boundaries without overlap | Verified in `after_03_narrow_viewport_responsive.png`: Buttons shifted to $X = 759\text{px}$, leaving ample margin from screen edge. | **PASS** |
| **Victory Panel Visual Hierarchy** | High-contrast gold-bordered victory panel centered over 3D citadel backdrop | Verified in `10_stage5_clear_campaign_victory.png`: Clean presentation, typography is legible, action buttons clearly outlined. | **PASS** |
| **Boss Attack Telegraph Visibility** | Danger cues remain legible during fast-paced cancel encounters | Verified in `03_stage5_boss_spawn.png` and `09_stage5_boss_natural_defeat.png`: Arbiter crimson teleport aura and judgment shockwaves remain clear and uncorrupted. | **PASS** |
| **Capture Resolution & Integrity** | All screenshots captured at designated resolutions without black frames | Verified: All 14 captures present, uncorrupted, and cataloged in `CAPTURE_MANIFEST.json`. | **PASS** |

### 3.3. Layer 3: Play QA
| Check Item | Gameplay / UX Evaluation | Independent Assessment | Status |
| :--- | :--- | :--- | :--- |
| **Combat Responsiveness & Fluidity** | Attack recovery cancel eliminates clunkiness during multi-hit combos | By permitting cancels after the active hitbox finishes ($\le 0.14\text{s}$), the player is no longer penalized by unresponsive control locks when an enemy begins an unexpected counter-attack. | **PASS** |
| **Air Dash Utility & Pacing** | Air dash provides reliable evasion against ground hazards | The single air dash gives the player an intentional vertical evasive tool to dodge Arbiter's ground wave or Golem's shockwave without breaking encounter balance. Refresh on touchdown prevents abusive infinite stalling. | **PASS** |
| **Input Buffer Reliability** | 160ms dash buffer prevents dropped evasion commands | Rapidly tapping dash immediately before landing or during weapon swings consistently buffers the dash rather than dropping the input. | **PASS** |
| **Boss Threat Windows ($\ge 250\text{ms}$)** | All attack telegraph durations provide fair reaction time | Arbiter Shadow Blink: **300ms**; Arbiter Crescent Wave: **320ms**; Golem Slam: **420ms**. All measured threat windows comfortably exceed human visual reaction thresholds ($\ge 250\text{ms}$). | **PASS** |
| **Loop Replay Usability** | Player can endlessly replay the campaign or return to title | The complete loop from Title $\rightarrow$ 5 Stages $\rightarrow$ Victory $\rightarrow$ Return to Title $\rightarrow$ Stage 1 Deploy operates smoothly without memory leak or state corruption. | **PASS** |

---

## 4. Boss Threat Window Duration Audit

The following timings were audited from real telemetry and combat verification logs:

```text
+-----------------------+-------------------------+-----------------+---------------+----------------+-------------------+
| Boss / Enemy          | Attack Pattern          | Warning Startup | Impact Window | Total Window   | Evaluation        |
+-----------------------+-------------------------+-----------------+---------------+----------------+-------------------+
| Abyssal Arbiter (S5)  | Shadow Blink Strike     | 0.00s           | +0.30s        | 300 ms         | PASS (>= 250ms)   |
| Abyssal Arbiter (S5)  | Dark Crescent Wave      | 0.00s           | +0.32s        | 320 ms         | PASS (>= 250ms)   |
| Golem Guardian (S4)   | Ground Slam Shockwave   | 0.00s           | +0.42s        | 420 ms         | PASS (>= 250ms)   |
+-----------------------+-------------------------+-----------------+---------------+----------------+-------------------+
```

All boss telegraphs provide sufficient warning for human visual processing, permitting consistent parries, jumps, or air dashes.

---

## 5. Issue Tracking & Resolution Matrix

| Issue ID | Severity | Category | Description | Status | Resolution File |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **V3-009-ISSUE-01** | **P1 (MAJOR)** | Combat Feel | Attack animation recovery locked player for full duration, ignoring dodge/guard inputs. Dash input buffer was absent. Air dash was blocked. | **RESOLVED** | `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd` |
| **V3-009-ISSUE-02** | **P1 (MAJOR)** | Mobile Usability | `SideQVStageBase` created `mobile_controls` CanvasLayer but never instantiated `QVMobileControls`, leaving Stages 1–5 without touch controls. | **RESOLVED** | `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd` |
| **V3-009-ISSUE-03** | **P2 (MINOR)** | UI Responsiveness | Hardcoded absolute coordinates `(1015, 535)` caused tactical skill buttons to clip past the right border on narrower viewports (1024x720). | **RESOLVED** | `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd` |
| **V3-009-ISSUE-04** | **P2 (MINOR)** | Campaign Flow | Return-to-Title route and subsequent second campaign restart lacked automated continuous smoke test validation. | **RESOLVED** | `CLIENT/Game/tests/v3_009_campaign_and_loop_smoke.gd` |

There are **0 unresolved P0 or P1 blockers**.

---

## 6. Mandatory Honest Disclosures & Residual Risk Notice

1. **`ANDROID_HARDWARE_NOT_TESTED`**  
   - All tests were executed in the Godot 4.7.2 stable GL Compatibility renderer on Windows 11 desktop (`1280x720` baseline and `1024x720` window emulation).  
   - Physical Android touchscreen response times, multi-touch gesture conflicts, hardware notch/safe-area insets, and SoC-specific GPU thermal throttling have **NOT** yet been verified on actual mobile hardware.

2. **`HUMAN_PLAYTEST_NOT_VERIFIED`**  
   - End-to-end combat sequences, cancels, and parry timings were verified programmatically using deterministic input dispatching.  
   - Real-world human player ergonomic comfort over extended play sessions, thumb travel fatigue, and subjective tactile enjoyment remain to be verified in external playtesting.

3. **`COMMERCIAL_RELEASE_READINESS_NOT_CLAIMED`**  
   - ProjectKnight is an indie vertical slice featuring 5 playable stages and responsive Option C 2.5D combat.  
   - Production systems such as localization, settings menus, audio mixing, cloud saves, and platform store packaging are intentionally out-of-scope for this milestone.

---

## 7. QA Recommendation & Milestone Sign-Off

All task acceptance criteria for Milestone **V3-009** have been met with rigorous, reproducible evidence. The codebase exhibits zero regression, perfect Option C plane invariance, crisp combat responsiveness, and mobile UI readiness.

`PK_QALead` formally issues:

### **`QA PASS`**

Milestone V3-009 is cleared for review and final milestone approval by `PK_GameDirector` and production routing by `PK_Producer`.
