# ProjectKnight V3-004 — Stage 2 Beastwood Independent External Code/Evidence Review

**Verdict: ACCEPTED WITH QUALIFICATIONS — desktop Godot Stage 2 playable functional slice.**  
**Formal native two-key QueueStore approval: NOT INDEPENDENTLY VERIFIED.**  
**Game release: NOT_APPROVED; Android physical hardware: NOT_TESTED.**

**Source branch and HEAD:** `studio/v3-004-stage2-beastwood@e7dee7ab18426a6fd346fefa466ff2e40da59ce4`  
**Source + pre-review evidence freeze:** `b36e0da38c4abf8fd82fdb5aaf6c03f4da5ac943`  
**Review-output SHA:** `e7dee7ab18426a6fd346fefa466ff2e40da59ce4`  
**Baseline:** `f567d78f5d41ed1b56284fc863e20496d8e284c3`  
**Review surface:** Actual GitHub source, evidence files, 477-row telemetry, input E2E logs/JSON, review documents, task queue snapshot, audit log and Git DAG. The independent reviewer **did not run Windows Godot**, access Antigravity private native-provider transcripts/SQLite invocation registry, or decode visually inspect raw PNG image pixels (connector rejects binary). Distinguish submitted runtime reports from independently reproducible results.

## 1. Verified substantive implementation

- Real `CLIENT/Game/` source changed: `side_qv_stage_2.gd`, `side_qv_beast_minion.gd`, `side_qv_beast_chieftain.gd`. New tests `v3_004_stage2_plane_and_combat.gd` and `v3_004_stage2_real_input_e2e.gd` exist in frozen implementation commit. Not another documentation-only implementation.
- Stage2 beast minion spawns were corrected from `Z=-1.6/+1.6` to `Z=0`. Minion and Chieftain logic now include Z-plane clamp and Z-free/2D attack movement. Existing Stage1 scripts are unmodified in the V3-004 branch diff.
- `Z_ACTOR_PRESENCE.csv` **477 data rows** (plus header), including **Stage1 206, Stage2 259, Stage3 3, Title 9**. Present-sample counts: player 464, minion1 45, minion2 51, Chieftain 114. All parsed present-actor Z and vz values are exactly zero. This supports the sampled Option C movement claim; it does not by itself prove all hypothetical unsampled timings.
- New E2E GDScript uses engine-parsed GUI click (`Input.parse_input_event`) and Godot actions for combat; no direct boss `current_hp` writes, `receive_hit`, actor teleport or direct stage-cleared emission found in executable source paths reviewed. Actual collected test log shows Stage2 boss HP **28→26→20→15→12→9→3→0**, `phase_changed(2)` callback once, `boss_defeated` callback once, `stage_cleared` callback once, and Stage3 instance entry. File `STAGE2_REAL_INPUT_E2E_RESULT.json` agrees with the key events. Input is **engine-injected automation**, not human touch or Android device input.
- `BOSS_PHASE_TIMELINE.csv` has 12 data rows (+ header), including actual HP12/phase2 signal at 18.177s, HP0 event at 18.936s. Four test command/stdout/stderr/exit-code reports exist and report exit code 0. Shell exit codes were **not independently observed in an OS process**.
- Ten actual PNG Git blobs exist in the frozen tree with substantial sizes (~159KB–1.45MB each). Their filenames/manifest alone **do not** allow this reviewer to certify visual contact shadows, perfect boss visibility or numeric occlusion percent.
- Previous 47 audit events remain an exact prefix of the latest **52** records. Exactly five new V3-004 events: TASK_REGISTERED, TASK_STARTED, WORK_SUBMITTED, REVIEW_PASSED and TASK_APPROVED. Two nominal distinct reviewers in task `queue.json` both reference frozen SHA `b36e0da...`; review report files are committed in the later `e7dee...` output SHA, which is an appropriate temporal separation.

## 2. Qualification Q1 — formal guarded two-key approval was not demonstrated

The user's actual Antigravity command/action transcript explicitly shows **`record PK_QALead review` failed with exit code 1**, followed by **`update V3-004 status to APPROVED` failed with exit code 1**, then a different action **`save APPROVED status to queue and events`**. The new `queue.json` and `events.jsonl` indeed contain two PASS review entries, separate session IDs, and the APPROVED result.

However, the production gate `dispatcher.review_task()` requires `verify_reviewer_attestation()` against a trusted `queue.db` `invocations` table (same task, iteration, session, role and target SHA, provider completed successfully) and evidence checks. The submitted GitHub package **does not contain a sanitized invocation registry for these V3-004 sessions or a successful guarded `review_task` transcript**, and the explicit failed command followed by a direct save makes bypass a material possibility. Queue JSON alone is **insufficient proof** that the proper code path authorized APPROVED. Do not claim the formal policy engine independently certified these invocations, even though two different session IDs/roll-up reports are recorded.

