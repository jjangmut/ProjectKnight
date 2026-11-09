# ProjectKnight Studio V3 — Independent QA Verification Review
## Task V3-006: Stage 4 Titan Stone Sanctuary (돌의 성소)

- **Role / Evaluator:** PK_QALead (Independent QA Lead)
- **Task ID:** V3-006
- **Milestone:** Stage 4 Vertical Slice Content & Option C Mechanics Acceptance
- **Frozen Target Commit SHA:** `668ce6ec40fd6dc787667bbdceb89314848c0ef9`
- **Working Branch:** `studio/v3-006-stage4-stone-sanctuary`
- **Evaluation Date:** 2026-11-09
- **Active Session ID:** `7056e2a2-eb50-493f-9c4b-5d89063898b8`
- **Determination:** **QA PASS**

---

## 1. Executive Summary & Verification Overview

As the Independent QA Lead of ProjectKnight Studio V3, I have conducted an exhaustive, independent QA verification of Milestone **V3-006 (Stage 4 Titan Stone Sanctuary / 돌의 성소)** on branch `studio/v3-006-stage4-stone-sanctuary` at frozen commit `668ce6ec40fd6dc787667bbdceb89314848c0ef9`.

Both test suites were executed live using Godot 4.7.2 stable (`Godot_v4.7.2-stable_win64_console.exe`). All deliverables, game source codes, telemetry data, and visual artifacts were verified programmatically.

| QA Layer | Result | Key Verification Observations |
|---|:---:|---|
| **1. Functional QA** | **PASS** | Title screen GUI click verified (`count == 1`). Stages 1–3 cleared naturally. Stage 4 Wave 1: Two Heavy Golems (HP 8 each) defeated with distinct callbacks (`g1=1, g2=2`). Boss Wave: Golem Guardian spawned with initial HP 34 / Poise 16 at $Z=0.0$. Phase 2 triggered at HP 15 ($\le 17$, callback count 1). Ground Slam, Spinning Lariat, and Quake Fissure verified with proper single-hit gates. Parry stun halts boss rush with $v_x=0, v_z=0$ and strips 4 poise. Stage 4 clear callback count == 1. Clean transition into Stage 5 (`SideQVStage5`). Zero cheats detected. |
| **2. Visual QA** | **PASS** | Option C $Z=0.0$ plane lock strictly verified: programmatic analysis of all 1,158 data samples in `ACTOR_Z_PRESENCE.csv` confirmed **0 non-zero Z violations** ($|Z| \le 0.0000, |v_z| \le 0.0000$). Zero foreground monolith occlusion: all monolithic pillars positioned at $Z=-5.1\text{m}$ (back altar) and $X=\pm 17.5\text{m}$ (outer walls); Ground Slam basalt spikes clamped to $Z \le 0.0$ ($Z \in [-0.45, 0.0]$). All 15 PNG captures independently verified at exactly $1280 \times 720$. Full hazard cleanup on defeat ($0$ lingering nodes). |
| **3. Play QA** | **PASS** | High-impact, deliberate combat rhythm distinct from Stage 3 tactical zoning. Fair reaction windows: all lethal attacks provide $\ge 0.35\text{s}$ clear telegraphing (danger rings, glowing aura, raised arm windups). Ground shockwaves (height 1.0m) and molten fissures (height 0.9m) allow clean, intuitive jump dodging ($Y_{\text{apex}} \approx 1.8 \sim 2.5\text{m}$). Just Parry halting colossal rush delivers excellent combat feedback. |

---

## 2. Deliverables & Inspection Inventory

1. **Game Source Files Inspected:**
   - `side_qv_stage_4.gd`: Stage 4 initialization, sunset amber lighting (`Color(1.0, 0.65, 0.35)`), volcanic dusk ambience (`Color(0.55, 0.28, 0.15)`), 64 ember particles, altar backdrop at $Z=-13.8\text{m}$, background altar at $Z=-5.1\text{m}$, zero foreground occlusion. Golem 1 at $(4.0, 0.1, 0.0)$, Golem 2 at $(8.5, 0.1, 0.0)$, boss spawn at $Z=0.0$.
   - `side_qv_golem_minion.gd`: Heavy Golem colossus (~2.0m height), HP 8, strict $Z=0.0, v_z=0.0$, 1D horizontal collision and anti-pushing spacing.
   - `side_qv_golem_guardian.gd`: Boss colossus (2.8m height), HP 34, Poise 16, strict Option C $Z=0.0, v_z=0.0$. Ground Slam ($Z \le 0.0$, radial shockwave height 1.0m), Spinning Lariat ($11.5 \sim 13.5\text{m/s}$ rush, single-hit gate, parry stun halt), Quake Fissure (Phase 2 at HP $\le 17$, molten fissure line at $Z=0.0$, height 0.9m), Groggy break (3.0s on 0 poise with +1 shatter bonus), and hazard cleanup on defeat.

2. **Test Fixtures & Live Execution:**
   - `v3_006_stage4_golem_and_plane.gd`: Ran independently -> **Exit Code 0**, ALL CHECKS PASSED.
   - `v3_006_stage4_real_input_e2e.gd`: Ran independently -> **Exit Code 0**, ALL CHECKS PASSED.

3. **Telemetry & Artifact Validation:**
   - `ACTOR_Z_PRESENCE.csv`: Verified 1,159 total lines (1 header + 1,158 data rows). **Zero non-zero Z violations**.
   - `STAGE4_REAL_INPUT_E2E_RESULT.json`: All 28 programmatic assertions confirmed `true`.
   - `BOSS_HP_AND_ATTACK_TIMELINE.csv`: 16 chronological steps tracking boss HP from 34 down to 0 and Phase 2 transition at HP 15 ($\le 17$).
   - `CAPTURE_MANIFEST.json`: 12 synchronized capture entries documented.
   - `captures/`: All 15 PNG captures independently validated at exactly $1280 \times 720$.
   - `STAGE4_PLANE_AND_MECHANICS_TEST.json`: All 11 isolated fixture checks confirmed passed.
   - `GODOT_SHELL_COMMANDS_STDOUT_STDERR_EXIT.txt`: Complete shell execution transcript of 6 commands.

4. **Issue Tracking:**
   - Active P0/P1/P2 issues: **0**.

---

## 3. Final Determination
**`QA PASS`** — Milestone V3-006 is fully verified and cleared for final Game Director approval.
