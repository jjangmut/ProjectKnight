# ProjectKnight V3-003 Final Input Path — External Independent Review

**Decision: ACCEPTED WITH QUALIFICATIONS — Stage 1 desktop/engine-injected input gameplay slice.**
**Not a formal new QueueStore two-key reapproval, physical Android certification, or commercial release approval.**

- **Reviewed source branch:** `studio/v3-003-stage1-p1@71374cad6ea28ec8453c8038f727b1fecba1132a`
- **Original instruction-registration HEAD:** `48b9861d4657138e94ceada2becc565cfff4af7d`
- **Initial implementation:** `9fa9c2a2502401125166c18d9004ea4e7bf5a925`
- **Initial frozen review input:** `37ae92954457f1471a45b4030ff938c088751e91`
- **QA-triggered test fix and updated evidence:** `69772a474511543a62635acae22b21143601e878`
- **Final review documents / HEAD:** `71374cad6ea28ec8453c8038f727b1fecba1132a`
- **Parent external findings:** `STUDIO_V3/reviews/V3-003-RETEST-EXTERNAL-INDEPENDENT-REVIEW.md` (previous FIX_REQUIRED).
- **Reviewer method:** GitHub diff/file/structured-data independent static audit. Reviewer did not remotely execute Windows Godot, observe live hardware touch, authenticate private native subagent sessions, or inspect screenshot pixel content with a binary image viewer. GitHub tree confirms six PNG blobs; Director/QA's visual inspection remains a **reported internal review**, not reproduced externally.

## Verified corrections since the previous external FIX_REQUIRED

1. **Source changed for real.** Two actual `CLIENT/Game/tests` GDScript files were modified (E2E and touch UI), not only documents. The production boss state machine, Z-plane, and mobile HUD implementation were **not unnecessarily rewritten**. The new code uses `Input.parse_input_event()` and `Input.flush_buffered_events()` to dispatch real Godot **engine-injected** mouse press/release on `btn_new_game.get_global_rect().get_center()` instead of direct `btn.pressed.emit()`. The observer is attached to the Button's `pressed` signal and source no longer directly invokes its handler.
2. **Player facing is now controlled through input actions** (`move_left`/`move_right`) instead of `player.facing_dir_x =`. In the new E2E source there is no direct boss HP/poise modification, teleport, or `receive_hit()` invocation. The self-check is not a formal parser/security boundary, but direct review of executable paths supports the desired behavior.
3. **Natural combat and signals:** The committed shell transcript shows Stage 1 reached via GUI-injected click with `title_click_count=1`; two minions are defeated; boss spawns HP 24, HP falls successively to 0; `boss_defeated` callback=1, Stage 1 `stage_cleared` callback=1; campaign transitions to `SideQVStage2`. The E2E result JSON records matching true values and `boss_min_hp_recorded=0`. This directly remedies the old “signal count inferred from a boolean” weakness. The committed console record reports exit code 0; this reviewer did **not independently obtain the OS process exit code**.
4. **Touch test now uses Godot's engine event parser**, not `hud._input(ev)`. Four button rectangles receive index-1 `InputEventScreenTouch`; index-0 joystick plus index-1 action routes are tested in two release orders. Test checks zero stuck actions after all virtual touches release.
5. **Keyboard/touch ownership now has a real assertion** in the injected-input test: `InputEventKey(KEY_A)` is pressed through the engine; a joystick touch is pressed/released; `Input.is_action_pressed("move_left")` is asserted **before** the injected key-up. The reported JSON honestly labels it `SIMULATED_KEY_ROUTE_ONLY` / `PHYSICAL_HARDWARE_NOT_VERIFIED`. This is functional evidence for the engine-simulated combination, **not** a real device hardware guarantee.
6. The shell evidence contains **three** Godot 4.7.2 Compatibility command lines (touch, existing isolated boss windup fixture, E2E), stdout, empty stderr and reported exit code 0. Captures now wait on `RenderingServer.frame_post_draw`. Six distinct PNG blobs and `CAPTURE_MANIFEST.json` exist; manifest's Stage 1 boss frame explicitly indicates `boss_visible=true`, HP=24 and the Stage2 frame indicates a current campaign scene. The final Z-plane CSV has **217 data rows**, including **73 boss-present rows**; actor-present Z and vz samples are reported 0.
7. The independent QA report explicitly detected `ISSUE-V3-003-QA-01` (use-after-free access of TitleScreen after scene transition). A focused code guard and an updated successful run are committed at `69772a4...`; the QA report explicitly says it rechecked this patched SHA. This is a meaningful defect found and corrected during review.

