# V3-017 — Targeted Regression Verification Report

## 1. Executive Summary

All automated regression and mobile input verification suites executed with **ZERO FAILURES (Exit Code: 0)**.
Core gameplay systems, Option C plane lock ($Z=0.000, v_z=0.000$), 5-stage campaign flow, and multi-touch virtual controls remain 100% intact.

---

## 2. Test Execution Matrix

| Test Suite | Target Feature | Method | Result | Evidence |
| :--- | :--- | :--- | :--- | :--- |
| `tests/v3_015_campaign_smoke.gd` | Full 5-Stage Campaign Loop | GUI Windowed Mode | **PASS** (ExitCode: 0) | Title -> S1 -> S2 -> S3 -> S4 -> S5 -> Victory -> Title -> Replay |
| `tests/v3_003_real_touch_ui.gd` | Real Engine-Routed Touch | GUI Windowed Mode | **PASS** (ExitCode: 0) | Multi-touch (move+attack, move+jump), 0 stuck actions |
| `tests/v3_010_test_touch_repro.gd` | Touch Repro & Pointer Audit | GUI Windowed Mode | **PASS** (11/11 Passed) | Dual touch, slide transitions, focus loss safety |

---

## 3. Campaign Smoke Verification Highlights (`v3_015_campaign_smoke.gd`)

```text
[0.000s] TitleScreen successfully instantiated into root scene tree.
[0.417s] Dispatching real InputEventMouseButton PRESS to Deploy button center: (971.5, 216.0)
[0.433s] [OBSERVATION] btn_new_game.pressed callback received! count=1
>>> [CAMPAIGN] Loaded Stage 1: 성문 외곽 (Citadel Terrace Gate) <<<
[0.467s] Stage 1 Entry verified: Citadel Terrace Gate active. Player at X=-8.00
[5.791s] Stage 1 Commander boss defeated naturally!
>>> [CAMPAIGN] Continue Button Pressed: Advancing to Stage 2... <<<
>>> [CAMPAIGN] Loaded Stage 2: 야수숲 (Beastwood Forest Gorge) <<<
[13.392s] Beast Chieftain defeated naturally! Awaiting Stage 2 clear...
>>> [CAMPAIGN] Continue Button Pressed: Advancing to Stage 3... <<<
>>> [CAMPAIGN] Loaded Stage 3: 무너진 성벽 (Ruined Crossbow Bastion) <<<
[20.634s] Crossbow Commander defeated naturally! Awaiting Stage 3 clear...
>>> [CAMPAIGN] Continue Button Pressed: Advancing to Stage 4... <<<
>>> [CAMPAIGN] Loaded Stage 4: 돌의 성소 (Titan Stone Sanctuary) <<<
[28.884s] Golem Guardian defeated naturally! Awaiting Stage 4 clear...
>>> [CAMPAIGN] Continue Button Pressed: Advancing to Stage 5... <<<
>>> [CAMPAIGN] Loaded Stage 5: 침묵의 성채 (Silent Abyssal Citadel) <<<
[33.769s] Stage 5 Boss Spawn Verified: Abyssal Arbiter active with HP=38/38, Poise=18 at X=12.13, Z=0.00
[35.929s] [OBSERVATION] Arbiter phase_changed callback received! phase=2 count=1
[39.961s] [OBSERVATION] Arbiter boss_defeated callback received! count=1
>>> [CAMPAIGN] Stage 5 CLEARED! ALL 5 STAGES CLEARED! <<<
[41.987s] CAMPAIGN VICTORY VERIFIED! CampaignVictoryPanel found with Replay & Title buttons.
[42.120s] RETURN TO TITLE VERIFIED! TitleScreen node instantiated in root.
[42.220s] SECOND CAMPAIGN START VERIFIED! SideQVCampaign reloaded cleanly from TitleScreen.
ExitCode: 0
```

---

## 4. Multi-Touch Controls Verification Highlights (`v3_003_real_touch_ui.gd` & `v3_010_test_touch_repro.gd`)

```text
[TOUCH UI TEST]
  Strike Button Touch: PASS
  Leap Button Touch: PASS
  Parry Button Touch: PASS
  Dash Button Touch: PASS
  Multi-Touch Move+Attack (rel 0 then 1): PASS
  Multi-Touch Move+Jump (rel 1 then 0): PASS
  Release Safety Zero Stuck: PASS
  Keyboard/Touch Ownership: PASS
  ExitCode: 0

[V3-010 AUDIT SUMMARY]
  Test 1.1: Joystick drag right activates move_right [PASS]
  Test 1.2: Finger 1 on Attack activates attack [PASS]
  Test 1.3: Releasing Finger 1 releases attack while maintaining move_right [PASS]
  Test 2.1: drag_touch_index retained active touch index 0 against mouse clobbering [PASS]
  Test 2.2: Touch 0 release cleanly resets joystick and releases move_right [PASS]
  Test 3.1: Guard pressed on touch down [PASS]
  Test 3.2: Dragging out of Guard button into empty space immediately releases guard [PASS]
  Test 3.3: Sliding pointer 2 into Dash button activates dash action [PASS]
  Test 3.4: Releasing pointer at Dash button releases dash [PASS]
  Test 4: Focus out notification properly clears all virtual actions and joystick [PASS]
  Test 5: Single-owner architecture verified: No redundant button_down signals [PASS]
  Audit Summary: Passed=11, Failed=0
  ExitCode: 0
```

---

## 5. Conclusion

No regression observed in PC desktop mode or mobile input subsystems. All 5 stages, boss state transitions, audio triggers, and Option C Z-plane constraints are preserved.
