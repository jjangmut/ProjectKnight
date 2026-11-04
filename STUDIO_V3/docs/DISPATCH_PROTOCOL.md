# Studio V3 — Dispatch and Governance Protocol

## 1. Principles
1. **Implementation is never approval:** The worker who implements code or art cannot approve it.
2. **Independent verification:** Reviewers must be distinct agents invoked independently.
3. **Evidence-backed gates:** Every status advance (`IN_REVIEW`, `APPROVED`) requires verifiable artifacts on disk.
4. **Bounded rework:** Maximum 3 improvement cycles per task execution. Unresolved defects remain `FIX_REQUIRED`.

## 2. State Machine

```text
[READY] ──(Producer assigns owner)──► [IN_PROGRESS]
                                           │
                                    (Owner submits work + evidence)
                                           │
                                           ▼
                                      [IN_REVIEW]
                                      /         \
                      (Any reviewer rejects)   (All reviewers pass)
                                    /             \
                                   ▼               ▼
                           [FIX_REQUIRED]      [APPROVED]
                                   │
                           (Producer reassigns)
                                   │
                                   ▼
                             [IN_PROGRESS]
                             (next cycle)
```

## 3. Review Ownership Matrix
- **Milestone Tasks:** Require independent review from both `PK_QALead` and `PK_GameDirector`.
- **Game Design Tasks:** Reviewed by `PK_GameDirector` + `PK_QALead`.
- **Art Direction Tasks:** Reviewed by `PK_ArtDirector` (or `PK_GameDirector` if Art Director implemented) + `PK_QALead`.
- **Client Programming Tasks:** Reviewed by `PK_ClientLead` (peer) or `PK_GameDirector` + `PK_QALead`.

## 4. Structured Defect Filing
When a reviewer issues `FIX_REQUIRED`, they must file at least one structured `Issue`:
- **ID:** Unique issue identifier (e.g. `ISS-001`).
- **Severity:**
  - `P0`: Blocker. Milestone progression immediately halted.
  - `P1`: Major. Must be resolved before task approval.
  - `P2`: Minor. Polish backlog.
  - `P3`: Trivial. Optional enhancement.
- **Reproduction Steps:** Step-by-step instructions to trigger defect.
- **Expected vs Actual:** Exact behavior deviation.
- **Evidence:** Log, trace, or screenshot path.

## 5. Event Audit Logging
All state transitions append an immutable record to `STUDIO_V3/events.jsonl`:
```json
{
  "created_at": "2026-11-04T14:30:00Z",
  "event_type": "TASK_APPROVED",
  "task_id": "V3-002",
  "actor": "PK_GameDirector",
  "commit_sha": "a1b2c3d4...",
  "verdict": "APPROVED",
  "evidence_paths": ["STUDIO_V3/evidence/review.md"]
}
```
