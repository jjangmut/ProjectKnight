# AUTOMATION-005 — Independent Code Review / Mandatory Fixes

**Reviewed GitHub implementation:** `a1d72f5e539e07bdcd82de9b94e44b3c12b363ef`
**Branch:** `studio/v3-automation-winforms-rebuild`
**Verdict:** **PARTIAL / NOT READY FOR DAILY USE**

## Verified
- C# `.NET 8` WinForms source, tests and `runner.ps1` modifications are committed; Python Tkinter launcher files `launcher.py`, `run_launcher.*` and Python tests are removed from Git.
- Test branch `test/v3-test-automation` prior remote execution and test artifacts exist; latest WinForms implementation's full GUI interaction and install are *not independently observable* in GitHub.
- Antigravity report says it built self-contained `ProjectKnight.Launcher.exe` and linked desktop shortcut, **but reports actual native EXE launch fails under Windows Smart App Control** `0x800711C7` / CodeIntegrity. This is a release blocker against the user's requested native WinForms EXE.
- A PowerShell WinForms fallback `launcher_winforms.ps1` was added. Although this may produce a Windows Forms UI, it is **not the requested C# WinForms EXE**; do not claim it validates the native app. Do not bypass/disable Smart App Control, Defender, Code Integrity, certificate trust or device policies.

## Source-confirmed blocking defects
1. **Manual approval mode hangs/fails.** In `MainForm.cs` lines ~475-535, the GUI confirms manual mode through a MessageBox. But `ExecuteTaskInternalAsync` passes `_chkAutoApprove.Checked` (FALSE) into `AutomationRunnerService.ExecuteTaskAsync`; that only supplies `-AutoApprove` when TRUE. `runner.ps1` lines ~573-583 then calls `Read-Host` in a hidden/no-console process. After GUI approval, always pass a distinct `-ApprovedByGui`/approved boolean to the runner and bypass only *duplicate manual prompt*, never SHA/scope/security checks. An ON/OFF setting must not determine whether GUI approval was already granted.
2. **False success result possible.** `AutomationRunnerService.cs` sets `Success=true` whenever PowerShell exit code is 0 and defaults `FinalStatus=COMPLETED`, ignoring `NO_CHANGES`, `PUSH_SKIPPED` and the runner's `[STAGE:COMPLETE]` status parsing mismatches. `runner.ps1` saves these as `completed_tasks` regardless of final status. Require a strict machine-readable end-result (JSON or explicit sentinel) with task ID/branch/SHA, actual commit SHA, push confirmation and status. Only `COMPLETED` with verified required checks should be success; partial outcomes remain retryable and are not stored as fully completed.
3. **Worktree may contain stale target branch code despite approved SHA.** `Ensure-Worktree` does not reset/fast-forward an already existing target local branch to verified remote SHA when switching/when same branch; `runner.ps1` verifies `origin/<branch>` HEAD but does not ensure `git -C $WorktreePath rev-parse HEAD` equals exact approved SHA immediately before CLI starts. Need exact binding check after checkout; abort on mismatch (do not forcibly discard uncommitted work).
4. **Destructive residue cleanup.** `runner.ps1` `Ensure-Worktree` (~295-299) automatically executes `git reset --hard HEAD` and `git clean -fd` on dirty worktree. This can silently erase user/agent unsaved work. Stop with clear message and require separate explicit recovery, not automatic destructive cleanup.
5. **Native EXE is OS-blocked.** Provide compliant path to run C# WinForms EXE under user's Windows security policy, e.g. verified trusted code signing via established publisher / legitimate administrative policy. Do not self-sign merely to evade Smart App Control or swap silently to PowerShell. If unavailable, clearly report `BLOCKED_BY_SAC` and request user decision, without presenting fallback as completion. Do not disable security settings as a workaround.

## Additional defects/risks to address
- `TaskDiscoveryService.RunGit` uses `StandardOutput.ReadToEnd()` then `WaitForExit(timeout)`; the timeout cannot bound an indefinitely blocked output read, and nonzero exit code is ignored. Fix async process wait/kill and check exit code; task discovery must not claim success from failed `git fetch`.
- The previous username's repo is **public**; `security_settings.json` still has broad `command(*)` allowance with string-deny rules. This is not OS isolation; state residual risk prominently.
- Dedicated native EXE GUI acceptance test was not completed because OS blocked launching it; scripted/headless and PowerShell fallback checks don't prove full UI behavior.
- On default action, if no chosen task, code chooses first valid task; in automatic approval mode with >1 valid candidates, do **not** start first task without explicit selection (one-click can be limited to unique candidate).
- Confirm actual desktop shortcut points only to C# EXE, and remove **SAC fallback shortcut/script** when genuine EXE is working; maintain user's requirement to remove Python GUI, not engine components.

## Acceptance criteria for revision
1. C# WinForms **actual EXE** launches on Windows without disabling security controls; if blocked, truthful partial report and no silent substitutions.
2. Both GUI manual approval and auto-approval ON start the **same exact task** with correct approved TaskId+Branch+40-character SHA, with no second hidden `Read-Host`.
3. UI receives reliable JSON status: SUCCESS/FAILED/PARTIAL/PUSH_SKIPPED/NO_CHANGES, never false complete; completed state only for verified completion.
4. Worktree HEAD equals approved commit before AGY, and dirty worktree fails closed without deletion.
5. Test multiple candidates, non-first selection, SHA race/mismatch, git failure, CLI failure, empty/no-change, push failure, with evidence.
6. Keep V3-017 and main development workspace untouched. Push code fixes to this branch; report tested vs untested clearly.

**Focus:** fix these defects, do not expand architecture or add polling/MCP/Actions runner.
