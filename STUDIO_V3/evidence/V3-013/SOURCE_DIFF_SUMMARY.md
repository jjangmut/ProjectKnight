# V3-013 Source Diff Summary

## Scope & Objective
Milestone **V3-013** implements **Player-Controlled Defeat, Retry & Campaign Recovery**:
- Replaces legacy 2-second uncontrolled automatic stage restart with a responsive, player-controlled `StageFailedOverlay` & `StageFailedPanel`.
- Provides explicit, accessible `RetryStageButton` and `ReturnTitleButton` actions.
- Neutralizes virtual touch controls and remaining enemy attack areas upon player death without global tree pausing.
- Guarantees pixel-perfect responsive centering at both 1280×720 and 1024×720 resolutions via `CenterContainer` and `PRESET_FULL_RECT`.
- Preserves earlier stage progress in `cleared_stages` when retrying the failed stage.

---

## 1. Codebase Modifications

### File 1: `CLIENT/Game/scripts/side_quarter_view/side_qv_campaign.gd`
- **State Management**:
  - Added `is_defeat_active: bool = false` to prevent duplicate defeat handling or defeat-cleared race conditions.
  - Added `failure_overlay: Control = null` tracking reference.
  - Updated `load_stage(idx)` to queue-free active `failure_overlay` and reset `is_defeat_active = false`.
  - Updated `_on_stage_cleared()`: added `if is_transitioning or is_defeat_active: return` to block clear signals while defeat is active.
- **Defeat Overlay Presentation (`_show_stage_failed()`)**:
  - Plays `AudioManager.play("player_hurt")`.
  - Builds `StageFailedOverlay` with full-rect `CenterContainer` for responsive placement.
  - Instantiates `StageFailedPanel` (`Vector2(620, 320)`) styled with crimson border (`#f24040`) and dark background (`Color(0.08, 0.04, 0.05, 0.94)`).
  - Displays `DefeatTitleLabel` ("☠ STAGE FAILED ☠") and `DefeatSubtitleLabel` indicating stage index and name.
  - Adds `RetryStageButton`:
    - Size: 220×48, `focus_mode = Control.FOCUS_ALL`.
    - Double-click guarded with `is_transitioning = true`.
    - Calls `AudioManager.stop_sfx()`, frees overlay, and calls `load_stage(current_stage_index)` to reload only the failed stage while keeping `cleared_stages` intact.
  - Adds `ReturnTitleButton`:
    - Size: 220×48, `focus_mode = Control.FOCUS_ALL`.
    - Double-click guarded with `is_transitioning = true`.
    - Calls `AudioManager.reset_all()`, frees overlay, and calls `get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")`.
- **Victory Overlay Polish (`_show_campaign_victory()`)**:
  - Wrapped `CampaignVictoryPanel` in `CenterContainer` with `PRESET_FULL_RECT` to match responsive dialog architecture.
  - Sets `is_transitioning = false` when victory panel opens so action buttons can receive input.
  - Added `if is_transitioning: return` guards on `ReplayCampaignButton` and `ReturnTitleButton` to prevent double-click scene reload races.

### File 2: `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd`
- **Player Death Flow (`_on_player_died()`)**:
  - Immediately releases all pressed virtual actions via `touch_controls._release_all_actions()`.
  - Hides virtual touch deck via `touch_controls.visible = false`.
  - Disables remaining minion and boss attack collision monitoring (`attack_area_3d.set_deferred("monitoring", false)`, `monitorable = false`).
  - Sets `is_attacking = false` and disables physics processing (`set_physics_process(false)`) on all enemies and the active boss, preventing phantom hits and damage while the player corpse rests.
  - Emits `stage_failed` signal to notify campaign controller.

---

## 2. Test Harness Suite Additions

### 1. `CLIENT/Game/tests/v3_013_failure_retry_verification.gd`
- 27 programmatic assertions verifying:
  - `StageFailedOverlay` structure, node naming, styling, and text content.
  - Action button dimensions (220×48), focus mode (`FOCUS_ALL`), and double-click race guards.
  - Virtual touch release and deck visibility toggling on death.
  - Enemy attack monitoring neutralization.
  - Single-stage retry reloading without resetting `cleared_stages`.
  - Responsive centering calculations at 1280×720 and 1024×720.

### 2. `CLIENT/Game/tests/v3_013_capture_and_verify.gd`
- Automated viewport capture script generating:
  - `after_01_stage_failed_overlay_1280x720.png`
  - `after_02_stage_failed_overlay_1024x720.png`
  - `after_03_retry_fresh_stage_respawn.png`
  - `after_04_return_to_title_screen.png`

### 3. `CLIENT/Game/tests/v3_013_failure_retry_smoke.gd`
- Real input E2E test verifying:
  - Title deploy $\rightarrow$ Stage 1 lethal damage $\rightarrow$ Defeat overlay $\rightarrow$ Real GUI click on Retry $\rightarrow$ Fresh Stage 1 reload $\rightarrow$ Minion & Boss combat $\rightarrow$ Stage 1 clear $\rightarrow$ Stage 2 transition.

### 4. `CLIENT/Game/tests/v3_013_campaign_smoke.gd`
- Full 5-stage continuous campaign playthrough test verifying:
  - Title deploy $\rightarrow$ Stage 1-5 natural clears $\rightarrow$ Campaign Victory panel $\rightarrow$ Return to Title $\rightarrow$ Second campaign deploy.
  - Option C $Z = 0.0000, v_z = 0.0000$ plane lock tracking across all actors.
