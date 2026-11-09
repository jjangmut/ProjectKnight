# V3-013 Issue List & Disclosures

## Milestone Tracking
- **Milestone ID**: V3-013
- **Objective**: Player-Controlled Defeat, Retry & Campaign Recovery
- **Target Branch**: `studio/v3-013-failure-retry-gameplay`

---

## Resolved Issues

### ISSUE-V3-013-001 (P1): Uncontrolled 2-Second Automatic Stage Reload on Player Death
- **Severity**: P1 - High
- **Category**: Game Flow / UX
- **Description**: In `side_qv_campaign.gd`, `_on_stage_failed()` performed `await get_tree().create_timer(2.0).timeout; load_stage(current_stage_index)` without user feedback or choice, forcing the player directly back into the fight.
- **Resolution**: Replaced with `_show_stage_failed()`, instantiating a high-readability `StageFailedOverlay` & `StageFailedPanel` featuring explicit "⚔ RETRY STAGE" and "⮌ RETURN TO TITLE" buttons.
- **Verification**: Verified via `v3_013_failure_retry_verification.gd` (Checks 1-10) and `v3_013_failure_retry_smoke.gd`.

---

### ISSUE-V3-013-002 (P1): Virtual Touch Deck & Enemy Attacks Lingering Post-Defeat
- **Severity**: P1 - High
- **Category**: Combat Mechanics & State Integrity
- **Description**: On player defeat, virtual touch action buttons remained pressed, the touch deck remained visible over the dead player, and active minions/bosses continued attacking the corpse, causing continuous phantom hit sounds and physics collisions.
- **Resolution**: Updated `side_qv_stage_base.gd::_on_player_died()` to invoke `touch_controls._release_all_actions()`, set `touch_controls.visible = false`, disable enemy attack collision monitoring (`attack_area_3d.set_deferred("monitoring", false)`), and disable physics processing (`set_physics_process(false)`) on all active enemies and bosses.
- **Verification**: Verified via `v3_013_failure_retry_verification.gd` (Checks 18-24).

---

### ISSUE-V3-013-003 (P2): Hardcoded Dialog Positioning Causing Clipping on Compact Ratios
- **Severity**: P2 - Medium
- **Category**: UI / Viewport Responsiveness
- **Description**: `CampaignVictoryPanel` used hardcoded pixel offsets (`position = Vector2(320, 190)`), causing off-center rendering and right-edge clipping on 1024×720 or 4:3 tablet viewports.
- **Resolution**: Encapsulated dialog panels inside a root `Control` and `CenterContainer` with `set_anchors_preset(Control.PRESET_FULL_RECT)`, guaranteeing responsive mathematical centering across both 1280×720 and 1024×720 viewports.
- **Verification**: Verified via `v3_013_capture_and_verify.gd` capturing `after_01_stage_failed_overlay_1280x720.png` and `after_02_stage_failed_overlay_1024x720.png`.

---

### ISSUE-V3-013-004 (P1): `is_transitioning` Flag Blocking Action Buttons on Campaign Victory
- **Severity**: P1 - High
- **Category**: Game Flow / Event Handling
- **Description**: When `_on_stage_cleared()` completed Stage 5, it set `is_transitioning = true`. When `_show_campaign_victory()` opened, the buttons checked `if is_transitioning: return`, causing clicks on "Return to Title" and "Replay Campaign" to be ignored.
- **Resolution**: Set `is_transitioning = false` immediately when `_show_campaign_victory()` displays the overlay, and properly set `is_transitioning = true` upon button click to guard against double-click races.
- **Verification**: Verified via `v3_013_campaign_smoke.gd` (Phases 21-23).

---

## Mandatory Milestone Disclosures

1. **`ANDROID_NOT_TESTED`**:
   - All tests, captures, and performance evaluations were conducted on Windows PC using the Godot 4.7.2 OpenGL3 compatibility backend.
   - Real Android device deployment and touch latency have not been tested.
2. **`HUMAN_PLAYTEST_NOT_VERIFIED`**:
   - Playtesting was performed using automated and programmatic test harnesses (`v3_013_failure_retry_smoke.gd` and `v3_013_campaign_smoke.gd`).
   - Human subjective playfeel and ergonomics require physical user testing.
3. **`COMMERCIAL_RELEASE_READINESS_NOT_CLAIMED`**:
   - This milestone completes core game failure and recovery flows. Additional audio, animation polish, and content progression are required before commercial distribution.
