# V3-009 — Hands-On Combat Tuning & Mobile-Scale UI (Before / After Report)

**Repository:** `jjangmut/ProjectKnight`  
**Branch:** `studio/v3-009-combat-mobile-ui`  
**Engine:** Godot 4.7.2 stable, OpenGL3 Compatibility, Desktop 1280x720 (and 1024x720 narrow audit)  
**Operating Mode:** Option C Strict 2D Combat Plane Lock ($Z = 0.0000, v_z = 0.0000$)  

---

## 1. Executive Summary

Milestone **V3-009** advances moment-to-moment combat responsiveness, attack-cancel flexibility, and mobile-scale interface usability across the 5 completed stages. Building upon V3-008's victory replay foundation, V3-009 directly tackles control locks and missing mobile virtual controls without altering enemy stats, faking inputs, or skipping mechanics.

All improvements were tested on a real rendered window with GL Compatibility on an NVIDIA RTX 5060 GPU, preserving the five completed stages and verified by targeted and continuous end-to-end automated input suites.

---

## 2. The 3 Concrete Player-Facing Issues & Solutions

### Issue 1 (P1 Combat Feel / Usability): Attack Recovery Lockout, Missing Dash Buffer, & Air Dash Blocking
- **Location:** `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd`
- **Observed Defect:**
  1. Attack Lockout: When attacking, the player was locked in `State.ATTACK` for the entire animation duration (0.28s–0.32s). Even when an enemy telegraphed an impending strike (e.g. Arbiter Blink Strike, Golem Slam), mashing Dash or Guard was completely ignored until full animation recovery finished.
  2. Missing Dash Buffer: Jump and Attack had buffer timers, but Dash had none. Tapping Dash 50ms before landing or before attack recovery finished dropped the input entirely.
  3. Air Dash Blocked: Line 897 noted refreshing air dash, but line 390 strictly enforced `and is_on_floor()`, preventing mid-air evasion.
- **Implemented Fix:**
  - Added `dash_buffer_timer` (`DASH_BUFFER_TIME = 0.16s`) in `_update_timers()`.
  - Added **Attack Recovery Cancel**: once the attack strike frame has landed (`attack_duration_remaining <= 0.14s`), pressing Dash or Guard immediately cancels the remaining recovery into `State.DASH` or `State.GUARD`.
  - Added `can_air_dash`: enables 1 crisp airborne dash to evade ground shockwaves and ranged projectiles, refreshed upon floor landing.
- **Visual Evidence:**
  - Before: `captures/before/before_01_attack_recovery_lock.png` (Player locked in attack recovery)
  - After: `captures/after/after_01_attack_recovery_cancel.png` (Instant cancel into Dash with shadow ghost trails)

---

### Issue 2 (P1 Mobile Usability): Missing Mobile Virtual Controls Deck in Side Quarter View Stages
- **Location:** `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd`
- **Observed Defect:** In `SideQVStageBase`, `_setup_mobile_ui()` created an empty `CanvasLayer` named `SideQVMobileUI` with HUD bars and counters, but never instantiated `QVMobileControls`. Mobile/touch players had zero on-screen virtual joystick or action buttons across Stages 1–5.
- **Implemented Fix:**
  - Instantiated `TouchControlsDeck` (`QVMobileControlsClass.new()`) and attached it as a child of `mobile_controls` across all 5 stages.
  - Exposes tactical radar joystick (`move_left`, `move_right`, `move_down` for Dive Slam) and 4 tactical skill buttons: ⚔ STRIKE, 🛡 PARRY, 💨 DASH, ▲ LEAP.
- **Visual Evidence:**
  - Before: `captures/before/before_02_mobile_ui_missing_in_stage.png` (Stage HUD without touch controls)
  - After: `captures/after/after_02_mobile_touch_deck.png` (Stage 1 with complete tactical virtual controls deck)

---

### Issue 3 (P2 UI Responsiveness): Hardcoded UI Coordinates Clipping on Narrower Viewports
- **Location:** `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd`
- **Observed Defect:** `JoystickContainer` and `ActionContainer` used hardcoded absolute positions `(145.0, 535.0)` and `(1015.0, 535.0)`. On narrower viewports (such as 1024x720 or 4:3 tablets), `1015 + 88 = 1103px`, clipping the right skill cluster completely off-screen.
- **Implemented Fix:**
  - Added dynamic layout handler `_update_layout()` listening to `size_changed`.
  - Dynamically calculates container offsets relative to viewport width and height (`maxf(680.0, vp_size.x - 265.0)`), seamlessly shifting the skill deck to $X=759\text{px}$ on 1024px screens without clipping, while preserving exact $X=1015\text{px}$ on 1280x720 baseline.
- **Visual Evidence:**
  - Before: `captures/before/before_03_narrow_viewport_hud.png`
  - After: `captures/after/after_03_narrow_viewport_responsive.png` (Skill cluster comfortably positioned inside 1024px boundary)

---

## 3. Summary of Code Modifications

| File | Changes | Impact |
| :--- | :--- | :--- |
| `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd` | +28 lines | Adds `dash_buffer_timer` (0.16s), attack recovery cancel into Dash/Guard, and `can_air_dash` |
| `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd` | +6 lines | Instantiates `TouchControlsDeck` (`QVMobileControls`) in `SideQVMobileUI` across Stages 1–5 |
| `CLIENT/Game/scripts/quarter_view/qv_mobile_controls.gd` | +19 lines | Implements `_update_layout()` with dynamic viewport anchoring preventing narrow screen clipping |

---

## 4. Boss Threat Window Duration Audit

Exact elapsed time from warning/telegraph startup to damage window:
- **Abyssal Arbiter Shadow Blink Strike:** **300ms** (0.30s pre-swing telegraph + crimson-gold aura ring).
- **Abyssal Arbiter Dark Crescent Wave:** **320ms** (0.32s pre-spawn charge telegraph).
- **Golem Guardian Ground Slam:** **420ms** (0.42s arms-raised windup + warning ring).
- *All measured boss threat windows exceed standard human visual reaction time ($\ge 250\text{ms}$), guaranteeing fair counterplay.*
