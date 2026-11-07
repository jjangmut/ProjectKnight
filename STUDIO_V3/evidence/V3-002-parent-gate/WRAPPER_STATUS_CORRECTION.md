# Studio V3 — Task V3-002-PARENT-APPROVAL Status Correction & Invariant Attestation

**Document ID:** `WRAPPER_STATUS_CORRECTION.md`  
**Task Reference:** `V3-002-PARENT-GATE-RECONCILE` (P1-01 Resolution)  
**Parent Milestone:** `V3-002` (Multi-Agent Production Infrastructure)  
**Authoritative Infra Implementation Commit:** `214000678186b6ebb42349eeb28336b4dcfe0e42`  
**Parent Milestone Reviewed Packet Commit:** `a1c954e98acbfec95395be973e5b016339888300`  
**Parent Milestone Review Output Commit:** `0c98ee150daeed6a4c1dad45c9ecd3da9c2367c6`  
**External Independent Review:** `STUDIO_V3/reviews/V3-002-PARENT-INDEPENDENT-REVIEW.md` (FIX_REQUIRED)  

---

## 1. Executive Summary & Objective

In the external independent review of the parent milestone roll-up (`STUDIO_V3/reviews/V3-002-PARENT-INDEPENDENT-REVIEW.md`), finding **P1-01** identified an internal approval state discrepancy:

```text
V3-002:                 status=APPROVED, iteration=2, reviewers=PK_QALead+PK_GameDirector, both PASS
V3-002-PARENT-APPROVAL: status=APPROVED, iteration=1, reviewers=PK_QALead+PK_GameDirector, reviews={}
```

Milestone `V3-002` satisfied the two-key independent review requirement (`PK_QALead` session `3aa4a1d0-4972-4750-852f-04e2675be74f` and `PK_GameDirector` session `178b4ee7-d8b6-4b9b-8310-4db576501a4b`). However, the secondary administrative wrapper task `V3-002-PARENT-APPROVAL` was marked `status="APPROVED"` while its own `reviews` mapping was completely empty (`reviews={}`).

The purpose of this document is to:
1. Provide the exact root cause of this discrepancy backed by the authentic execution script `apply_parent_approval.py`.
2. Explicitly separate the scopes of milestone `V3-002`, wrapper `V3-002-PARENT-APPROVAL`, and new correction task `V3-002-PARENT-GATE-RECONCILE`.
3. Correct the unsupported status of `V3-002-PARENT-APPROVAL` to `FIX_REQUIRED` (annotated as `SUPERSEDED / INVALID FOR GATING`) through the SQLite-backed authoritative `QueueStore`, without fabricating reviews or rewriting history.
4. Establish and enforce a permanent read-only queue invariant that blocks any task from holding `TaskState.APPROVED` without valid two-key review records.

---

## 2. Root Cause Analysis (Authentic Script Provenance)

The authentic Python script used to apply the parent approval transitions—preserved at `C:\Users\jjang\.gemini\antigravity\brain\c1845c39-fd7b-445c-9a68-644aaac576ff\scratch\apply_parent_approval.py`—was audited.

In that script:
1. **Lines 50–184:** `task_id = "V3-002"` was properly transitioned through `IN_PROGRESS -> IN_REVIEW`, registered its two subagent invocations, populated `task.reviews` with full signed review dictionaries, evaluated `can_approve(task, invocation_registry=qs)`, and set `task.status = TaskState.APPROVED`.
2. **Lines 186–250:** The 5 formal audit events (`TASK_STARTED`, `WORK_SUBMITTED`, `REVIEW_PASSED (QA)`, `REVIEW_PASSED (Director)`, `TASK_APPROVED`) were recorded for `task_id="V3-002"`.
3. **Lines 252–264:** The script author handled the administrative tracking task:
   ```python
   # Also update tracking task V3-002-PARENT-APPROVAL to APPROVED
   t_rollup = qs.get_task("V3-002-PARENT-APPROVAL")
   if t_rollup:
       t_rollup.status = TaskState.APPROVED
       t_rollup.current_commit_sha = sha_reviewed
       t_rollup.iteration = 1
       t_rollup.evidence = evidence_files
       t_rollup.evidence_manifest = manifest
       t_rollup.lease_owner = None
       t_rollup.lease_expires_at = None
       t_rollup.notes = "Completed. Parent milestone V3-002 officially transitioned to APPROVED via verified two-key independent reviews."
       qs.save_task(t_rollup)
       print("Updated tracking task V3-002-PARENT-APPROVAL to APPROVED.")
   ```

### Finding
The author treated `V3-002-PARENT-APPROVAL` purely as a tracking envelope for `V3-002`. Because subagents had explicitly attested `task_id="V3-002"`, their review records could not be registered for `V3-002-PARENT-APPROVAL` (which would have violated `policies.py` session isolation and task binding). As a shortcut, `t_rollup.status` was set directly to `TaskState.APPROVED` via `qs.save_task(t_rollup)` without calling `can_approve(t_rollup)` or registering separate signed reviews.

This directly contradicted `STUDIO_V3/orchestrator/policies.py::can_approve`, which requires every task with declared reviewers to have matching `PASS` records.

---

## 3. Separation of Concerns & Non-Counterfeiting Policy

To maintain absolute governance integrity:

1. **Milestone `V3-002` (Historical Authority):**
   - Retains its valid, verified status of `APPROVED` (iteration 2, commit `a1c954e98acbfec95395be973e5b016339888300`).
   - Backed by genuine subagent sessions `3aa4a1d0-4972-4750-852f-04e2675be74f` (`PK_QALead`) and `178b4ee7-d8b6-4b9b-8310-4db576501a4b` (`PK_GameDirector`).
   - Its history is NOT mutated, deleted, or reopened.

