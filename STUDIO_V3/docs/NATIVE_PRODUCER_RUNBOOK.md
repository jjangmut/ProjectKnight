# ProjectKnight Studio V3 — Native Producer Runbook (TASK V3-002-R3)

## 1. Architectural Model & Plane Separation

ProjectKnight Studio V3 separates the **Execution Plane** from the **Control Plane**:

```text
====================================================================================
                        EXECUTION PLANE (Antigravity IDE)
====================================================================================
                   +----------------------------------+
                   |           PK_Producer            |
                   |  (Native IDE Coordinator Agent)  |
                   +-----------------+----------------+
                                     |
         +---------------------------+---------------------------+
         | (invoke_subagent)         | (invoke_subagent)         | (invoke_subagent)
         v                           v                           v
+-----------------+         +-----------------+         +-----------------+
|  PK_ClientLead  |         |    PK_QALead    |         | PK_GameDirector |
| (Worker / Code) |         | (Independent QA)|         |  (Final Gate)   |
+--------+--------+         +--------+--------+         +--------+--------+
         |                           |                           |
         +---------------------------+---------------------------+
                                     |
                                     v [Transcript Logs & Artifacts]
====================================================================================
                        CONTROL PLANE (Python & SQLite)
====================================================================================
                                     |
                                     v
                       +---------------------------+
                       |     SingleEntryRunner     |
                       |    (TaskDispatcher API)   |
                       +-------------+-------------+
                                     |
     +-------------------------------+-------------------------------+
     v                               v                               v
[QueueStore / DB]           [Policies & Gates]             [Audit / Manifest]
- Immutable Invocations     - allow_mock=False             - SHA256 Evidence
- Unique Run Leases         - Structured Verdict Parsing   - Git Object Verify
- CAS Optimistic Locks      - Two-Key Independent Signoff  - events.jsonl
```

### Execution Plane:
- **Actor:** `PK_Producer` inside the Antigravity IDE context.
- **Mechanism:** Native `invoke_subagent` calls to spawn `PK_ClientLead`, `PK_QALead`, and `PK_GameDirector`.
- **Guarantee:** Each subagent runs in its own isolated conversation container, recorded on disk at `<brainDir>/<session_id>/.system_generated/logs/transcript.jsonl`.
- **Honesty Invariant:** Standalone Python CLI (`cli.py run-loop`) **cannot** create native subagents without an IDE host. When running outside the IDE, it fails closed with `AGENT_COMPLETION_NOT_VERIFIED`.

### Control Plane:
- **Actor:** Python Orchestrator (`QueueStore`, `TaskDispatcher`, `SingleEntryRunner`).
- **Mechanism:** SQLite WAL transactions with `filelock`, optimistic concurrency control, git commit object validation, and cryptographic SHA256 evidence manifests.
- **Guarantee:** Never permits self-approval, mock provider milestones (`allow_mock=False`), forged CLI sessions, or lingering leases after approval.

---

## 2. Producer Autonomous Quality Loop Procedure

From a single user prompt initiating a task, `PK_Producer` follows this deterministic state machine:

### Cycle 1 — Worker Implementation:
1. **Initialize Task & Run Token:**
   - Create unique `run_id`: `run-r3-<timestamp>-<hash>`.
   - Acquire exclusive lease on task: `dispatcher.start_task(task_id, actor="PK_ClientLead", claim_token=run_id)`.
2. **Invoke Worker (`PK_ClientLead`):**
   - Call native `invoke_subagent(TypeName="PK_ClientLead", Role="Lead Client Programmer", Prompt=...)`.
   - Wait for completion notification.
   - Worker writes code, runs local validation, creates Git commit, and reports SHA.
3. **Control Plane Ingestion:**
   - Call `runner.step_worker_delivery(task_id, session_id, commit_sha, evidence_paths)`.
   - AgentAPI validates `typeName="PK_ClientLead"` and `parentConversationId`.
   - SQLite registers immutable invocation record and records SHA256 evidence manifest.
   - Task transitions `IN_PROGRESS` -> `IN_REVIEW`.

