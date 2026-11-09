# V3-006-EXECUTION — Stage 4 게임플레이 구현 즉시 실행 지시

**Task:** V3-006 (기존 작업 연속, V3-007 신규 착수 금지)  
**Branch:** `studio/v3-006-stage4-stone-sanctuary`  
**Verified GitHub HEAD at instruction time:** `740f7246927cec0e8540acf9d53331e4d15fe2f0`  
**Canonical scope:** `STUDIO_V3/tasks/V3-006.md`

## Situation / Why this instruction

GitHub branch HEAD currently contains **only the V3-006 task instruction commit** on top of V3-005. No V3-006 gameplay implementation, tests, or new evidence commits were observed. Therefore the next task is **execute V3-006**, not write a new Stage 5 task or file more governance paperwork. The existing STATE.md still describes V3-005.

## Mandatory execution sequence

1. `git fetch origin`, checkout `studio/v3-006-stage4-stone-sanctuary`, inspect `git status` and latest log. If local uncommitted edits exist, preserve and report them; never discard. Read `STUDIO_V3/tasks/V3-006.md`, Stage4 scene, Stage4 golem & guardian, base enemy, player, stage base and campaign. Spend no more than one bounded baseline cycle on setup. Do not repeat prior milestone infrastructure audits.
2. **First gameplay commit:** correct Stage 4 minion spawn positions currently at Z=-1.2/+1.2, and eliminate boss (and inherited golem) nonzero `velocity.z` / `position.z` throughout chase, lariat, knockback, groggy, death, etc. Preserve actual X/Y jump, attacks and collision. Check damaging hitboxes and fissure/shockwave shape alignment to X/Y gameplay plane, anti-double-hit and stage cleanup. Add targeted script/tests for each high-risk fix. Run Godot in project's configured real executable and log commands, stderr/stdout, exit status. **Do not start review ceremony before committing working gameplay changes.**
3. **Fight completion:** HeavyGolem 2 distinctive real-control kills -> Guardian HP34 -> phase2 at <=17 -> genuine boss defeat -> exact one Stage4 clear -> real Stage5 transition through campaign. Reuse V3-005 input-only test bot, produce `CLIENT/Game/tests/v3_006_stage4_real_input_e2e.gd`. Never alter HP/positions directly, inject wins, emit clear signals manually, or fake stages. Fail closed and exit nonzero on absent mandatory events.
4. **Mechanics:** demonstrate ground slam, spinning lariat, and phase2 quake fissure in actual runtime. Distinguish `observed_e2e` vs `observed_isolated` in evidence; unobserved events must remain false. Validate appropriate telegraph windows, guard/parry/dash dodge, single damage, boss/pillar sightlines, cleanup and actual game feel.
5. **Visual evidence:** capture real post-render Stage4 encounter frames at 1280x720, inspect the actual pixels, fix occlusion/readability proven by screenshot. Keep improvements scoped to Stage4 and impacted shared logic.
6. **Verification:** run Stage4 targeted tests + smallest relevant Stage3/shared-script regressions; save unedited run logs, actual result JSON, attack timeline, Z telemetry, screenshots/manifest under `STUDIO_V3/evidence/V3-006/`. Freeze actual code and evidence into a commit. Invite QA + Director to review identical frozen SHA; keep claimed approvals separate from official queue. Push to origin, update STATE.md honestly, and report actual final commit hashes.
7. If anything blocks execution, deliver the best *real code change* safely possible and enumerate precise blocker with command/output. Do not substitute documentation, false green flags, lengthy agent governance or repeated failed infrastructure reviews.

## Report to ChatGPT

Return branch HEAD, changed game source paths, meaningful mechanic fixes, test command+exit, observable Stage4 E2E counters, patterns seen in E2E vs isolated tests, captured screen paths, known defects and frozen/review commits. **No V3-007 until V3-006 real gameplay implementation and evidence have been reviewed.**
