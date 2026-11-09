# V3-011 Issue List & Defect Resolution

**Milestone:** V3-011 (Combat Audio Feedback & Player-Facing Sound Polish)  
**Date:** 2026-11-09  
**Branch:** `studio/v3-011-combat-audio-feedback`  

---

## 1. Resolved Issues

| Issue ID | Severity | Description | Resolution | Status |
|---|:---:|---|---|:---:|
| **ISSUE-V3-011-01** | P0 | **Silent Combat Swings:** Player attack combos 1, 2, 3 triggered visual streaks but zero sound effects. | Synthesized `player_slash_1/2/3.wav` and wired them to `combo_step` inside `side_qv_player.gd:start_attack()`. | **RESOLVED** |
| **ISSUE-V3-011-02** | P0 | **Silent Hit Impacts:** Striking enemies produced damage popups and hit-stops but no audible impact. | Synthesized `enemy_hit_impact.wav` and `enemy_hit_counter.wav`. Wired directly to `_check_attack_hit()`. | **RESOLVED** |
| **ISSUE-V3-011-03** | P0 | **Missing Defensive & Parry Feedback:** Blocking and just-parrying lacked distinct audible feedback. | Synthesized `guard_block.wav` and `parry_clash.wav`. Connected to `take_damage()` just-parry window and guard branch. | **RESOLVED** |
| **ISSUE-V3-011-04** | P1 | **Silent Boss Telegraphs:** Boss attacks (Beast leap, Crossbow volley, Golem slam, Arbiter rift) gave no audible windup. | Added `boss_tell_beast`, `boss_tell_crossbow`, `boss_tell_golem`, `boss_tell_abyssal`, and impact sounds to boss attack routines. | **RESOLVED** |
| **ISSUE-V3-011-05** | P1 | **Missing Stage Clear & Victory Fanfares:** Defeating bosses and conquering Stage 5 produced visual text without reward audio. | Added `stage_clear_stinger.wav` to `side_qv_stage_base.gd` and `campaign_victory_fanfare.wav` to `side_qv_campaign.gd`. | **RESOLVED** |
| **ISSUE-V3-011-06** | P1 | **2D Audio Positional Mismatch:** `audio_manager.gd` used `AudioStreamPlayer2D` with Vector2 coordinates in a 3D camera world. | Migrated to global 16-voice `AudioStreamPlayer` pool with -1.5 dB headroom, concurrency capping (max 3), and 35ms throttling. | **RESOLVED** |

---

## 2. Open Non-Blocking Disclosures (P2 / P3 Backlog)

| Item ID | Severity | Area | Description | Current Status |
|---|:---:|---|---|:---:|
| **DISC-V3-011-01** | P2 | Subjective Audio Quality | Engine-level audio buffer generation and signal dispatches are verified. Human subjective listening on physical headphones/speakers is pending. | `SUBJECTIVE_LISTENING_NOT_VERIFIED` |
| **DISC-V3-011-02** | P3 | Target Platform | Testing verified on Windows 11 desktop under OpenGL3 Compatibility renderer. Physical Android hardware performance and audio output are pending. | `ANDROID_NOT_TESTED` |
| **DISC-V3-011-03** | P3 | Input Verification | Input and combat loops verified via automated engine-parsed event routing. Physical human touch and gamepad feel are pending. | `HUMAN_PLAYTEST_NOT_VERIFIED` |