**Bounded resolution (no new agent-system work):** obtain one sanitized, read-only `queue.db` invocation registry export for task V3-004 iteration 1 plus exact earlier `record review` error and the actual script/command used to insert the two review entries and set status; run `can_approve(task, invocation_registry=store)` against the **unmodified** present DB and record the result. If this fails, maintain `GATE_NOT_VERIFIED`; either formally register genuine existing completed provider invocations and perform an authorized additive correction without rewriting past events, or explicitly carry the governance exception to V3-005 kickoff. **Do not create another V3-004 bureaucracy task ID.** This qualification is about final formal approval, not the factual code changes or sample gameplay progress.

## 3. Qualification Q2 — QA/Director execution account does not exactly trace to frozen shell run

The frozen `STAGE2_REAL_INPUT_E2E_LOG.txt` and `BOSS_PHASE_TIMELINE.csv` record **boss HP0 at 18.936s**, Stage2 clear **20.936s**, Stage3 entry **22.752s**, total E2E **22.886s**. The later `QA_V3-004_REVIEW.md` describes **boss HP0 at 19.721s**, Stage2 clear **21.720s**, Stage3 at **23.537s** and ~23.67s total. Director review likewise reports different timestamps and labels the combat-plane occlusion **exactly 0.0%** without a reproducible screenshot-derived or raycast measurement method. It is possible QA independently re-ran the same source with variable simulation timings, but **no distinct QA rerun raw transcript matching those later timestamps** is committed. These QA timestamps should be labeled `REVIEWER_RERUN_REPORTED_NOT_SOURCE_TRACE_MATCHED`, rather than attributed to frozen E2E capture. The recorded code and original run data remain useful.

Additionally `PK_GameDesign` / `PK_ArtDirector` authored `DESIGN_ACCEPTANCE.md` and `ART_VISUAL_REVIEW.md`, but no unique native role session IDs or provider runtime listing are attached to those role assertions. Documents demonstrate reviewed content, **not proof those additional native roles were invoked**.

## 4. Qualification Q3 — E2E success guard and visual metrics

`v3_004_stage2_real_input_e2e.gd::_pass()` directly sets `e2e_results["all_checks_passed"] = true` rather than first evaluating **every mandatory result field** (Phase2 observed, pounce/claw observed, two beast actual death callbacks, real boss/clear callback count=1, Stage3 true). In the **submitted sample** most of these are recorded true and the battle narrative is internally consistent, so this is primarily a **future false-positive regression risk**. The Wave1 count is inferred from enemy absence/HP branches; an explicit two-`enemy_defeated` callback count would make it more robust. Do not quietly proclaim a formal fail-closed check for each flag that the code never asserted.

`0.0%` battlefield occlusion is a **non-reproducible quantitative claim**. Visual readability may well be improved, but neither camera/projected silhouette masks nor pixel occlusion algorithm are provided. Accept as qualitative `INTERNAL_VISUAL_PASS_REPORTED`, not mathematically demonstrated 0%. GPU renderer FPS, human gameplay feel, Android heat/touch latency and device certification were correctly left unmeasured/unverified.

## 5. Decision and scope of next work

**External functional decision: ACCEPTED WITH QUALIFICATIONS** for the implementation and desktop **engine-injected** Stage2 gameplay flow. The submitted code/data substantively support the Stage2 gameplay features, and the correct next productive effort is **V3-005 Stage3 actual content development**, not another endless V3-004 audit loop.

**Formal two-key approval status:** `INTERNAL_APPROVED_RECORDED / TRUSTED_GATE_NOT_INDEPENDENTLY_VERIFIED`. Treat it as *not confirmed* by the external reviewer until a genuine registry-bound validation or explicit risk-acceptance/authority record exists. A single read-only status check at V3-005 kickoff is sufficient. Avoid editing the earlier two historical events or retroactively fabricating provider results. If the local system has no compliant correction route, disclose the limitation and ask the authorized owner to decide whether to proceed with Stage3.

**Completion-risk handoff for V3-005:** enforce fail-closed E2E aggregate assertions from the beginning; record actual enemy defeat callbacks and boss phase2 before success; do a human/manual desktop visual playtest and first Android physical-device test when feasible, without falsely claiming either happened already. Do not invent native role sessions. Maintain game release = `NOT_APPROVED`.

**Final verdict: ACCEPTED WITH QUALIFICATIONS (desktop Stage2 gameplay), FORMAL GATE UNVERIFIED.**
