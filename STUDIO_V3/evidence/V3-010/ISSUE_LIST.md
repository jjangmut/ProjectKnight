# V3-010 — Issue List & Residual Risk Disclosures

**Repository:** `jjangmut/ProjectKnight`  
**Branch:** `studio/v3-010-touch-combat-onboarding`  
**Milestone:** V3-010 Reliable Multi-Touch Combat & First-Play Readability  

---

## 1. Resolved Issues in V3-010

| Issue ID | Severity | Category | Summary | Status | Resolution File |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **V3-010-ISSUE-01** | **P0 (BLOCKER)** | Touch Input | Double dispatch vulnerability: Action Buttons connected `button_down/up` signals while `_input` also routed screen touch events. | **RESOLVED** | `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd` |
| **V3-010-ISSUE-02** | **P0 (BLOCKER)** | Touch Input | Under mouse/touch emulation, an incoming mouse event overwrote `drag_touch_index` to 999 while touch pointer 0 was active, causing touch release to fail and locking joystick drag permanently. | **RESOLVED** | `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd` |
| **V3-010-ISSUE-03** | **P1 (MAJOR)** | Stage Architecture | `SideQVStage1` instantiated two duplicate `QVMobileControls` instances (`TouchControlsDeck` + `MobileControlsHUD`), doubling event delivery and desynchronizing toggle state. | **RESOLVED** | `CLIENT/Game/scripts/side_quarter_view/stages/side_qv_stage_1.gd` |
| **V3-010-ISSUE-04** | **P1 (MAJOR)** | First-Play UX | Stage 1 had zero on-screen tactical onboarding or keybind guidance for new players. | **RESOLVED** | `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd` |
| **V3-010-ISSUE-05** | **P2 (MINOR)** | Touch Input | Sliding a thumb across skill buttons did not transition actions, and dragging into empty space did not release held virtual actions. | **RESOLVED** | `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd` |
| **V3-010-ISSUE-06** | **P2 (MINOR)** | Window Life Cycle | Lost window focus (`NOTIFICATION_APPLICATION_FOCUS_OUT`) failed to clear virtual actions or reset the joystick. | **RESOLVED** | `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd` |
| **V3-010-ISSUE-07** | **P2 (MINOR)** | Combat Semantics | `dash_buffer_timer` and input buffers were not cleared on entering `_enter_death_state()`. | **RESOLVED** | `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd` |

---

## 2. Residual Issues & Mandatory Honest Disclosures

### A. `ANDROID_HARDWARE_NOT_TESTED`
- **Scope:** All mobile multi-touch event routing, slide transitions, and responsive layout calculations were validated inside Godot 4.7.2 stable GL Compatibility renderer on Windows 11 desktop (`1280x720` baseline and `1024x720` narrow window emulation) using simulated `InputEventScreenTouch` and `InputEventScreenDrag` pointer events.
- **Residual Risk:** Real Android physical touch digitization latency, thermal throttling under sustained gameplay, Mali/Adreno OpenGL ES driver variations, and physical screen notch / rounded display cutout insets have **NOT** been verified on physical Android hardware.

### B. `HUMAN_PLAYTEST_NOT_VERIFIED`
- **Scope:** All 5-stage playthroughs, combat combos, parries, cancels, and multi-touch combinations were executed via Godot deterministic engine input events (`InputEventScreenTouch`, `Input.parse_input_event()`, `gui_input()`, and scripted test agents).
- **Residual Risk:** Natural human multi-finger ergonomics, thumb fatigue on mobile glass displays, and subjective layout preference across varying hand sizes remain unverified by external human playtesting panels.

### C. `COMMERCIAL_RELEASE_READINESS_NOT_CLAIMED`
- **Scope:** ProjectKnight is currently a complete 5-stage vertical slice demonstrating Option C 2.5D mechanics, responsive melee combat, and robust multi-touch virtual controls.
- **Residual Risk:** Production sound mix, multi-language localization, cloud save integration, settings menus, and Google Play Store packaging are out-of-scope for this milestone and remain future production roadmap items.
