# Studio V3 — Operator Runbook (V3-002-R1)

## 1. Quick Start Commands

The Studio V3 Orchestrator is managed via the unified CLI tool or programmatically through Python.

### Inspect Status & Tasks
```powershell
python -m STUDIO_V3.orchestrator.cli show
```
Displays current tasks, iterations, active owners, reviewer statuses, state version, and open issues.

### Start a Task (Owner Only with Exclusive Lease)
```powershell
python -m STUDIO_V3.orchestrator.cli start V3-001 --actor PK_ClientLead
```
Claims an exclusive 300s lease on the task, transitions `READY` / `FIX_REQUIRED` -> `IN_PROGRESS`, increments iteration, and logs `TASK_STARTED`.

### Submit Work Deliverables (Cryptographic Manifest)
```powershell
python -m STUDIO_V3.orchestrator.cli submit V3-001 --actor PK_ClientLead --evidence STUDIO_V3/evidence/V3-001/audit.md
```
Computes SHA256 hashes of all submitted evidence files, builds the cryptographic manifest, transitions `IN_PROGRESS` -> `IN_REVIEW`, and logs `WORK_SUBMITTED`.

### Review a Task (Authorized Reviewer Only with Session Attestation)
```powershell
# Reviewer approves
python -m STUDIO_V3.orchestrator.cli review V3-001 --actor PK_QALead --result PASS --evidence STUDIO_V3/evidence/V3-001/qa_report.md --session-id qa-sess-12345

# Reviewer rejects with defect
python -m STUDIO_V3.orchestrator.cli review V3-001 --actor PK_QALead --result FIX_REQUIRED --evidence STUDIO_V3/evidence/V3-001/qa_report.md --session-id qa-sess-12345 --issue-id ISS-001 --issue-title "Depth movement collision bug" --severity P1
```

## 2. Issue Lifecycle
- When a reviewer rejects with `FIX_REQUIRED`, the issue is recorded in SQLite and exported to `queue.json`.
- The worker reads open issues with:
  ```powershell
  python -m STUDIO_V3.orchestrator.cli issues --task V3-001
  ```
- After fixing, the issue is resolved upon re-review.

## 3. Crash and State Recovery
- **Database Engine:** SQLite in WAL (Write-Ahead Logging) mode located at `STUDIO_V3/queue.db`.
- **Snapshot Recovery:** If the database file is ever lost or corrupted, restore from `STUDIO_V3/queue.json`:
  ```powershell
  python -m STUDIO_V3.orchestrator.cli restore --snapshot STUDIO_V3/queue.json
  ```
- **Audit Log:** `STUDIO_V3/events.jsonl` contains immutable event records for forensic analysis.
- **Optimistic Locking:** If concurrent modifications occur, `ConcurrentModificationError` is raised and prevents database corruption.
- **Task Leasing:** Prevents duplicate runs of the same task by distinct worker processes.
