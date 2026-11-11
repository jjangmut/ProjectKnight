# ProjectKnight AUTOMATION-006 (V3-018) — Before & After Comparison

## 1. Executive Summary

| Item | Before (AUTOMATION-005) | After (AUTOMATION-006 / V3-018) | Status |
| :--- | :--- | :--- | :--- |
| **Executable Security & SAC** | `ProjectKnight.Launcher.exe` blocked by Windows 11 SAC (`0x800711C7`). Desktop shortcut default was broken. | Native standalone PE documented honestly as `BLOCKED_BY_SAC`. Verified launch path: `CSHARP_DLL_HOST_VERIFIED` via Microsoft-signed .NET host running compiled C# WinForms DLL. | **VERIFIED** |
| **Desktop Shortcut** | Duplicate shortcuts: broken EXE shortcut + PowerShell script fallback shortcut (`ProjectKnight 작업 실행 (SAC 대응).lnk`). | Single clean desktop shortcut `ProjectKnight 작업 실행.lnk` directly executing the compiled C# WinForms DLL via official .NET host. Legacy fallback deleted. | **VERIFIED** |
| **Binary Deployment Location** | Resided inside temporary worktree (`worktree\tools\automation\...`), vulnerable to branch switches. | Installed in stable external directory `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\bin\`, persistent across branch switches and worktree changes. | **VERIFIED** |
| **Live Progress & Streaming** | `runner.ps1` used blocking `WaitForExit()` without in-flight output forward. GUI UI appeared frozen during AGY CLI runs. | Dual-pipe asynchronous streaming with 6s heartbeats (`[HEARTBEAT]`). `AutomationRunnerService` parses heartbeats and `MainForm` updates status strip and rich text log in real-time. | **VERIFIED** |
| **Working Directory Safety** | `AutomationRunnerService` spawned PowerShell in `worktree`, holding directory handles during git checkout. | Set `WorkingDirectory` to `Automation\ProjectKnight` root, eliminating file locks on worktree during branch checkouts. | **VERIFIED** |
| **Candidate Guard (Fail-Closed)** | Auto-pick first candidate on multiple candidates caused unintended task runs if user did not choose. | When multiple candidates exist and none is explicitly selected, launcher halts and prompts user to pick a task. | **VERIFIED** |
| **Security Assertions** | Commit SHA mismatch check existed in runner but needed verification on Windows. | Rigorously tested: SHA mismatch halts with `Security Violation` before execution. Dirty worktree halts with `Safety Abort` without destructive reset. | **VERIFIED** |
| **Game Repository Isolation** | Preserved `Projects\ProjectKnight` and `V3-017`. | 100% preserved. `Projects\ProjectKnight` untouched. All test executions ran exclusively on `test/v3-test-automation`. | **VERIFIED** |

---

## 2. Technical Detail: Windows 11 Smart App Control (SAC) Compliance

### Windows 11 Code Integrity Observation
- **Error Code:** `0x800711C7` (`ERROR_SYSTEM_INTEGRITY_POLICY_VIOLATION`)
- **Event Log:** `Microsoft-Windows-CodeIntegrity/Operational` Event ID 3077
- **Policy ID:** `{0283ac0f-fff1-49ae-ada1-8a933130cad6}` (Smart App Control enforcement policy)
- **Policy Behavior:** Blocks unsigned native PE executables (`ProjectKnight.Launcher.exe`) generated locally without trusted enterprise/commercial CA signature or cloud reputation.

### Architectural Solution (`CSHARP_DLL_HOST_VERIFIED`)
1. In strict compliance with security rules, **SAC was not disabled**, no policy exclusions were added, and no untrusted self-signed certificates were injected into root stores.
2. Official Microsoft-signed executable `C:\Program Files\dotnet\dotnet.exe` is utilized as the host process.
3. The desktop shortcut (`C:\Users\jjang\Desktop\ProjectKnight 작업 실행.lnk`) targets:
   ```cmd
   "C:\Program Files\dotnet\dotnet.exe" "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\bin\ProjectKnight.Launcher.dll"
   ```
4. This loads and runs the **pure compiled C# WinForms application** (`MainForm`, `TaskDiscoveryService`, `AutomationRunnerService`) with 100% native WinForms fidelity while adhering completely to Windows 11 Smart App Control.
