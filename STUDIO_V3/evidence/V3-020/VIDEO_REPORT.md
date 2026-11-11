# V3-020 — Desktop Godot Playtest Video Report

## 1. Executive Summary

Milestone **V3-020** delivers the primary P0 deliverable requested by the user: **an authentic, playable, continuous gameplay MP4 video with full synchronized game audio**, covering the entire campaign from the Title Screen through all 5 stages to the Campaign Victory screen and Return to Title.

- **Primary Video Artifact:** [`D:\JUNYPAPA_STUDIO\Videos\ProjectKnight\V3-020\ProjectKnight_Playtest_Full.mp4`](file:///D:/JUNYPAPA_STUDIO/Videos/ProjectKnight/V3-020/ProjectKnight_Playtest_Full.mp4)
- **Duration:** **00:01:04.03 (64.03s)** / 3,842 frames @ 60 FPS
- **Resolution:** **1280×720 (16:9 Landscape)**
- **Video Format:** **H.264 / AVC** (High Profile, FastStart enabled for instant streaming/playback)
- **Audio Format:** **AAC Stereo 48,000 Hz** (Full game SFX: sword slashes, parry clangs, guard blocks, boss tells, stage clear stingers, victory fanfare)
- **Playthrough Classification:** **`AUTOMATED_ENGINE_INPUT_PLAYTHROUGH`** (Natural engine `InputEvent` routing, zero cheats, zero HP injections, 100% Option C Z=0 plane lock enforced)

---

## 2. Technical Specifications & Integrity Verification

```text
================================================================================
                    PROJECT KNIGHT V3-020 VIDEO AUDIT
================================================================================
File Path:     D:\JUNYPAPA_STUDIO\Videos\ProjectKnight\V3-020\ProjectKnight_Playtest_Full.mp4
File Size:     66,394,737 bytes (63.32 MB)
SHA-256:       666E7F00E6F9BD6166EA9B62A259B8570C44DF4DCAE29DF102B1F2BB6787EE87
Duration:      00:01:04.03 (64.03 seconds)
Video Codec:   H.264 / AVC (High Profile Level 3.2, yuv420p)
Resolution:    1280x720 (Aspect: 16:9)
Frame Rate:    60.00 fps (3,842 progressive frames)
Video Bitrate: 8,181 kb/s
Audio Codec:   AAC (LC) Stereo
Audio Rate:    48,000 Hz, 100 kb/s
Audio Status:  VERIFIED (Mean: -20.8 dB, Max: 0.0 dB, Samples: 6,148,096)
================================================================================
```

---

## 3. Video Playthrough Timeline Breakdown

| Timestamp | Game Stage | Gameplay Event & Visuals | Audio Triggers |
|:---:|:---|:---|:---|
| **00:00 – 00:02.5** | **Title Screen** | High-res 3D Paladin knight breathing animation, game title logo, UI menu with Deploy (출격) button. Mouse moves to Deploy center and clicks. | Ambient silence $\to$ UI click |
| **00:02.5 – 00:08.5** | **Stage 1 (성문 외곽)** | Hero steps into Citadel Terrace Gate under warm sunlight. Hero engages 2 Citadel Minions with 3-hit slash combos, then fights Stage 1 Boss Commander. Hero parries heavy axe swing and executes finisher. | `player_slash_1/2/3`, `guard_clang`, `parry_clash`, `enemy_hit_impact` |
| **00:08.5 – 00:11.5** | **Stage 1 Clear Intermission** | Stage Clear banner displays with player victory pose and **+20 Shards** tally. Continue button clicked. | `stage_clear_stinger` |
| **00:11.5 – 00:17.5** | **Stage 2 (야수숲)** | Hero enters Beastwood Forest Gorge. Fights 2 Beast Minions, then engages Beast Chieftain boss. Parries leaping claw attack and counters with sword beams. | `boss_tell_beast`, `player_dash`, `enemy_hit_counter` |
| **00:17.5 – 00:20.5** | **Stage 2 Clear Intermission** | Stage Clear overlay displays **+25 Shards** tally. Continue button clicked. | `stage_clear_stinger` |
| **00:20.5 – 00:26.5** | **Stage 3 (무너진 성벽)** | Hero enters Ruined Crossbow Bastion. Guards against flying crossbow bolts, clears 2 ranged minions, fights Crossbow Commander boss. Leaps over caltrop traps and defeats boss. | `boss_tell_crossbow`, `boss_crossbow_fire`, `guard_block` |
| **00:26.5 – 00:29.5** | **Stage 3 Clear Intermission** | Stage Clear overlay displays **+30 Shards** tally. Continue button clicked. | `stage_clear_stinger` |
| **00:29.5 – 00:36.5** | **Stage 4 (돌의 성소)** | Hero enters Titan Stone Sanctuary. Fights 2 Heavy Golems, encounters massive Golem Guardian. Leaps over ground fissure shockwaves, attacks core, and shatters guardian. | `boss_tell_golem`, `boss_golem_fissure`, `dive_slam_impact` |
| **00:36.5 – 00:39.5** | **Stage 4 Clear Intermission** | Stage Clear overlay displays **+35 Shards** tally. Continue button clicked. | `stage_clear_stinger` |
| **00:39.5 – 00:52.0** | **Stage 5 (침묵의 성채)** | Grand entrance into Silent Citadel. Hero clears 2 Elite Abyssal Knights. **Abyssal Arbiter** (HP 38, Poise 18) spawns. Phase 1 melee cleaves and shadow blinks parried. Phase 2: Arbiter triggers Judgment Storm & Dark Crescent Wave; hero leaps shockwave and delivers final victory combo! | `boss_tell_abyssal`, `boss_abyssal_strike`, `parry_clash` |
| **00:52.0 – 00:58.5** | **Campaign Victory** | **CONGRATULATIONS! ALL 5 STAGES CLEARED!** full screen victory panel with soul shards, badge rankings, and Replay / Return Title buttons. | `campaign_victory_fanfare` |
| **00:58.5 – 01:04.0** | **Return to Title** | ReturnTitleButton clicked. Clean return to TitleScreen, completing the entire gameplay lifecycle. | Title Screen UI |

---

## 4. Keyframe Visual Audit (Decoded Frames)

All 5 sampled keyframes were extracted directly from the generated MP4 via `ffmpeg` to verify zero black frames and zero rendering glitches:

- `captures/01_title_screen.png` (t = 2.0s): Title Screen UI, Deploy button, 3D character preview.
- `captures/02_stage1_combat.png` (t = 6.0s): Active combat on Citadel Terrace, parry visual effects, Option C Z=0 plane alignment.
- `captures/03_stage3_crossbow.png` (t = 24.0s): Crossbow bolts and trap hazards in Ruined Bastion.
- `captures/04_stage5_arbiter_boss.png` (t = 45.0s): Abyssal Arbiter boss duel in Silent Citadel with purple abyssal visual FX.
- `captures/05_campaign_victory.png` (t = 55.0s): Full campaign victory panel with Replay & Title navigation.

---

## 5. Playback & Viewing Instructions for the User

The video file is located locally on your PC at:
```text
D:\JUNYPAPA_STUDIO\Videos\ProjectKnight\V3-020\ProjectKnight_Playtest_Full.mp4
```

### Viewing Options:
1. **Windows Media Player / 영화 및 TV 앱:**
   - Windows 탐색기에서 위 경로의 `ProjectKnight_Playtest_Full.mp4`를 더블클릭하면 즉시 재생됩니다.
2. **웹 브라우저 (Chrome, Edge):**
   - 브라우저 창에 `ProjectKnight_Playtest_Full.mp4` 파일을 드래그 앤 드롭하면 하드웨어 가속 60 FPS로 즉시 재생됩니다.
3. **ChatGPT 검수용 첨부:**
   - 63.32 MB 크기로 인코딩되어 있어, ChatGPT 대화창에 직접 파일로 첨부하여 독립 AI 검수관이 재생 화면을 프레임별로 분석할 수 있습니다.
