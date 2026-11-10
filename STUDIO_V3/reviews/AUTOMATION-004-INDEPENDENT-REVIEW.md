# AUTOMATION-004 Independent Code Review — Fix Before Daily Use

**Review date:** 2026-11-10
**Reviewed implementation:** `854360f0b7c21ab39e87aab60e54b72b188491d6`
**Verdict:** **PARTIAL / HOLD for unattended auto-approval**

## Verified on GitHub
- `tools/automation/launcher.py`, `runner.ps1`, `security_settings.json`, tests, README and verification report committed.
- `test/v3-test-automation` HEAD `bedc1c0524028c8a462668175c95198007599902`, verification JSON changed.
- Desktop `.lnk` existence and the real UI are **only Antigravity-reported**, not independently observed in GitHub.

## Blocking defects (source-based)
1. **Selected task cannot execute when multiple candidates exist.** In `launcher.py` `_on_scan_done` lines ~592-600, `len(candidates)>1` always returns after displaying "select then click again". Next click calls `_scan_tasks_worker(True)`, repopulates the ComboBox with `.current(0)`, and again returns for multiple. It never consumes the user's prior selection. Fix by separating **Refresh tasks** from **Run selected task** or honoring an explicit persisted candidate ID before returning; never assume first item.
2. **Task discovery is noisy/unsafe.** `_scan_tasks_worker` lines ~495-553 scans *every* `STUDIO_V3/tasks/*.md` on every `studio/v3-*` branch and accepts empty declared branch or `V3-TEST*` without target match (line ~533). This surfaces historical/copied tasks and duplicates. Restrict to branch-owned task ID from exact branch naming and matching `Branch:` metadata, valid task ID, and desired task class; dedupe by task ID+branch+SHA. If metadata absent, do not autoapprove it.
3. **Approved remote HEAD/SHA isn't bound to execution.** GUI discovers `full_sha`, but `_run_task_worker` passes only `-TaskId` to `runner.ps1` (lines ~648-655). Runner `Invoke-Execute` reads `$TasksDir\$TaskId.md` from local main repo or worktree *before* checking out intended worktree branch (~484-540). It never receives or checks GUI-approved branch/SHA. Fix runner args `-ExpectedBranch`, `-ExpectedCommitSha` and verify fetched remote branch HEAD, exact task file content and target branch before starting CLI; no local fallback or auto-approval if mismatch. This is a security and correctness BLOCKER.
4. **Tkinter called from background worker.** `_scan_tasks_worker` directly invokes `self._set_ui_running`, `_reset_stages`, `_set_stage_status` (~476-478). Use `msg_queue` and `root.after` for all Tk GUI mutations, not worker thread direct calls.
5. **Completed status may be falsely reported.** `runner.ps1` permits exit code 0 with unparseable/absent CLI JSON (lines ~603-624) and still continues to commit and set `COMPLETED`. It also can set COMPLETED with no changes (lines ~661-679), or after push skipped. Implement fail-closed JSON result validation with status `SUCCESS`, verify task-specific acceptance conditions, distinguish NO_CHANGES/PARTIAL/PUSH_SKIPPED vs complete, and on CLI failure avoid automatic PUSH.
6. **Permissions aren't a true sandbox.** Committed `security_settings.json` explicitly grants `command(*)` then excludes certain strings by wildcard. This does not imply OS-level isolation and can permit unexpected commands; worktree separation does not protect arbitrary local files. For auto-approval, use reduced-privilege OS process/account and limit filesystem access where feasible. Never claim full workstation isolation.

## Required validation
- Test **2+ historical/task candidates** and select a non-first task in manual AND auto-approval modes; prove execution of exact selected ID/branch/SHA.
- Test changed remote SHA between display and click; execution must stop.
- Test task markdown with wrong/missing branch; no auto-approval.
- Test CLI returns exit 0 but bad JSON, denied tools, no changes, push failure; GUI must show failure/partial accordingly.
- Exercise real GUI in Windows desktop (not just Python settings tests), capture evidence.
- Preserve V3-017 and existing production project workspace. Restrict changes to safe automation files and review results.
- Do not add background polling, MCP, Webhook, GitHub Actions runner.

**Report:** actual GitHub commit, precise test proof, screenshots or UI test limitations, any remaining risks. Do not call the one-click app production ready before blockers fixed.
