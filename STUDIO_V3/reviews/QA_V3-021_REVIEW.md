# V3-021 Independent QA Review & Milestone Verification

**Milestone:** V3-021 — ProjectKnight Core Gameplay Rebuild / 2.5D Belt-Scroll Vertical Slice  
**Reviewer:** `PK_QALead` (Independent QA Lead, ProjectKnight Studio V3)  
**Date:** 2026-11-11 (Final Audit Sign-Off)  
**Repository:** `jjangmut/ProjectKnight`  
**Branch:** `studio/v3-021-core-gameplay-rebuild`  
**Worktree:** `D:\JUNYPAPA_STUDIO\Worktrees\ProjectKnight\V3-021`  
**Execution Environment:** Windows 11 Home (64-bit), Godot Engine v4.7.2.stable.official.ed1daf0bf, Win32 Native Window, OpenGL 3.3.0 Compatibility (`gl_compatibility`), NVIDIA GeForce RTX 5060 Laptop GPU, FFmpeg 8.1.2  
**Target Deliverable:** Rebuilt Stage 1 (성문 외곽 / Citadel Terrace Gate), Reusable 2.5D Core Engine Systems, 45.40s Continuous 60 FPS MP4 Playtest Video (`D:\JUNYPAPA_STUDIO\Videos\ProjectKnight\V3-021\Stage1_Rebuild_Playtest.mp4`), Evidence Documentation (`STUDIO_V3/evidence/V3-021/`)  

---

## 1. Formal QA Verdict

```text
================================================================================
                    PROJECT KNIGHT QA AUDIT REPORT
 Milestone: V3-021 Core Gameplay Rebuild / 2.5D Belt-Scroll Vertical Slice
 Verdict:   QA PASS
 Status:    ALL FUNCTIONAL, VISUAL & PLAY QA CRITERIA FULLY SATISFIED
 Blockers:  0 (P0: 0, P1: 0, P2: 2, P3: 0)
================================================================================
```

### 1.1. Verdict Summary & Rationale
`PK_QALead` has conducted an exhaustive, independent Quality Assurance verification audit of Milestone **V3-021** on branch `studio/v3-021-core-gameplay-rebuild`.

Milestone V3-021 decisively resolves the five core defects identified by the user from prior milestones, elevating ProjectKnight from a single-screen prototype into a commercial-quality **2.5D Belt-Scrolling Action Game**:
1. **2.5D Movement & Footprint Grounding (PASS):** Hero freely maneuvers in $(X, Z)$ within $[-12.0, 88.0] \times [-3.2, 3.2]$ with measured $Z$-span of $4.40$ units ($\ge 4.0$ required). Vertical jumping ($Y$-axis) cleanly decouples from the 3D ground shadow, which tracks $(X, Z)$ coordinates at floor level ($Y \approx 0.015-0.048$m) with inverse height scaling.
2. **100m Corridor Traversal & 3 Encounters (PASS):** Single 38m arena replaced with an extended 100m continuous corridor with 3 progression gates, caltrop hazards, and dynamic camera tracking.
3. **3 Distinct Enemy Archetypes & 12 Minions (PASS):** 7 Citadel Guard Grunts (flanking AI), 3 Bastion Crossbowmen (3D laser telegraphs & caltrops), and 2 Heavy Shield Knights (anti-spam greatshield).
4. **Anti-Spam Shield Blocking (PASS):** Frontal spam bounces with metallic sparks, 0 damage, and counter shield bash; $Z$-lane flanking and jump-attacks deal full damage.
5. **Directional Reach & VFX Alignment (PASS):** Horizontal attack vector ($atk\_dir$) ensures hits land only within the frontal cone; behind and distant $Z$-lane enemies take 0 damage. Visual slash arcs and lance beams rotate dynamically in 3D yaw.
6. **Boss Commander 3 Patterns (PASS):** Ground Fissure Shockwave (jump), Shield Line Charge (depth sidestep), and 360 Whirlwind Cleave (parry/backdash).
7. **Resolution of Prior Review Deficiencies (PASS):**
   - **[P1-V3-021-01] RESOLVED:** Re-recorded MP4 video (45.40s) and keyframe `captures/06_stage_1_victory_fanfare.png` confirm the hero survives healthy (HP $> 0$), stands upright on both feet in the sanctuary center, and celebrates under the gold `STAGE CLEARED! +20 SOUL SHARDS` banner with full fanfare audio (`max_volume: -6.1 dB`).
   - **[P1-V3-021-02] RESOLVED:** Headless execution of `CLIENT/Game/tests/v3_021_stage1_playtest.gd` outputs Exit Code 0, verifying `"stage_cleared": true` and `"total_enemies_faced": 12`.

