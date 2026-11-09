# V3-008 — Playability & Combat Readability Polish (Before / After Report)

**Repository:** `jjangmut/ProjectKnight`  
**Branch:** `studio/v3-008-playability-polish`  
**Engine:** Godot 4.7.2 stable, OpenGL3 Compatibility, Desktop 1280x720  
**Operating Mode:** Option C Strict 2D Combat Plane Lock ($Z = 0.0000, v_z = 0.0000$)  

---

## 1. Executive Summary

Milestone **V3-008** advances player experience, combat feedback, visual readability, and campaign completion continuity through direct, scoped Godot GDScript improvements. Rather than refactoring governance or multi-agent tooling, V3-008 directly addresses the top 3 observable gameplay and visual defects across the 5 campaign stages.

All improvements were tested on a real rendered window (1280x720) with GL Compatibility on an NVIDIA RTX 5060 GPU, preserving the five completed stages and verified by targeted and end-to-end automated input suites.

---

## 2. The 3 Concrete Player-Facing Issues & Solutions

### Issue 1 (P0 UX/Flow): End-of-Campaign Dead End — Missing Interactive Replay/Return Button in `CampaignVictoryPanel`
- **Location:** `CLIENT/Game/scripts/side_quarter_view/side_qv_campaign.gd`
- **Observed Defect:** Upon defeating the final boss and clearing Stage 5, `_show_campaign_victory()` instantiated a bare `PanelContainer` with two static text labels. Zero interactive controls were provided. The player was stranded on the victory screen with no means of returning to the Title screen or replaying the campaign without terminating the game executable.
- **Root Cause:** Placeholder implementation from V3-007 only verified signal emission and panel node visibility (`visible = true`), without providing an interactive UI action loop.
- **Implemented Fix:**
  - Styled `CampaignVictoryPanel` with a polished dark gunmetal panel (`StyleBoxFlat`, border color `Color(1.0, 0.85, 0.2)`, 8px rounded corners, 32px padding).
  - Added two interactive action buttons:
    1. `ReplayCampaignButton` (`"⚔ REPLAY CAMPAIGN"`): Frees the victory panel, resets campaign state (`cleared_stages = [false, false, false, false, false]`), and reloads Stage 1 (`load_stage(0)`).
    2. `ReturnTitleButton` (`"⮌ RETURN TO TITLE"`): Frees the victory panel and cleanly transitions to `res://scenes/ui/TitleScreen.tscn`.
  - Both buttons feature keyboard/touch/mouse focus (`Control.FOCUS_ALL`), custom minimum size `Vector2(220, 48)`, and theme font overrides.
- **Visual Evidence:**
  - Before: `captures/before/before_01_campaign_victory_panel.png` (Static bare text, no buttons)
  - After: `captures/after/after_01_campaign_victory_panel.png` (Polished golden border, Replay & Title buttons)

---

### Issue 2 (P1 Combat Readability): Final Boss Shadow Blink Strike & Crescent Wave Telegraph Window & Contrast
- **Location:** `CLIENT/Game/scripts/side_quarter_view/bosses/side_qv_abyssal_arbiter.gd`
- **Observed Defect:**
  1. In `_execute_shadow_blink_strike()`: Telegraph duration upon reappearing behind the player was only 0.18s–0.20s with a generic dim "!" popup. Against the obsidian/dark violet fog of the Silent Citadel throne room, the cue was nearly invisible and well under human reflex reaction time (~200ms).
  2. In `_execute_dark_crescent_wave()`: Zero danger telegraph was spawned before the projectile was released, forcing players to guess projectile timing at long range.
