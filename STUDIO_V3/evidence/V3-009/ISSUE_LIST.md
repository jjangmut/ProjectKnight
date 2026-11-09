# V3-009 — Issue List & Residual Risk Disclosures

**Repository:** `jjangmut/ProjectKnight`  
**Branch:** `studio/v3-009-combat-mobile-ui`  
**Milestone:** V3-009 Hands-On Combat Tuning & Mobile-Scale UI  

---

## 1. Resolved Issues in V3-009

| Issue ID | Severity | Category | Summary | Status | Resolution File |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **V3-009-ISSUE-01** | **P1 (MAJOR)** | Combat Feel | Attack animation recovery locked player for full duration (0.28-0.32s), ignoring dodge/guard inputs against incoming boss strikes. Dash input buffer was missing. Air dash was blocked. | **RESOLVED** | `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd` |
| **V3-009-ISSUE-02** | **P1 (MAJOR)** | Mobile Usability | `SideQVStageBase` created `mobile_controls` CanvasLayer but never instantiated `QVMobileControls`, leaving Stages 1–5 without on-screen touch controls. | **RESOLVED** | `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd` |
| **V3-009-ISSUE-03** | **P2 (MINOR)** | UI Responsiveness | Absolute coordinates `(1015, 535)` caused tactical skill buttons to clip past the right border on narrower viewports (1024x720). | **RESOLVED** | `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd` |
| **V3-009-ISSUE-04** | **P2 (MINOR)** | Campaign Flow | Return-to-Title route and subsequent second campaign restart lacked continuous smoke test validation. | **RESOLVED** | `CLIENT/Game/tests/v3_009_campaign_and_loop_smoke.gd` |

---

## 2. Boss Threat Window Audit

Measured in natural combat and test telemetry:

| Boss / Hazard | Attack Pattern | Warning Startup | Damage Impact | Threat Window | Evaluation ($\ge 250\text{ms}$) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Abyssal Arbiter** (Stage 5) | Shadow Blink Strike | 0.00s (Crimson warning aura) | +0.30s (Scythe arc impact) | **300 ms** | **PASS** (Clear visual cue) |
| **Abyssal Arbiter** (Stage 5) | Dark Crescent Wave | 0.00s (Dark charge aura) | +0.32s (Projectile launch) | **320 ms** | **PASS** (Clear telegraph) |
| **Golem Guardian** (Stage 2) | Ground Slam Shockwave | 0.00s (Arms raised telegraph) | +0.42s (Ground impact) | **420 ms** | **PASS** (Generous jump/air-dash window) |

---

## 3. Residual Issues & Mandatory Honest Disclosures

### A. `ANDROID_HARDWARE_NOT_TESTED`
- **Scope:** All mobile UI and responsive layout tests were executed inside Godot 4.7.2 stable GL Compatibility renderer on Windows 11 desktop (`1280x720` baseline and `1024x720` narrow window emulation).
- **Residual Risk:** Real Android touch event latency, thermal throttling, GPU driver shader quirks (e.g. Mali/Adreno OpenGL ES implementations), and physical notch/safe-area insets have **NOT** been validated on physical Android hardware.

### B. `HUMAN_PLAYTEST_NOT_VERIFIED`
- **Scope:** All E2E playthroughs, combat combos, cancels, and victory loop validations were executed via Godot deterministic engine input events (`Input.parse_input_event()`, `gui_input()`, and scripted agent controllers).
- **Residual Risk:** Subjective human muscle-memory comfort, finger fatigue during prolonged touch control sessions, and natural human reaction variability remain unverified by external playtesting panels.

### C. `COMMERCIAL_RELEASE_READINESS_NOT_CLAIMED`
- **Scope:** ProjectKnight is currently a complete 5-stage vertical slice demonstrating Option C 2.5D mechanics, responsive melee combat, and progressive difficulty.
- **Residual Risk:** Localization, sound effects/audio mixing polish, cloud saves, settings menus, and store publishing packaging are not part of this milestone and remain future production items.
