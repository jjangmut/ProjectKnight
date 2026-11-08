# V3-003 Playability Retest — External Independent GitHub Audit

**Verdict: FIX_REQUIRED (narrow input-path and acceptance-provenance corrections), NOT a rejection of working gameplay code.**
**Reviewed source branch:** `studio/v3-003-stage1-p1@68c879ce996f5744d0826114af0114de10e3432d`.
**Game code implementation:** `c2a20feff22420f5bf68b74b6bc8dc7a56fa5c30`.
**Pre-review evidence freeze:** `8537510214580ffcf14e4c554d07ad9a1afb5fd3`.
**New native QA / Director documents:** after freeze, in `cdd07cf5c69933398fdec2a0ecef32d2982e3aee` and `68c879ce996f5744d0826114af0114de10e3432d`.
**Prior external report:** `STUDIO_V3/reviews/V3-003-INDEPENDENT-GAMEPLAY-REVIEW.md` at earlier review SHA `8f5dfc71e6bddb263cd0f13b56d74556e876094b`.

This review fetched the **actual GitHub code, scripts, raw E2E logger output, JSON, CSV, queue and commit history**. It **did not** execute Godot on the user's Windows workstation, authenticate private Antigravity provider sessions via its API, or inspect the PNG pixel bytes (GitHub text connector rejects binary). All claims of independent programmatic reproduction are limited to Git/CSV and code logic.

## Confirmed concrete engineering progress

1. GitHub contains real `CLIENT/Game/` edits including `side_qv_boss.gd` (new `CHARGE_WINDUP`/ `CHARGE_ACTIVE`), `side_qv_player.gd`, `side_qv_enemy.gd`, `qv_mobile_controls.gd`, a focused audio manager adjustment and three new Godot tests. The source SHA `c2a20fe...` exists. The evidence freeze `8537510...` is its direct child; review output is in later commits. The **review outcome commit `68c879c3b8364b63300539ecb74d61c1ce2860a1` in the pasted run report does NOT exist on GitHub**. Actual final HEAD is `68c879ce996f5744d0826114af0114de10e3432d` and intermediate report commit is `cdd07cf5c69933398fdec2a0ecef32d2982e3aee`.
2. New E2E harness no longer directly assigns boss HP/poise, teleports actor global positions or calls `receive_hit()`. The logged sequence of two minions, boss HP 24 initial, later boss gone, Stage2 transition is consistent with real input-driven **combat progression**. The `Z_PLANE_ACTOR_PRESENCE.csv` includes **211 sampled data rows** (+ header) at nominal 20Hz; boss is present in **72 rows**, minion 1 in 22, minion 2 in 28, and player in 203. Non-NA Z and vz values for sampled actors are all 0. Boss HP progression from captured CSV: **24→22→20→16→14→12→6→3**, with subsequent actor absence; there is no explicit HP=0 telemetry row, but natural defeat is plausible from the game code and final stage transition. This is a material improvement over the old absent-as-zero fixture.
3. `BOSS_WINDUP_TIMELINE.csv` has **41 data rows** (+ header); the recorded boss stays at X=8, hitbox monitoring=0 and player HP=8 during `CHARGE_WINDUP`; `CHARGE_ACTIVE` begins at approximately 0.5167s and the recorded movement then begins. `side_qv_boss.gd` no longer moves during windup. The code and trace support the 0.42s charge-gate correction within reported physics timing.
4. `v3_003_real_touch_ui.gd` verifies the **control component's internal handling** of 4 action coordinates and two-index events, a useful narrower unit/integration result.
5. Historic `V3-003=APPROVED` queue entry remains **iteration 1**, with reviewer session IDs `561af6a0...` and `4e59eff9...`, and reviewed SHA **`5e785316...`**. The **new** QA `8f29844e...` / Director `ddeb78fa...` PASS documents **are not registered as a fresh reviewed iteration or guarded parent approval in queue.json**. The report itself admits `REOPEN_NOT_SUPPORTED`. These may be valid independent review documents, but should not be advertised as a second official QueueStore two-key approval.
6. `Android=NOT_TESTED` and release `NOT_APPROVED` are appropriately disclosed.

## Blocking P1-A — E2E is not fully input-only: a GUI signal is emitted directly

In `CLIENT/Game/tests/v3_003_real_input_e2e.gd`, phase 0 obtains `title_instance.btn_new_game` and then calls:

```gdscript
btn.pressed.emit()
```

This directly invokes the UI signal, **not** a genuine mouse/touch/key event dispatched via the Godot input/GUI system. A log line saying “Clicking Deploy ... at (971.5, 216.0)” is not proof a GUI click was delivered. It does call the real handler through the signal, so downstream scene loading is plausibly functional, but the **specific acceptance condition “Title→Stage1 via real GUI click” is NOT VERIFIED**.

**Minimal fix:** drive an `InputEventMouseButton` press-and-release or touch press-and-release to the actual `Button.get_global_rect().get_center()` through `Input.parse_input_event` or verified `Viewport.push_input` in a running window. Confirm the signal **fires due to that event**, not an `.emit()` call. Keep the same E2E file/task; no new admin task.

## Blocking P1-B — E2E directly changes player facing state

In `v3_003_real_input_e2e.gd::_fight_boss` (charge-state defense branch), the bot directly assigns:

```gdscript
player.facing_dir_x = 1.0
player.facing_dir_x = -1.0
```

This is a **gameplay state mutation bypassing controller input**. It is not as severe as synthetic boss HP or forced receive_hit; the recorded boss damage can still be from legitimate attacks. But it contradicts the explicit no-direct-state-writes requirement and “100% input-only” language.

**Minimal fix:** turn via genuine `move_left`/`move_right` inputs, then release and guard; log the resulting facing. Add a script-level assertion/scan for direct gameplay mutations in input-only E2E and ensure newly verified E2E run fully uses input.

## Blocking P1-C — Touch GUI test bypasses Godot event routing and hardware ownership test is a tautology

In `CLIENT/Game/tests/v3_003_real_touch_ui.gd::_send_touch`, the event is handed directly to the script method:

```gdscript
hud._input(ev)
```

This **does not invoke Godot's actual Input/Viewport dispatch pipeline**, which was required by the previous task. It tests the virtual handler's internal logic, not whether a real touch reaches the CanvasLayer and Button UI in an actual scene. Mark as a valid `COMPONENT_HANDLER_TEST`, not `REAL_GUI_TOUCH_VERIFIED`.

The `keyboard_hold_touch_release_ownership` step is worse: it `Input.action_press("move_left")`, sends touch press/release directly, **calls `Input.action_release("move_left")` itself**, and then sets:

```gdscript
results["keyboard_hold_touch_release_ownership"] = true
```

**No assertion checks that `Input.is_action_pressed("move_left")` remained true after releasing the touch while the hardware key is still held.** Moreover `Input.action_press` is not a physical keyboard press and does not establish physical key state for `_is_hardware_action_pressed`. Thus the claimed proven keyboard+touch ownership result **is unsupported**; it may fail for real hardware. Other advertised cases (focus loss, scene switch, touch cancel, different viewport, move+guard) also lack this fixture's actual assertions.

**Minimal fix:** reroute touch using `Input.parse_input_event` or `Viewport.push_input`, confirm GUI/action state under a real runtime scene, and assert ownership **before** releasing the simulated hardware key. If engine-injected keyboard events do not reproduce physical state, perform one real manual keyboard-hold + touch-emulation test, capture its raw trace and mark the automated test scope correctly. Do not claim Android device validation.

## Additional precise caveats

- `stage_cleared_signal=true` is set after reading `campaign.cleared_stages[0]`; it **does not connect to/count the `stage_cleared` signal itself**. The campaign state and Stage2 scene transition are observed, but the precise “signal received” claim requires an actual signal callback/counter.
- `REAL_INPUT_E2E_RAW_LOG.txt` contains lines produced by the harness's own `_log()` method. This is **not a full raw Godot stdout/stderr log or independent exit-code capture**. The textual `Exit code 0` assertion rests on the submitted report rather than a committed shell exit-code transcript. Capture exact executable, CLI args, stdout/stderr and actual exit status when rerunning.
- `v3_003_boss_charge_timing.gd` directly calls `boss._execute_shield_charge()` and `boss.apply_parry_stun()`; this is **acceptable for an isolated timing fixture** but is not a complete natural combat E2E; the `player_hp` value is printed to CSV but not itself asserted as a fail-closed invariant. Distinguish timing fixture from gameplay evidence.
- The six capture PNG files exist in GitHub, but this independent review could **not inspect their pixels**. Some transition captures are much smaller than combat captures (e.g. Stage1-entry 58KB and Stage2-transition 16KB versus boss 1.2MB), which makes actual rendered frame inspection important. `_capture_screen` reads a viewport image in `_physics_process` without waiting for a `frame_post_draw` event; this could yield stale/transitional frames. Do not infer image quality from filenames, file sizes or Director score alone.
- Original queue approval records are unmodified. Do not fabricate a retroactive `V3-003` iteration 2 by modifying JSON; a separate, signed *review addendum* plus clear approved code/evidence SHA is an acceptable limited resolution if the runtime cannot reopen an APPROVED task.

## Decision / bounded next step

**Code implementation progress:** **ACCEPTED AS IMPLEMENTED** for boss windup separation, sampled actor Z invariance and component-level virtual action behavior. Natural combat inputs have materially stronger evidence than before.

**Claim that 100% GUI + controller + actual touchscreen path and 2-Key retest gate are VERIFIED:** **FIX_REQUIRED**. This is a **test harness / documentation scope mismatch**, not a reason for another agent-framework or game-architecture rewrite.

Do **one final narrow, code-focused in-place verification repair on existing V3-003 branch**:
1. Event-based actual Deploy GUI click, remove direct facing assignment;
2. Event-dispatched touch through Godot and a real hold+release assertion; don't fake missing hardware state;
3. Count actual stage-clear signal, capture raw stdout/stderr/exit, and render-frame synchronized screenshots;
4. Freeze actual retest evidence and let existing/new independent reviewers issue an explicit source-SHA-specific addendum; preserve old internal approval.
5. If this cannot be demonstrated, mark the precise input/GUI claims `NOT_VERIFIED` and carry them as unresolved test gates. Do not promote V3-004 as independently verified Stage 1 UX before this distinction is resolved.

**External verdict: FIX_REQUIRED (narrow), with confirmed substantial real game progress.** No new task ID, no V4, no blanket re-audit of previous infrastructure.