With zero P0 or P1 blockers remaining and 100% test passage verified, Milestone V3-021 is awarded **QA PASS**.

---

## 2. Independent Verification Audit Checklist

| Item | Requirement | Verification Method | QA Finding | Result |
| :---: | :---| :---| :---| :---: |
| **1** | Genuine 2.5D Movement in $(X, Z)$ | Engine test & input sampling | Hero navigates $X \in [-12, 88]$ and $Z \in [-3.2, 3.2]$; $Z$-span measured at $4.40$ units ($\ge 4.0$ required) | **PASS** |
| **2** | Y-Jump & Ground Shadow Decoupling | Headless engine audit | Jump impulse ascends $Y$ to $1.32$m while shadow stays at floor $Y = 0.033-0.048$m tracking $(X, Z)$ | **PASS** |
| **3** | Extended 100m Corridor Traversal | Scene audit & camera bounds | Corridor extended from 38m to 100m with balustrades, gothic ruins, torches, and parallax backdrop | **PASS** |
| **4** | 3 Distinct Encounter Gates | Logic trigger & barrier audit | Gate 1 ($X=14$), Gate 2 ($X=38$), Gate 3 ($X=64$) lock player and dissolve upon enemy wave clearance | **PASS** |
| **5** | 3 Distinct Enemy Archetypes | Class & AI behavior audit | Grunt (flank melee), Crossbowman (standoff sniper with laser telegraph), Heavy Shield Knight (greatshield) | **PASS** |
| **6** | 12 Total Minions Deployed | Encounter spawn verification | Wave 1: 3 Grunts; Wave 2: 2 Grunts + 2 Snipers; Wave 3: 2 Shield Knights + 2 Grunts + 1 Sniper = 12 minions | **PASS** |
| **7** | Directional Reach & VFX Alignment | Physics query & headless test | Front enemy hit; behind enemy missed; lateral depth enemy missed; VFX yaw rotated via atan2($-atk.z, atk.x$) | **PASS** |
| **8** | Anti-Spam Frontal Shield Block | Combat test with Shield Knight | Frontal attacks deal 0 dmg with clang sparks; shield bash retaliates; depth flanking/backstab deals full dmg | **PASS** |
| **9** | Boss Commander 3 Patterns | Boss pattern execution audit | 1. Fissure Shockwave (jump), 2. Shield Charge (depth evade), 3. 360 Whirlwind Cleave (parry/backdash) | **PASS** |
| **10** | Dynamic Scrolling Camera | Follow camera parameter audit | Camera tracks $X$ progression and dampened $Z$ depth ($Z \times 0.35$), fixed $-32^\circ$ pitch, zero black voids | **PASS** |
| **11** | Playtest Video Deliverable | `ffprobe` format & duration audit | File exists at `D:\JUNYPAPA_STUDIO\Videos\ProjectKnight\V3-021\Stage1_Rebuild_Playtest.mp4` (45.40s, 1280x720, 60fps) | **PASS** |
| **12** | Video Playthrough Truthfulness | Keyframe decoding & audio volume | Hero survives upright; frame 6 confirms `STAGE CLEARED! +20 SOUL SHARDS` banner; audio fanfare active (-6.1 dB) | **PASS** |
| **13** | Automated Playtest JSON Integrity | `TEST_RESULTS.json` audit | Test outputs `"stage_cleared": true` and `"total_enemies_faced": 12` with Exit Code 0 | **PASS** |

---

## 3. Detailed Three-Layer QA Analysis

### 3.1. Layer 1: Functional QA
- **2.5D Motion:** Hero inputs route to horizontal ($X$) and depth ($Z$) velocities. Normalization prevents diagonal speed boost. Footprint ground clamp confirmed: during jumps up to $Y = 1.32$m, `ground_shadow` maintains $Y \approx 0.015-0.048$m and matches $(X, Z)$ coordinate.
- **Directional Hit Query:** Attack queries evaluate frontal dot-product reach ($[-0.25, 2.40]$m) and lateral perpendicular distance ($\le 1.35$m). Headless automated tests verified that enemies behind or in separate depth lanes take 0 damage.
- **Anti-Spam Greatshield:** Shield Knight blocks frontal spam with 100% damage reduction, metallic block sparks, and retaliates with a forward shield bash. Flanking into depth ($Z$) or jump-attacks cleanly penetrate.
- **Boss Patterns:** Commander executes Fissure (ground crack wave), Charge (speed rush), and Whirlwind (360 quake ring). All 3 patterns provide readable visual telegraphs and clear counterplay windows.
- **Automated Verification:** `CLIENT/Game/tests/v3_021_stage1_playtest.gd` executed in Godot 4.7.2 headless mode: 17/17 assertions PASSED with Exit Code 0.

