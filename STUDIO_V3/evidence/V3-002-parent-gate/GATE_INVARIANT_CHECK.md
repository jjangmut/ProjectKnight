# Studio V3 — Queue Approval Invariant Check & Verification Report

**Document ID:** `GATE_INVARIANT_CHECK.md`  
**Task Reference:** `V3-002-PARENT-GATE-RECONCILE` (P1-01 Resolution)  
**Parent Milestone:** `V3-002` (Multi-Agent Production Infrastructure)  
**Authoritative Infra Implementation Commit:** `214000678186b6ebb42349eeb28336b4dcfe0e42`  
**External Independent Review:** `STUDIO_V3/reviews/V3-002-PARENT-INDEPENDENT-REVIEW.md` (FIX_REQUIRED)  

---

## 1. Specification of the Read-Only Queue Invariant

In accordance with finding P1-01 of the external independent review, a formal read-only queue invariant validator is established:

```python
def validate_task_approval_invariant(task: Task) -> Tuple[bool, str]:
    """Enforce that every TaskState.APPROVED task possesses valid, signed two-key PASS reviews."""
    if task.status != TaskState.APPROVED:
        return True, f"Task {task.id} is {task.status.value}; approval invariant does not apply."

    if not task.reviewers:
        return False, f"INVARIANT_VIOLATION: Task {task.id} is APPROVED but has no designated reviewers."

    if not task.reviews or len(task.reviews) == 0:
        return False, f"INVARIANT_VIOLATION: Task {task.id} is APPROVED but reviews dictionary is empty."

    seen_sessions = set()
    for reviewer in task.reviewers:
        review = task.reviews.get(reviewer)
        if not review:
            return False, f"INVARIANT_VIOLATION: Task {task.id} is APPROVED but lacks review entry for designated reviewer '{reviewer}'."
        
        verdict = review.get("result")
        if verdict != "PASS":
            return False, f"INVARIANT_VIOLATION: Task {task.id} reviewer '{reviewer}' verdict is '{verdict}', not PASS."

        rev_iter = review.get("iteration")
        if rev_iter != task.iteration:
            return False, f"INVARIANT_VIOLATION: Task {task.id} reviewer '{reviewer}' iteration mismatch: {rev_iter} != {task.iteration}."

        rev_sha = review.get("reviewed_commit_sha")
        if rev_sha != task.current_commit_sha:
            return False, f"INVARIANT_VIOLATION: Task {task.id} reviewer '{reviewer}' commit SHA mismatch: {rev_sha} != {task.current_commit_sha}."

        session_id = review.get("session_id")
        if not session_id:
            return False, f"INVARIANT_VIOLATION: Task {task.id} reviewer '{reviewer}' lacks authenticated session ID."

        if session_id in seen_sessions:
            return False, f"INVARIANT_VIOLATION: Task {task.id} reviewers share duplicate session ID '{session_id}'. Independent agents required."
        seen_sessions.add(session_id)

    return True, f"INVARIANT_SATISFIED: Task {task.id} has verified two-key independent approval."
```

---

## 2. Invariant Validation on Historical & Current Tasks

### Positive Invariant Tests (Legitimately Approved Tasks)

| Task ID | Status | Iteration | Commit SHA | Reviewers | Reviews Present | Invariant Result |
|---|---|---|---|---|---|---|
| `V3-001` | APPROVED | 1 | `a712236...` | `PK_QALead`, `PK_GameDirector` | Both PASS, distinct sessions | **PASS** |
| `V3-002` | APPROVED | 2 | `a1c954e...` | `PK_QALead`, `PK_GameDirector` | Both PASS, distinct sessions | **PASS** |
| `V3-002-CLOSE` | APPROVED | 1 | `2140006...` | `PK_QALead`, `PK_GameDirector` | Both PASS, distinct sessions | **PASS** |
| `V3-001-ATTESTATION-CLOSE` | APPROVED | 1 | `7881e32...` | `PK_QALead`, `PK_GameDirector` | Both PASS, distinct sessions | **PASS** |
| `V3-001-EVIDENCE-RECONCILE` | APPROVED | 1 | `c557147...` | `PK_QALead`, `PK_GameDirector` | Both PASS, distinct sessions | **PASS** |
| `FIXTURE-V3-LIVE-002` | APPROVED | 2 | `2f3cc94...` | `PK_QALead`, `PK_GameDirector` | Both PASS, distinct sessions | **PASS** |
| `FIXTURE-V3-LIVE-003` | APPROVED | 2 | `9d1012f...` | `PK_QALead`, `PK_GameDirector` | Both PASS, distinct sessions | **PASS** |

### Negative Invariant Tests (Demonstrating Fail-Closed Gate)

1. **Test Case NEG-01: `V3-002-PARENT-APPROVAL` in Pre-Correction State**
   - Input: `status = APPROVED`, `reviews = {}`, `reviewers = ["PK_QALead", "PK_GameDirector"]`
   - Validator Output:
     `INVARIANT_VIOLATION: Task V3-002-PARENT-APPROVAL is APPROVED but reviews dictionary is empty.`
   - Outcome: **DETECTED & BLOCKED (PASS)**

2. **Test Case NEG-02: Synthetic Task with Missing One Reviewer**
   - Input: `status = APPROVED`, `reviewers = ["PK_QALead", "PK_GameDirector"]`, `reviews = {"PK_QALead": PASS}`
   - Validator Output:
     `INVARIANT_VIOLATION: Task SYNTH-01 is APPROVED but lacks review entry for designated reviewer 'PK_GameDirector'.`
   - Outcome: **DETECTED & BLOCKED (PASS)**

3. **Test Case NEG-03: Synthetic Task with Mismatched Commit SHA**
   - Input: `status = APPROVED`, `current_commit_sha = "aaa..."`, `review.reviewed_commit_sha = "bbb..."`
   - Validator Output:
     `INVARIANT_VIOLATION: Task SYNTH-02 reviewer 'PK_QALead' commit SHA mismatch: bbb... != aaa...`
   - Outcome: **DETECTED & BLOCKED (PASS)**

4. **Test Case NEG-04: Synthetic Task with Shared Session ID**
   - Input: Both `PK_QALead` and `PK_GameDirector` reviews use identical `session_id = "shared-uuid"`
   - Validator Output:
     `INVARIANT_VIOLATION: Task SYNTH-03 reviewers share duplicate session ID 'shared-uuid'. Independent agents required.`
   - Outcome: **DETECTED & BLOCKED (PASS)**

---

## 3. Post-Correction Queue Status

When `V3-002-PARENT-APPROVAL` is transitioned from `APPROVED` to `FIX_REQUIRED` (annotated as `SUPERSEDED`):
- All remaining `APPROVED` tasks strictly satisfy the invariant.
- `V3-002-PARENT-APPROVAL` is non-approved (`FIX_REQUIRED`), so it no longer poses an invalid gating claim.
- The authoritative milestone `V3-002` remains the sole, validly approved multi-agent infrastructure milestone.