### Cycle 1 QA — Independent Verification:
4. **Invoke QA (`PK_QALead`):**
   - Call native `invoke_subagent(TypeName="PK_QALead", Role="Independent QA Lead", Prompt=...)`.
   - QA inspects submitted commit SHA and executes independent functional & headless engine tests.
   - QA outputs schema-compliant structured JSON verdict:
     ```json
     {
       "task_id": "...",
       "iteration": 1,
       "role": "PK_QALead",
       "reviewed_commit_sha": "<sha>",
       "verdict": "FIX_REQUIRED",
       "issues": [{"id": "ISS-...", "severity": "P1", "title": "...", "steps": "...", "expected": "...", "actual": "...", "evidence": [...]}]
     }
     ```
5. **Control Plane Ingestion & Issue Registration:**
   - Call `runner.step_reviewer_verdict(task_id, "PK_QALead", session_id, commit_sha, worker_session_id)`.
   - Task transitions `IN_REVIEW` -> `FIX_REQUIRED`.
   - Issue persisted into SQLite `issues` table and `queue.json`.

### Cycle 2 — Worker Rework (Zero Human Intervention Required):
6. **Re-Invoke Worker (`PK_ClientLead`):**
   - `PK_Producer` automatically starts new iteration and passes open issue details to `PK_ClientLead`.
   - Worker implements fix, commits new SHA, and returns evidence.
7. **Control Plane Delivery:**
   - Call `runner.step_worker_delivery(task_id, session_id, new_commit_sha, evidence_paths)`.
   - Task transitions `IN_PROGRESS` -> `IN_REVIEW`.

### Cycle 2 QA — Independent Retest:
8. **Invoke QA (`PK_QALead`):**
   - QA retests the *new exact SHA* in headless engine.
   - If tests pass, marks issue RESOLVED and outputs structured JSON `verdict: "PASS"`.
9. **Control Plane Ingestion:**
   - Call `runner.step_reviewer_verdict(...)`.
   - Task records 1/2 independent pass. Remains in `IN_REVIEW`.

### Cycle 3 — Director Milestone Gate:
10. **Invoke Game Director (`PK_GameDirector`):**
    - Call native `invoke_subagent(TypeName="PK_GameDirector", Role="Product and Milestone Authority", Prompt=...)`.
    - Director inspects the exact same SHA, verifies 0 open blockers, and outputs structured JSON `verdict: "PASS"`.
11. **Final Two-Key Approval & Lease Clearance:**
    - Call `runner.step_reviewer_verdict(...)`.
    - Both distinct provider-verified AI reviews pass -> Two-key approval gate satisfied.
    - Task transitions `IN_REVIEW` -> `APPROVED`.
    - `lease_owner` and `lease_expires_at` are atomically set to `NULL`.

---

## 3. Command Reference & Diagnostic CLI

### Inspect Queue Status:
```powershell
python -m STUDIO_V3.orchestrator.cli show
```

### Inspect Open Issues:
```powershell
python -m STUDIO_V3.orchestrator.cli issues
```

### Reconcile Local SQLite DB with queue.json Snapshot:
```powershell
python -m STUDIO_V3.orchestrator.cli reconcile
```

### Probe Provider Capabilities:
```powershell
python -m STUDIO_V3.orchestrator.cli probe
```

### Run Python Test Suite (29 Tests):
```powershell
python -m unittest discover -s STUDIO_V3/tests -p "test_*.py" -v
```

### Run Godot Headless Engine Tests:
```powershell
& "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\JUNYPAPA_STUDIO\Projects\ProjectKnight" --script "D:\JUNYPAPA_STUDIO\Projects\ProjectKnight\STUDIO_V3\tests\fixtures\test_fixture_stamina_r3.gd"
```

---

## 4. Governance & Anti-Spoofing Rules

1. **No Worker Self-Approval:** A task owner cannot review or approve their own deliverables.
2. **Provider Session Verification:** Reviewer sessions must be attested by `agentapi.bat get-conversation-metadata` with matching `typeName` and `parentConversationId`.
3. **No Mock Provider Milestones:** `allow_mock=False` is enforced on all production gates. `MOCK_SIMULATED`, `SIMULATED_MOCK`, and `MOCK` providers cannot approve production tasks.
4. **Immutable Provenance:** Invocations cannot be overwritten (`INSERT OR REPLACE` is forbidden; duplicate invocation IDs raise `PolicyViolation`).
5. **Session Cross-Task Reuse Blocked:** A session registered for one task/iteration cannot be reused by another task/iteration.
6. **Atomic Lease Clearance:** An approved task must have `lease_owner=None` and `lease_expires_at=None`.
7. **Cleanroom Boundary:** Game code (`CLIENT/Game/`) and scenes are never modified during orchestrator verification tasks.