## Qualification Q1 — reviewers are *not* bound to the same final SHA

The Director's `V3-003-FINAL-INPUT-INDEPENDENT-DIRECTOR-REVIEW.md` declares:
- **Code SHA:** `9fa9c2a2502401125166c18d9004ea4e7bf5a925`;
- **Evidence SHA:** `37ae92954457f1471a45b4030ff938c088751e91`.

The QA report records the later **patched-and-verified code SHA `69772a474511543a62635acae22b21143601e878`**.

The 697 patch modified the test and multiple captures/logs **after** the Director's reviewed SHA. While the game production source was not changed by this patch and the QA independently rechecked its results, it is **false to claim both reviewers certified the exact same final SHA**. The Director's 9.12/10 visual score is internal feedback on the earlier capture set and does **not** cryptographically certify the postpatch replacement images.

**Disposition:** Accept the patched Stage 1 desktop input gameplay work with a clearly disclosed *formal dual-signoff provenance limitation*. Do not invent a Director review of 697; if a strict same-SHA two-key gate is needed for formal queue/milestone closure, obtain a narrow Director acknowledgement of the final 697 artifact when naturally scheduling next stage authorization, **not another new agent-framework task or another full gameplay rewrite**.

## Qualification Q2 — no formal fresh queue approval and only simulated device evidence

`STUDIO_V3/queue.json` at final HEAD still has `V3-003=APPROVED` iteration **1**, with reviewer IDs `561af6a0...` and `4e59eff9...` and `current_commit_sha=5e785316...` (the earlier source). The new QA `20328dbb...` and Director `2699ca5c...` are represented in separate native review Markdown reports; the queue does **not** reflect a new TaskDispatcher iteration/approval. This matches Producer's stated `REOPEN_NOT_SUPPORTED` constraint. Treat it as an **append-only review addendum**, not a new guarded `APPROVED` transition.

The actual Windows physical keyboard ownership, native touch digitizer and Android real device performance remain NOT_VERIFIED / NOT_TESTED. The input-event route is desktop Godot Engine simulated; this acceptance scope cannot be extended to device certification.

## Qualification Q3 — scope/quality of the captured assertions

- In `v3_003_real_input_e2e.gd`, phase 5 allows transition when `stage_cleared_signal_count>=1 OR campaign.cleared_stages[0]`, and `_pass()` itself does not independently aggregate all result booleans. The **submitted actual run does show** `stage_cleared_signal_count=1` and boss signal=1, so this does **not invalidate the current run**; however future regression tests should enforce explicit counts in a final `_pass()` predicate instead of unconditionally labeling all checks PASS.
- The touch test allows some individual button checkpoints to pass solely when `Input.is_action_pressed(action)` becomes true, even before fully verifying animation/physical effects; the current evidence still establishes useful event and action routing. Do not overstate full Android real-world touch behavior.
- `RESULT_AND_LIMITATIONS.md` contains a **malformed base commit field** (`48b9861docs(state): ...`), which should not be treated as real Git provenance; authoritative base SHA is given at the top of this review.
- The visual quality score and “commercial indie calibre” language are subjective **internal** assessment, not external photographic confirmation. The PNG files were not visually decoded by this external reviewer, only listed with actual Git blob sizes and manifest metadata.

## Next action and decision

**Decision: ACCEPTED WITH QUALIFICATIONS** for **Stage 1 desktop engine-injected GUI/touch input functionality, natural combat completion, boss telegraph and Z-plane regression scope**. The actual implementation has materially progressed and the previous three input-path blockers are repaired.

**Do not open another V3-003 audit-only loop.** Retain Q1/Q2 as traceable acceptance-scope notes, not hidden assertions of rigorous official same-SHA approval. Prior `V3-003` queue approval is a preserved historical record, not a new approval for 697.

**Ready for an explicitly authorized V3-004 Stage 2 development kickoff** on a new development branch with **real Stage 2 content changes**, while carrying over a narrow final Director acknowledgement of postpatch 697 at the next natural review opportunity. Do not label Android or commercial release READY.

**Reviewed verdict: ACCEPTED WITH QUALIFICATIONS — Stage 1 functional slice; qualified formal review provenance.**
