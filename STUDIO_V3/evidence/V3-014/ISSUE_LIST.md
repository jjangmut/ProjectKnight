# V3-014 Issue List & Disclosures

## Milestone Tracking
- **Milestone ID**: V3-014
- **Objective**: Stage-Clear Intermission & Player-Controlled Next Stage Progression (Game First)
- **Target Branch**: `studio/v3-014-stage-clear-intermission`

---

## Resolved Issues

### ISSUE-V3-014-001 (P1): Uncontrolled 1.8-Second Automatic Stage Advance
- **Severity**: P1 - High
- **Category**: Game Flow / UX
- **Description**: In `side_qv_campaign.gd`, `_on_stage_cleared()` executed `await get_tree().create_timer(1.8).timeout; load_stage(next_stage_index)` without user feedback or pause, depriving the player of the ability to inspect earned Soul Shards, review campaign progress, or choose when to continue.
- **Resolution**: Replaced automatic timer advance with `_show_stage_clear_intermission()` for Stages 1–4, instantiating a responsive `StageClearOverlay` & `StageClearPanel` featuring explicit "CONTINUE TO STAGE N+1 ➔" and "⮌ RETURN TO TITLE" buttons.
- **Verification**: Verified via `v3_014_stage_clear_intermission_verification.gd` (Checks 1-12) and `v3_014_intermission_smoke.gd` (Phase 2 2.2s dwell with zero stage change).

---

### ISSUE-V3-014-002 (P1): Virtual Touch Deck & Enemy Attacks Lingering Post-Clear
- **Severity**: P1 - High
- **Category**: Combat Mechanics & State Integrity
- **Description**: On boss defeat, virtual touch action buttons remained active on screen, and active minions/boss attack areas could continue monitoring collisions, risking phantom hits while the victory fanfare played.
- **Resolution**: Updated `side_qv_stage_base.gd::_on_boss_defeated()` to invoke `touch_controls._release_all_actions()`, set `touch_controls.visible = false`, disable enemy attack collision monitoring (`attack_area_3d.set_deferred("monitoring", false)`), and disable physics processing (`set_physics_process(false)`) on all active enemies and bosses.
- **Verification**: Verified via `v3_014_stage_clear_intermission_verification.gd` (Checks 13-18).

---

### ISSUE-V3-014-003 (P2): Floating Text "STAGE CLEARED!" Overlapping Intermission Dialog
- **Severity**: P2 - Medium
- **Category**: UI / Visual Polish
- **Description**: Legacy `_on_boss_defeated()` spawned a world-space label (`clear_lbl`) directly above the player character. When the intermission panel appeared, this floating label remained visible behind or through the panel margins.
- **Resolution**: Freed `clear_lbl` (`if is_instance_valid(clear_lbl): clear_lbl.queue_free()`) right before emitting `stage_cleared`, ensuring a clean presentation for `StageClearOverlay`.
- **Verification**: Verified via `v3_014_capture_and_verify.gd` and visual QA inspection.

---

### ISSUE-V3-014-004 (P1): Double-Tap Races and Callback Duplication
- **Severity**: P1 - High
- **Category**: Concurrency / Robustness
- **Description**: Rapid mouse clicks or touch taps on "Continue" or "Return to Title" could trigger multiple concurrent calls to `load_stage()` or scene transitions, causing stage skipping or duplicate node allocations.
- **Resolution**: Both buttons disable immediately upon being pressed (`btn_continue.disabled = true`, `btn_title.disabled = true`) and set `is_transitioning = true`. Late signals are blocked by `if is_transitioning or is_defeat_active: return`.
- **Verification**: Verified via `v3_014_stage_clear_intermission_verification.gd` (Checks 11, 12, 40).

---

## Mandatory Milestone Disclosures

1. **`ANDROID_NOT_TESTED`**:
   - All tests, captures, and performance evaluations were conducted on Windows PC using the Godot 4.7.2 OpenGL3 compatibility backend.
   - Real Android device deployment, hardware touch latency, and mobile thermals have not been tested.
2. **`HUMAN_PLAYTEST_NOT_VERIFIED`**:
   - Playtesting was performed using automated and programmatic test harnesses (`v3_014_intermission_smoke.gd` and `v3_014_campaign_smoke.gd`).
   - Human subjective playfeel and touchscreen ergonomics require physical user testing.
3. **`COMMERCIAL_RELEASE_READINESS_NOT_CLAIMED`**:
   - This milestone completes player-controlled stage-clear intermission and multi-stage progression. Additional audio polish, particle effects, and final balance tuning are required before commercial release.
