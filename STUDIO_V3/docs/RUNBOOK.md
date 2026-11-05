# Studio V3 — Operator Runbook (V3-002-R2)

## 1. Single-Entry Autonomous Loop

The Studio V3 Orchestrator provides a unified, single-entry command to drive the full autonomous rework loop:

```powershell
python -m STUDIO_V3.orchestrator.cli run-loop <task_id> [--adapter {mock,bridge,antigravity}] [--max-cycles 3]
```

### Supported Execution Modes & Provider Limitations
1. **`mock` mode (`--adapter mock`)**:
   - Used for deterministic unit and integration testing.
   - Emits `MOCK_TEST_PASS`. Mock verdicts cannot satisfy live milestone review gates.
2. **`bridge` mode (`--adapter bridge`)**:
   - Directly bridges to live Antigravity native subagents spawned in the IDE session.
   - Authenticates provider session IDs via `agentapi.bat get-conversation-metadata <session_id>`.
   - Validates that `subagentSpec.typeName` matches the designated reviewer/worker role.
   - Ingests completion records and structured review verdicts from `transcript.jsonl`.
3. **`antigravity` mode (`--adapter antigravity`)**:
   - Interfaces with standalone `agy` CLI or `agentapi.bat new-conversation`.
   - Note: If standalone `agy` is not installed on PATH, `agentapi.bat new-conversation` returns `AGENT_COMPLETION_NOT_VERIFIED` to prevent false completions.

---

## 2. Command Reference

### Inspect Status & Tasks
```powershell
python -m STUDIO_V3.orchestrator.cli show
```
Displays current tasks, iterations, active owners, reviewer statuses, state version, and open issues.

### Non-Destructive Queue Reconciliation
```powershell
python -m STUDIO_V3.orchestrator.cli reconcile
```
Non-destructively imports new tasks from `STUDIO_V3/queue.json` into local `STUDIO_V3/queue.db` under filelock while preserving local in-flight task progress and active issues.

### Start a Task (Owner Only with Unique Run Lease)
```powershell
python -m STUDIO_V3.orchestrator.cli start V3-001 --actor PK_ClientLead
```
Validates branch safety and prerequisite dependencies before claiming an exclusive 300s lease on the task. Transitions `READY` / `FIX_REQUIRED` -> `IN_PROGRESS`.

### Submit Work Deliverables (Cryptographic Manifest)
```powershell
python -m STUDIO_V3.orchestrator.cli submit V3-001 --actor PK_ClientLead --evidence STUDIO_V3/evidence/V3-001/audit.md
```
Verifies Git commit existence in the repository, computes SHA256 hashes of all submitted evidence files, builds the cryptographic manifest, transitions `IN_PROGRESS` -> `IN_REVIEW`, and logs `WORK_SUBMITTED`.

### Review a Task (Trusted Invocation Registry Attestation)
```powershell
# Reviewer approves
python -m STUDIO_V3.orchestrator.cli review V3-001 --actor PK_QALead --result PASS --evidence STUDIO_V3/evidence/V3-001/qa_report.md --session-id <verified_session_id>

# Reviewer rejects with defect
python -m STUDIO_V3.orchestrator.cli review V3-001 --actor PK_QALead --result FIX_REQUIRED --evidence STUDIO_V3/evidence/V3-001/qa_report.md --session-id <verified_session_id> --issue-id ISS-001 --issue-title "Collision bug" --severity P1
```
> [!IMPORTANT]
> Arbitrary unverified session IDs passed to `--session-id` will be rejected with `IdentityVerificationError`. All reviews must correspond to a registered invocation in the trusted provider registry.

---

## 3. Issue Lifecycle & Defect Resolution
- When a reviewer rejects with `FIX_REQUIRED`, the structured issue is recorded in SQLite and exported to `queue.json`.
- The worker reads open issues with:
  ```powershell
  python -m STUDIO_V3.orchestrator.cli issues --task V3-001
  ```
- The task transitions back to `IN_PROGRESS` upon worker rework.
- After fixing and independent retesting, the issue is marked `RESOLVED` and the two-key approval gate (`PK_QALead` + `PK_GameDirector`) evaluates final signoff.

---

## 4. Crash and State Recovery
- **Database Engine:** SQLite in WAL (Write-Ahead Logging) mode located at `STUDIO_V3/queue.db`.
- **Atomic File Writes:** Snapshot writes use temporary files and atomic `os.replace` under filelock.
- **Optimistic Locking:** Task versioning (CAS) detects and rejects concurrent modifications.
- **Snapshot Recovery:** If the database file is lost or corrupted, restore from `STUDIO_V3/queue.json`:
  ```powershell
  python -m STUDIO_V3.orchestrator.cli restore --snapshot STUDIO_V3/queue.json
  ```
- **Audit Log:** `STUDIO_V3/events.jsonl` contains immutable event records for forensic analysis.