2. **Wrapper Task `V3-002-PARENT-APPROVAL` (Corrected Wrapper):**
   - Never underwent its own independent review cycle.
   - We strictly refuse to counterfeit or copy `V3-002` reviews onto `V3-002-PARENT-APPROVAL`.
   - Its status is corrected from `APPROVED` to `FIX_REQUIRED` with note: `SUPERSEDED / INVALID FOR GATING: Administrative wrapper previously marked APPROVED without independent reviews. Milestone approval is governed directly by V3-002.`
   - In accordance with existing schema enums (`READY`, `IN_PROGRESS`, `IMPLEMENTATION_COMPLETE`, `IN_REVIEW`, `FIX_REQUIRED`, `APPROVED`, `BLOCKED`), `FIX_REQUIRED` is the canonical legal state representing an unapproved task requiring resolution.

3. **Correction Task `V3-002-PARENT-GATE-RECONCILE` (Active Bounded Scope):**
   - Dedicated governance task created to reconcile findings P1-01, P1-02, and P1-03.
   - Must undergo its own distinct two-key independent review by fresh `PK_QALead` and `PK_GameDirector` sessions.
   - It cannot and will not inherit approval from `V3-002`.

---

## 4. Controlled State Correction Procedure

The correction is applied via the SQLite-backed authoritative state store (`QueueStore`) and recorded append-only:

1. **Database Authority:**
   - Authoritative database: `STUDIO_V3/queue.db`.
   - Backed up prior to modification to scratch (`queue.db.bak_gate_reconcile_start`).
2. **State Transition in `queue.db`:**
   - Task `V3-002-PARENT-APPROVAL` is loaded via `QueueStore.get_task`.
   - Status updated: `TaskState.APPROVED` -> `TaskState.FIX_REQUIRED`.
   - Note updated:
     `"SUPERSEDED / INVALID FOR GATING: Corrected per external independent review finding P1-01. Administrative wrapper previously marked APPROVED without its own two-key independent reviews. Authoritative milestone approval is tracked directly on task V3-002."`
   - Saved via `QueueStore.save_task`.
3. **Audit Event in `events.jsonl`:**
   - Event recorded via `EventLog.record_event`:
     - `event_type`: `TASK_STATUS_CORRECTED`
     - `task_id`: `V3-002-PARENT-APPROVAL`
     - `actor`: `PK_Producer`
     - `provider`: `ANTIGRAVITY_PARENT`
     - `verdict`: `FIX_REQUIRED`
     - `details`:
       ```json
       {
         "previous_status": "APPROVED",
         "new_status": "FIX_REQUIRED",
         "reason": "Corrected wrapper approval inconsistency (P1-01). Empty reviews={} is invalid for gating.",
         "authoritative_parent_task_id": "V3-002",
         "source_commit_sha": "0c98ee150daeed6a4c1dad45c9ecd3da9c2367c6"
       }
       ```
4. **Snapshot Synchronization:**
   - `STUDIO_V3/queue.json` exported directly from `queue.db` using `QueueStore.export_snapshot`.
   - No manual JSON editing.

---

## 5. Queue Invariant Specification

To permanently prevent recurrence of this issue, the read-only invariant rule is defined as follows:

```python
def check_task_approval_invariant(task: Task) -> Tuple[bool, str]:
    """Enforce that every APPROVED task has verified independent reviews."""
    if task.status != TaskState.APPROVED:
        return True, "Non-approved task; invariant does not apply."

    if not task.reviewers:
        return False, f"Task {task.id} is APPROVED but has no designated reviewers."

    if not task.reviews or len(task.reviews) == 0:
        return False, f"Task {task.id} is APPROVED but reviews dictionary is empty."

    for r in task.reviewers:
        review = task.reviews.get(r)
        if not review:
            return False, f"Task {task.id} is APPROVED but lacks review for designated reviewer '{r}'."
        if review.get("result") != "PASS":
            return False, f"Task {task.id} reviewer '{r}' verdict is '{review.get('result')}', not PASS."
        if review.get("iteration") != task.iteration:
            return False, f"Task {task.id} reviewer '{r}' iteration mismatch: {review.get('iteration')} != {task.iteration}."
        if review.get("reviewed_commit_sha") != task.current_commit_sha:
            return False, f"Task {task.id} reviewer '{r}' SHA mismatch: {review.get('reviewed_commit_sha')} != {task.current_commit_sha}."

    return True, f"Task {task.id} satisfies approval invariant."
```

### Invariant Test Results:
- `V3-001` (iter 1, `a71223...`): **PASS**
- `V3-002` (iter 2, `a1c954...`): **PASS**
- `V3-002-CLOSE` (iter 1, `214000...`): **PASS**
- `V3-001-ATTESTATION-CLOSE` (iter 1, `7881e3...`): **PASS**
- `V3-002-PARENT-APPROVAL` (original state, `status=APPROVED, reviews={}`): **FAIL (VIOLATION DETECTED)**
- `V3-002-PARENT-APPROVAL` (corrected state, `status=FIX_REQUIRED`): **PASS (Invariant satisfied, non-approved)**

---

## 6. Attestation

The wrapper approval inconsistency is resolved truthfully. No historical data has been destroyed, no reviews have been forged, and the queue state is fully synchronized with the authoritative invariant policy.