- **Root Cause:** Prototype telegraph parameters were tuned for instant code execution rather than human visual readability and counterplay window.
- **Implemented Fix:**
  - `_show_danger_telegraph(duration, cue_text)`: Upgraded danger torus mesh to radius 0.75/1.15, elevated to $Y = 0.12\text{m}$, and heightened emission to vivid crimson/gold `Color(4.5, 0.8, 0.15, 0.95)` with 4.8x energy multiplier.
  - In `_execute_shadow_blink_strike()`: Increased reappearance-to-strike telegraph window to 0.30s–0.32s, and emitted clear eye-level popup `"DANGER! BLINK STRIKE!"` via `GameFeelManager.damage_popup_3d`.
  - In `_execute_dark_crescent_wave()`: Added `_show_danger_telegraph(0.32, "DANGER! CRESCENT WAVE!")` during projectile wind-up.
- **Visual Evidence:**
  - Before: `captures/before/before_02_arbiter_blink_telegraph.png` (Dim ring, generic "!" marker)
  - After: `captures/after/after_02_arbiter_blink_telegraph.png` (Crimson-gold high-contrast danger torus and explicit telegraph text)

---

### Issue 3 (P1 Combat Juice): Missing Hit-Stop Freeze-Frame on Just Parry Clash
- **Location:** `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd`
- **Observed Defect:** When executing a successful Just Parry (`guard_elapsed_time <= JUST_PARRY_WINDOW`), the game spawned a visual shockwave torus and camera shake (trauma 0.38), but lacked a hit-stop freeze-frame. Unlike Dive Slam and heavy attacks, parry clashes felt hollow and "floating" without mechanical resistance.
- **Root Cause:** `GameFeelManager.hit_stop_3d()` was called during standard attacks and Dive Slam landing, but was omitted from `_trigger_parry_flash()`.
- **Implemented Fix:**
  - Added `GameFeelManager.hit_stop_3d(0.08, 0.04)` to `_trigger_parry_flash()` in `side_qv_player.gd`.
  - On every successful parry clash, the engine timescale freezes momentarily for 80ms at 0.04 timescale, producing an authoritative, weighty Sekiro-style clash feel before releasing the counterattack buff.
- **Visual Evidence:**
  - Before: `captures/before/before_03_parry_hit_stop.png`
  - After: `captures/after/after_03_parry_hit_stop.png` (Recorded hit-stop end msec active during parry clash)

---

## 3. Summary of Code Modifications

| File | Changes | Impact |
| :--- | :--- | :--- |
| `CLIENT/Game/scripts/side_quarter_view/side_qv_campaign.gd` | +48 lines | Adds `CampaignVictoryPanel` styling, `ReplayCampaignButton`, `ReturnTitleButton`, and restart handler |
| `CLIENT/Game/scripts/side_quarter_view/bosses/side_qv_abyssal_arbiter.gd` | +14 lines, -13 lines | Adds `"DANGER! BLINK STRIKE!"` & `"DANGER! CRESCENT WAVE!"` telegraphs, increased 0.32s reaction window, high-contrast crimson-gold emission |
| `CLIENT/Game/scripts/side_quarter_view/side_qv_player.gd` | +3 lines | Integrates `GameFeelManager.hit_stop_3d(0.08, 0.04)` into `_trigger_parry_flash()` |

---

## 4. Verification & Testing Methodology

1. **Targeted Polish Verification:** `CLIENT/Game/tests/v3_008_polish_verification.gd` (Passed, Exit 0)
   - Verified styled victory panel with `ReplayCampaignButton` and `ReturnTitleButton`.
   - Verified replay button action reloads Stage 1 and clears victory panel cleanly.
   - Verified Arbiter crimson/gold danger torus mesh and text popups.
   - Verified Player Just Parry triggers 80ms hit-stop in `GameFeelManager`.
2. **Continuous 5-Stage Real-Input E2E:** `CLIENT/Game/tests/v3_008_five_stage_real_input_e2e.gd`
   - Validates Title $\rightarrow$ Stage 1..5 $\rightarrow$ Victory with Option C $Z = 0.0$ plane lock and exactly-once campaign completion signal.
