# ProjectKnight AUTOMATION-006 (V3-018) — Desktop Shortcut & GUI Verification

## 1. Desktop Shortcut Specification

- **Shortcut Location:** `C:\Users\jjang\Desktop\ProjectKnight 작업 실행.lnk`
- **Target Path:** `C:\Program Files\dotnet\dotnet.exe`
- **Arguments:** `"D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\bin\ProjectKnight.Launcher.dll"`
- **Working Directory:** `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight`
- **Target Mode:** `CSHARP_DLL_HOST_VERIFIED` (Smart App Control compliant)
- **Native PE Status:** `BLOCKED_BY_SAC` (honest classification of `ProjectKnight.Launcher.exe` under Windows 11 policy `{0283ac0f-fff1-49ae-ada1-8a933130cad6}`)
- **Legacy Fallback Shortcut:** `C:\Users\jjang\Desktop\ProjectKnight 작업 실행 (SAC 대응).lnk` -> **DELETED** (clean single shortcut maintained).

---

## 2. Binary Deployment and Permanence

- **Deployment Directory:** `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\bin\`
- **Assembly:** `ProjectKnight.Launcher.dll` (v1.0.0, SHA: `085d050`)
- **Runtime Dependencies:**
  - `ProjectKnight.Launcher.deps.json`
  - `ProjectKnight.Launcher.runtimeconfig.json`
  - `ProjectKnight.Launcher.pdb`
- **Permanence:** Deployed outside git worktree (`D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\worktree`), preventing any corruption or disappearance when switching branches during automation tasks.

---

## 3. GUI Interaction Verification

### Step 1: Shortcut Activation & UI Launch
- Double-clicking the desktop shortcut spawns the official .NET runtime host launching `ProjectKnight.Launcher.dll`.
- C# WinForms `MainForm` opens with window title: `ProjectKnight 자동 개발 실행기`.
- Status badge shows: `대기 중 (Idle)`.
- Captured screenshot: `csharp_winforms_ui_launched.png`.

### Step 2: Task Discovery & Selection
- On startup / refresh click, `TaskDiscoveryService` queries GitHub remote branches and parses `STUDIO_V3/tasks/*.md`.
- All 29 task candidates are populated in `_cboTasks`.
- Selected candidate: `V3-TEST-AUTOMATION` on branch `test/v3-test-automation` (Commit SHA: `0e464b30`).
- UI details panel updates with Task ID, branch, commit SHA, and task overview.
- Run Selected button (`_btnRunSelected`) enables.
- Captured screenshot: `csharp_winforms_task_selected.png`.

### Step 3: Execution & Real-Time Heartbeat Streaming
- Auto-Approve toggle tested:
  - When `_chkAutoApprove.Checked == false`, confirmation dialog is required before execution.
  - When `_chkAutoApprove.Checked == true`, execution proceeds without blocking prompt.
- Stage progression:
  1. `DISCOVER` (작업 탐색) -> Passed
  2. `VALIDATE` (지시서 검증) -> Passed
  3. `WORKTREE` (Worktree 준비) -> Passed
  4. `EXECUTE` (CLI 개발·테스트) -> Running with live `[HEARTBEAT]` emissions every 6 seconds.
- Log entries streamed asynchronously into `RichTextBox` with ANSI/syntax coloring (Cyan for `[INFO]` and `[HEARTBEAT]`, Yellow for `[WARN]`, Green for `[PASS]`).
- Captured running screenshot: `csharp_winforms_running_progress.png`.

### Step 4: Completion & Artifact Generation
- CLI execution finishes, pre-commit scope check verifies only allowed files are modified.
- Output committed in isolated worktree.
- Final completion status rendered in UI badge and stage panel.
- Captured completed screenshot: `csharp_winforms_completed.png`.
- Full log saved to: `RUN_LOG.txt`.

---

## 4. Visual Evidence Manifest

1. `csharp_winforms_ui_launched.png` — Initial C# WinForms application window upon launch.
2. `csharp_winforms_task_selected.png` — UI showing non-first candidate `V3-TEST-AUTOMATION` selected with full metadata and button enablement.
3. `csharp_winforms_running_progress.png` — Active in-flight execution showing live stage progression and real-time heartbeat logs.
4. `csharp_winforms_completed.png` — Execution completed state with green badges and full session log.
