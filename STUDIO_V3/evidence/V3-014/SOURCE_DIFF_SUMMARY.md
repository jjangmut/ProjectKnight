# V3-014 Source Diff Summary

## Scope & Objective
Milestone **V3-014** implements **Stage-Clear Intermission & Player-Controlled Next Stage Progression**:
- Replaces legacy 1.8-second uncontrolled automatic stage advance with a responsive, player-controlled `StageClearOverlay` & `StageClearPanel` for Stages 1–4.
- Provides explicit, accessible `ContinueStageButton` ("CONTINUE TO STAGE N+1 ➔") and `ReturnTitleButton` ("⮌ RETURN TO TITLE") actions.
- Neutralizes virtual touch controls and remaining enemy attack areas upon boss defeat without global tree pausing.
- Guarantees pixel-perfect responsive centering at both 1280×720 and 1024×720 resolutions via `CenterContainer` and `PRESET_FULL_RECT`.
- Displays authoritative single-awarded Soul Shards and campaign progression (e.g., "1 / 5 Stages Cleared").
- Preserves existing Stage 5 campaign victory dialog (`CampaignVictoryPanel`) exclusively, suppressing intermission for the final stage.
- Safeguards against double-tap races, late callback races, and defeat-clear races.

---

## 1. Codebase Modifications

### File 1: `CLIENT/Game/scripts/side_quarter_view/side_qv_campaign.gd`
- **Intermission Overlay Reference**:
  - Added `var clear_overlay: Control = null` tracking reference.
- **Stage Lifecycle Cleanups**:
  - In `load_stage(idx)`: added cleanup for `clear_overlay` (`if is_instance_valid(clear_overlay): clear_overlay.queue_free()`).
  - In `_show_stage_failed()`: added cleanup for `clear_overlay` if present.
  - In `_show_campaign_victory()`: added cleanup for `clear_overlay` if present.
- **Stage Clear Routing (`_on_stage_cleared()`)**:
  - Guarded against inactive or transition states (`if is_transitioning or is_defeat_active: return`).
  - For Stages 1–4: delegates to `_show_stage_clear_intermission()`.
  - For Stage 5 (final stage): delegates directly to `_show_campaign_victory()`, preserving the original final victory sequence.
- **Intermission Overlay Implementation (`_show_stage_clear_intermission()`)**:
  - Plays victory fanfare sound `AudioManager.play("stage_clear")`.
  - Builds full-rect `CenterContainer` inside `CanvasLayer` (layer 105) to ensure dynamic mathematical centering across viewports.
  - Instantiates `StageClearPanel` (640×360) styled with deep dark slate background (`Color(0.06, 0.08, 0.12, 0.94)`) and emerald/gold border (`#40f290`).
  - Renders `ClearTitleLabel` ("STAGE X CLEARED!"), `ClearSubtitleLabel` (Stage name), `RewardLabel` (Soul Shards earned + total progress e.g. "2 / 5 Stages Cleared").
  - Retrieves authoritative shard gain via `current_stage_node.last_earned_shards` without invoking a second reward calculation.
  - Adds `ContinueStageButton`:
    - Size: 230×48, `focus_mode = Control.FOCUS_ALL`.
    - Double-click guarded with `btn_continue.disabled = true`, `btn_title.disabled = true`, and `is_transitioning = true`.
    - Frees `clear_overlay` and calls `load_stage(next_stage_idx)`.
  - Adds `ReturnTitleButton`:
    - Size: 210×48, `focus_mode = Control.FOCUS_ALL`.
    - Double-click guarded with `btn_title.disabled = true`, `btn_continue.disabled = true`, and `is_transitioning = true`.
    - Calls `AudioManager.reset_all()`, frees `clear_overlay`, and transitions cleanly to `TitleScreen.tscn`.
  - Sets `btn_continue.grab_focus()` for keyboard/controller support.

### File 2: `CLIENT/Game/scripts/side_quarter_view/side_qv_stage_base.gd`
- **Authoritative Shard Tracking**:
  - Added `var last_earned_shards: int = 0` to record the exact shard award computed in `_on_boss_defeated()`.
- **Boss Defeat Flow (`_on_boss_defeated()`)**:
  - Assigns `last_earned_shards = earned_shards`.
  - Immediately releases all pressed virtual actions via `touch_controls._release_all_actions()`.
  - Hides virtual touch deck via `touch_controls.visible = false`.
  - Disables remaining minion and boss attack collision monitoring (`attack_area_3d.set_deferred("monitoring", false)`, `monitorable = false`).
  - Sets `is_attacking = false` and disables physics processing (`set_physics_process(false)`) on all active enemies and bosses.
  - Removes the legacy floating "STAGE CLEARED!" label (`clear_lbl.queue_free()`) prior to emitting `stage_cleared` so it does not overlap with the intermission overlay.

---

## 2. Test Harness Suite Additions

### 1. `CLIENT/Game/tests/v3_014_stage_clear_intermission_verification.gd`
- 41 programmatic assertions verifying:
  - `StageClearOverlay` structure, node naming, styling, and text content.
  - Action button dimensions (`ContinueStageButton`: 230×48, `ReturnTitleButton`: 210×48), focus mode (`FOCUS_ALL`), and double-click race guards.
  - Virtual touch release and deck visibility toggling on stage clear.
  - Neutralization of enemy attack monitoring and physics processing on clear.
  - Display of authoritative single-awarded Soul Shards without duplicate awarding.
  - Campaign progression tracking across all stages.
  - Responsive centering calculations at 1280×720 and 1024×720.
  - Stage 5 suppression of intermission and exclusive display of `CampaignVictoryPanel`.
  - Zero global tree pausing (`get_tree().paused == false`).

### 2. `CLIENT/Game/tests/v3_014_capture_and_verify.gd`
- Automated viewport capture script generating:
  - `after_01_stage_clear_overlay_1280x720.png` (1280×720)
  - `after_02_stage_clear_overlay_1024x720.png` (1024×720)
  - `after_03_continue_to_next_stage_respawn.png` (1280×720)
  - `after_04_return_to_title_screen.png` (1280×720)

### 3. `CLIENT/Game/tests/v3_014_intermission_smoke.gd`
- Real input E2E test verifying:
  - Title deploy $\rightarrow$ Stage 1 clear $\rightarrow$ Intermission rendered $\rightarrow$ 2.2s no auto-advance dwell verification $\rightarrow$ Real GUI mouse click Continue $\rightarrow$ Stage 2 clear $\rightarrow$ Real GUI mouse click Continue $\rightarrow$ Stage 3 entry $\rightarrow$ Shards audit verified.

### 4. `CLIENT/Game/tests/v3_014_campaign_smoke.gd`
- Full 5-stage continuous campaign playthrough test updated for player-controlled Continue buttons:
  - Title deploy $\rightarrow$ Stages 1–4 cleared with real Continue clicks $\rightarrow$ Stage 5 Arbiter clear $\rightarrow$ Campaign Victory panel $\rightarrow$ Return to Title $\rightarrow$ Second campaign deploy.
  - Option C $Z = 0.0000, v_z = 0.0000$ plane lock tracking across all actors (1,161 telemetry rows, 0 violations).