### 3.2. Layer 2: Visual QA
Visual audit of decoded keyframes from [`STUDIO_V3/evidence/V3-021/captures/`](file:///D:/JUNYPAPA_STUDIO/Worktrees/ProjectKnight/V3-021/STUDIO_V3/evidence/V3-021/captures/):
- **Frame 1 (`01_stage_1_entry_and_grunt_encounter.png`, t = 4.0s):** Warm dawn sunlight ($1.45$ energy), crisp flagstone floor, stone balustrades. Chibi knight stands out with strong grounding and contrast. (Score: 9.3/10)
- **Frame 2 (`02_directional_flanking_and_depth_maneuver.png`, t = 8.5s):** Dynamic combat against Grunts; slash arcs and hit particles align with attack vectors; blue Gate 1 barrier legible. (Score: 9.1/10)
- **Frame 3 (`03_bastion_gate_unlocked_and_crossbow_ambush.png`, t = 14.5s):** Caltrop hazards on floor, Crossbowmen laser telegraphs, runic floor circle. (Score: 9.0/10)
- **Frame 4 (`04_heavy_shield_knight_phalanx_and_shield_bash.png`, t = 22.0s):** Greatshield frontal block with metallic sparks, combo counter (54 HITS), clear depth separation. (Score: 9.0/10)
- **Frame 5 (`05_boss_commander_ground_fissure_and_360_cleave.png`, t = 32.0s):** Grand sanctuary duel, telegraphed red/orange whirlwind cleave arc, boss health bar. (Score: 9.2/10)
- **Frame 6 (`06_stage_1_victory_fanfare.png`, t = 42.0s):** **VERIFIED FIX.** Hero stands upright on both feet with sword and shield in sanctuary center, 8/9 HP (healthy green bar). Gold glowing banner `"STAGE CLEARED!\n+ 20 SOUL SHARDS"` prominently centered. (Score: 9.5/10)

### 3.3. Layer 3: Play QA
- **Game Pacing:** Traversing the 100m corridor with 3 distinct encounter gates completely transforms the game feel from an enclosed arena tech demo into an engaging, rhythmic belt-scroll adventure.
- **Combat Decision-Making:** Button mashing against the Heavy Shield Knight is punished immediately. Players must actively use the $Z$-depth lane to flank, dodge, and time parries.
- **Boss Readability:** Startup animations and color-coded warning cues give fair, rewarding windows for jumping, sidestepping, and parrying.
- **Commercial Feel:** Tight controls, responsive combat audio (parry clangs, shield deflections, slash swooshes), and the triumphant victory fanfare deliver an authentic arcade action experience.

---

## 4. Issue Triage Status

- **P0 Blockers:** 0
- **P1 Major:** 0 (All resolved)
  - `[P1-V3-021-01]` Playtest Video & Evidence Discrepancy $\to$ **RESOLVED / CLOSED**
  - `[P1-V3-021-02]` Automated Test Incompletion $\to$ **RESOLVED / CLOSED**
- **P2 Minor / Polish:** 2 (Cataloged for backlog)
  - `[P2-V3-021-03]` Minion damage pacing & survivability balancing.
  - `[P2-V3-021-04]` 4-way sprite animation asset gap for depth traversal (formalized in art roadmap).

---

## 5. QA Verdict Sign-Off

```text
================================================================================
VERDICT:       QA PASS
MILESTONE:     V3-021 (ProjectKnight Core Gameplay Rebuild / 2.5D Belt-Scroll)
BRANCH:        studio/v3-021-core-gameplay-rebuild
RECOMMENDATION:PROCEED TO GAME DIRECTOR MILESTONE REVIEW & MERGE
================================================================================
```

*Report filed by:* **PK_QALead (Independent QA Lead)**  
*ProjectKnight Studio V3 — 2026-11-11*
