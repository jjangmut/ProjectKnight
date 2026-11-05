# V3-002-R3-PATCH — ChatGPT Independent Code & Evidence Review

**Review target:** `studio/v3-002-r3-final-hardening@0b5bb54db44f45db17b09ee1435c7e1640c7f4c8`
**Reviewed:** pushed GitHub source, R3-PATCH logs, manifest, audit note, queue state, supplied Antigravity report.
**Scope caveat:** This is source/evidence inspection; I have not run the Windows-host Antigravity or Godot processes independently.

**Decision: FIX_REQUIRED (focused closure, not new R4 architecture).** Do not mark parent `V3-002` APPROVED or unblock `V3-003` based on this report.

## Verified improvements
- R3-PATCH really is pushed to the stated HEAD. Git diff contains 44-test Python regression code, strict reviewer parsing, Git tree blob checks, parent-conversation checks, and audit/run ID support.
- GitHub contains `STUDIO_V3/evidence/V3-002-R3-PATCH/test_logs/python_tests_raw.log`, reporting Python 3.11.9, **44 tests / 0 failures / exit 0**.
- GitHub contains `godot_tests_raw.log`, reporting Godot 4.7.2, **74 checks / 0 failures / exit 0**, with a real headless GDScript fixture test script.
- The prior R3 five native subagent sessions and reject/fix/retest flow are recorded. This establishes useful **IDE-native multi-agent workflow**, not unattended Python standalone launching.
- `V3-001` remains READY and `V3-003` remains BLOCKED, correctly.

## P0-01 — Git provenance enforcement still fails open on exceptional paths

**Location:** `STUDIO_V3/orchestrator/policies.py`: `verify_commit_on_branch`, `verify_committed_source_evidence`.

- `verify_commit_on_branch` wraps Git commands in `try ... except Exception`; any non-`PolicyViolation` exception silently executes `pass`, meaning missing Git, timeout, malformed command or OS error may bypass branch verification.
- Both verification functions silently `return` if `repo_root/.git` is absent; they also return when commit SHA is empty / `UNKNOWN_SHA` / `HEAD`. This behavior is incompatible with a production **fail-closed** Git gate.
- The branch contains a fallback based on `git branch -a --contains` and a broad `"* "` / substring check; this can validate the current branch instead of the assigned task branch.

**Required:** fail closed on all Git process exceptions, missing repository, missing/invalid 40-character commit SHA, unresolved branch, nonzero Git exit and non-ancestor. Only use an exact authorized branch ref and `git merge-base --is-ancestor` result. Unit-test missing .git, invalid SHA, missing Git executable/timeout, unrelated branch and current-branch-vs-assigned-branch mismatch. Do not silently allow an unverified commit.

## P1-02 — Strict reviewer JSON schema still has a bypass/ambiguity

**Location:** `dispatcher.py::parse_reviewer_verdict`.

- The stated mandatory field `evidence_manifest` can be omitted if an alternative `evidence` field is present; code uses `payload.get("evidence_manifest", payload.get("evidence", []))`.
- The parser allows multiple compatible JSON verdicts and picks the last one; it does not require a unique provider-returned **final verdict** envelope.
- `iteration` checks `isinstance(x, int)`; in Python `bool` is a subclass of `int` (minor type-hardening concern).

**Required:** enforce the agreed exact final response schema (no silent alias in production) and one authoritative final verdict. Separate pre-final narrative/examples from the terminal verdict, or reject ambiguous multi-verdict output. Add missing `evidence_manifest`, duplicated-PASS and bool iteration negative tests.

## P1-03 — Agent terminal completion can still rely on earlier DONE events

**Location:** `orchestrator/adapters/subagent_bridge.py`.

The ingestion marks `is_done=True` if the last transcript entry is completed **OR ANY prior entry contains `status == "DONE"`**. Thus an interrupted/incomplete session with an earlier DONE step and later nonterminal steps can be considered `SUCCEEDED`.

**Required:** require an authoritative final terminal event for the specific provider job; remove `any(s.get("status") == "DONE" for s in steps)`. Add negative transcript tests with earlier DONE plus later pending/failed state. Check the final result JSON is actually the session's terminal output rather than a previous model turn.

## P1-04 — Independent infrastructure approval is not present in the committed state

**Locations:** `STUDIO_V3/queue.json`, `STUDIO_V3/evidence/V3-002-R3-PATCH/live_native_run/audit_record.md`, `FINAL_EXECUTION_REPORT.md`.

- The pushed queue still has `V3-002-R3-PATCH: IN_PROGRESS, iteration: 0, reviews: {}`, no submitted SHA and no approval verdicts.
- The file `FINAL_EXECUTION_REPORT.md` explicitly says `Infrastructure independent QA/Director: REQUESTED`. The separately pasted completion narrative claims both passed, but their new provider session IDs, terminal transcripts, QA/Director structured verdicts and proof of review against the final source HEAD are not in this GitHub evidence package.
- The audit note under `live_native_run` reuses the **five older R3 stamina fixture subagent IDs**, so it cannot attest that an independent QA+Director inspected the **patch**.

**Required:** perform (or export, if already performed) two **new** independent reviewer invocations of the exact patch SHA with provider session IDs, parent context, terminal status, structured verdicts, reviewer evidence, and update the task state through the guarded queue. Do not mark `APPROVED` based on the older fixture.

## Narrow closure path
1. Fix only the P0/P1 defects above (do NOT redesign Studio V3). Keep game sources unchanged.
2. Run and upload raw Python/Godot regression outputs against the corrected source and record exact SHA.
3. Submit infrastructure work to the task queue, then independent QA and Director on the same *new* patch SHA.
4. Re-review these findings only; on verified PASS, consider accepting the parent Studio V3 infrastructure separately.
5. In parallel, `V3-001` is already READY and can audit the playable game without waiting on this infrastructure work. `V3-003` stays blocked until `V3-001` and `V3-002` pass.

**Result:** Significant implementation and reproducible testing progress. **Production-grade approval cannot yet be verified.**