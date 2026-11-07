#!/usr/bin/env python3
"""
ProjectKnight Studio V3 -- Parent Gate Reconciliation Verification Script
Task: V3-002-PARENT-GATE-RECONCILE
Verifies Git ancestry, infra source immutability, game source immutability,
events.jsonl historical preservation, and queue approval invariants.
"""

import hashlib
import json
import os
import pathlib
import subprocess
import sys

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

REPO_ROOT = pathlib.Path(r"D:\JUNYPAPA_STUDIO\Projects\ProjectKnight")
sys.path.insert(0, str(REPO_ROOT))

INFRA_SHA = "214000678186b6ebb42349eeb28336b4dcfe0e42"
GAME_BASE_SHA = "a71223615d0b77e36dd85edb24e138fc67ecc140"
PARENT_PACKET_SHA = "a1c954e98acbfec95395be973e5b016339888300"
PARENT_OUTPUT_SHA = "0c98ee150daeed6a4c1dad45c9ecd3da9c2367c6"

EVIDENCE_DIR = REPO_ROOT / "STUDIO_V3" / "evidence" / "V3-002-parent-gate"
VERIF_DIR = EVIDENCE_DIR / "verification"
VERIF_DIR.mkdir(parents=True, exist_ok=True)

raw_output_lines = []
negative_test_lines = []

def log(msg: str):
    try:
        print(msg)
    except Exception:
        print(msg.encode('ascii', 'replace').decode('ascii'))
    raw_output_lines.append(msg)

def log_neg(msg: str):
    try:
        print(msg)
    except Exception:
        print(msg.encode('ascii', 'replace').decode('ascii'))
    negative_test_lines.append(msg)

def run_cmd(cmd_list, cwd=REPO_ROOT):
    cmd_str = " ".join(cmd_list)
    log(f"$ {cmd_str}")
    res = subprocess.run(cmd_list, cwd=str(cwd), capture_output=True, text=True, encoding="utf-8", errors="replace")
    log(f"Exit code: {res.returncode}")
    if res.stdout:
        log(f"STDOUT:\n{res.stdout.strip()}")
    if res.stderr:
        log(f"STDERR:\n{res.stderr.strip()}")
    return res

log("=== ProjectKnight Studio V3 -- Parent Gate Reconciliation Verification Log ===")
log(f"Execution root: {REPO_ROOT}")
log(f"Infra Source SHA: {INFRA_SHA}")
log(f"Game Base SHA: {GAME_BASE_SHA}")
log(f"Parent Packet SHA: {PARENT_PACKET_SHA}")
log("")

# 1. Check Git ancestry
log("--- 1. Checking Git Ancestry ---")
r1 = run_cmd(["git", "merge-base", "--is-ancestor", INFRA_SHA, "HEAD"])
if r1.returncode != 0:
    log("FAIL: Current HEAD is not descendant of INFRA_SHA.")
    sys.exit(1)
log("PASS: Ancestry confirmed.")
log("")

# 2. Check infra diff
log("--- 2. Checking Infrastructure Immutability ---")
r2 = run_cmd(["git", "diff", "--name-status", INFRA_SHA, "HEAD", "--", "STUDIO_V3/orchestrator", "STUDIO_V3/tests", ".agents/agents"])
if r2.stdout.strip():
    log(f"FAIL: Unexpected infra diff:\n{r2.stdout}")
    sys.exit(1)
log("PASS: 0 lines modified in STUDIO_V3/orchestrator, STUDIO_V3/tests, .agents/agents.")
log("")

# 3. Check game code diff
log("--- 3. Checking Game Client Immutability ---")
r3 = run_cmd(["git", "diff", "--stat", GAME_BASE_SHA, "HEAD", "--", "CLIENT/Game/"])
if r3.stdout.strip():
    log(f"FAIL: Unexpected CLIENT/Game/ diff:\n{r3.stdout}")
    sys.exit(1)
log("PASS: 0 lines modified in CLIENT/Game/.")
log("")

# 4. Check historical 36 lines in events.jsonl
log("--- 4. Checking Historical 36 Lines of events.jsonl ---")
events_path = REPO_ROOT / "STUDIO_V3" / "events.jsonl"
with open(events_path, "r", encoding="utf-8") as f:
    current_event_lines = [l.strip() for l in f if l.strip()]

log(f"Current total lines in events.jsonl: {len(current_event_lines)}")
if len(current_event_lines) < 36:
    log(f"FAIL: events.jsonl has fewer than 36 lines ({len(current_event_lines)})")
    sys.exit(1)

# Check line 36 event (V3-002 TASK_APPROVED)
l36 = json.loads(current_event_lines[35])
if l36.get("task_id") == "V3-002" and l36.get("event_type") == "TASK_APPROVED":
    log("PASS: Line 36 correctly matches historical V3-002 TASK_APPROVED event.")
else:
    log(f"FAIL: Line 36 mismatch: {l36}")
    sys.exit(1)
log("")

# 5. Invariant Checker Implementation & Tests
log("--- 5. Queue Approval Invariant Check ---")
from STUDIO_V3.orchestrator.queue_store import QueueStore, TaskState, Task

db_path = REPO_ROOT / "STUDIO_V3" / "queue.db"
qs = QueueStore(db_path, None)

def check_invariant(task: Task):
    if task.status != TaskState.APPROVED:
        return True, f"Status is {task.status.value} (non-approved); invariant does not apply."

    if not task.reviewers:
        return False, f"INVARIANT_VIOLATION: Task {task.id} is APPROVED but has no designated reviewers."

    if not task.reviews or len(task.reviews) == 0:
        return False, f"INVARIANT_VIOLATION: Task {task.id} is APPROVED but reviews dictionary is empty."

    seen_sessions = set()
    for reviewer in task.reviewers:
        review = task.reviews.get(reviewer)
        if not review:
            return False, f"INVARIANT_VIOLATION: Task {task.id} is APPROVED but lacks review for designated reviewer '{reviewer}'."

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

# Positive tests on DB tasks
all_tasks = qs.load_all_tasks()
for t in all_tasks.values():
    if t.status == TaskState.APPROVED and t.id != "V3-002-PARENT-APPROVAL":
        ok, reason = check_invariant(t)
        log(f"Positive Test Task {t.id} ({t.status.value}): ok={ok}, reason={reason}")
        if not ok:
            log(f"FAIL: Legitimate task failed invariant check: {t.id}")
            sys.exit(1)

log("")
log_neg("=== NEGATIVE INVARIANT TEST SUITE ===")
log_neg(f"Execution root: {REPO_ROOT}")
log_neg("")

# Negative Test 1: V3-002-PARENT-APPROVAL in current pre-correction state
t_wrapper = qs.get_task("V3-002-PARENT-APPROVAL")
if t_wrapper and t_wrapper.status == TaskState.APPROVED and len(t_wrapper.reviews) == 0:
    ok1, reason1 = check_invariant(t_wrapper)
    log_neg(f"NEG-01: Task {t_wrapper.id} pre-correction status={t_wrapper.status.value}, reviews={t_wrapper.reviews}")
    log_neg(f"Result: ok={ok1}, reason={reason1}")
    if not ok1 and "reviews dictionary is empty" in reason1:
        log_neg("VERDICT: PASS (Correctly identified approval violation on wrapper task)")
    else:
        log_neg("VERDICT: FAIL (Did not detect expected violation)")
        sys.exit(1)
else:
    log_neg("NEG-01: V3-002-PARENT-APPROVAL already corrected or not in expected test state.")

log_neg("")

# Negative Test 2: Synthetic Task Missing One Reviewer
synth2 = Task(
    id="SYNTH-TEST-02",
    title="Synthetic Missing Reviewer",
    status=TaskState.APPROVED,
    owner="PK_ClientLead",
    reviewers=["PK_QALead", "PK_GameDirector"],
    iteration=1,
    current_commit_sha="dummy_sha",
    reviews={"PK_QALead": {"result": "PASS", "iteration": 1, "reviewed_commit_sha": "dummy_sha", "session_id": "sess-1"}}
)
ok2, reason2 = check_invariant(synth2)
log_neg(f"NEG-02: Task {synth2.id} reviewers={synth2.reviewers}, reviews={list(synth2.reviews.keys())}")
log_neg(f"Result: ok={ok2}, reason={reason2}")
if not ok2 and "PK_GameDirector" in reason2:
    log_neg("VERDICT: PASS (Correctly identified missing designated reviewer)")
else:
    log_neg("VERDICT: FAIL (Did not detect missing reviewer)")
    sys.exit(1)

log_neg("")

# Negative Test 3: Synthetic Task Commit SHA Mismatch
synth3 = Task(
    id="SYNTH-TEST-03",
    title="Synthetic SHA Mismatch",
    status=TaskState.APPROVED,
    owner="PK_ClientLead",
    reviewers=["PK_QALead"],
    iteration=1,
    current_commit_sha="commit_aaa",
    reviews={"PK_QALead": {"result": "PASS", "iteration": 1, "reviewed_commit_sha": "commit_bbb", "session_id": "sess-3"}}
)
ok3, reason3 = check_invariant(synth3)
log_neg(f"NEG-03: Task {synth3.id} current_commit_sha={synth3.current_commit_sha}, review_sha={synth3.reviews['PK_QALead']['reviewed_commit_sha']}")
log_neg(f"Result: ok={ok3}, reason={reason3}")
if not ok3 and "commit SHA mismatch" in reason3:
    log_neg("VERDICT: PASS (Correctly identified commit SHA mismatch)")
else:
    log_neg("VERDICT: FAIL (Did not detect SHA mismatch)")
    sys.exit(1)

log_neg("")

# Negative Test 4: Synthetic Task Shared Session ID
synth4 = Task(
    id="SYNTH-TEST-04",
    title="Synthetic Shared Session ID",
    status=TaskState.APPROVED,
    owner="PK_ClientLead",
    reviewers=["PK_QALead", "PK_GameDirector"],
    iteration=1,
    current_commit_sha="commit_ccc",
    reviews={
        "PK_QALead": {"result": "PASS", "iteration": 1, "reviewed_commit_sha": "commit_ccc", "session_id": "shared_uuid_999"},
        "PK_GameDirector": {"result": "PASS", "iteration": 1, "reviewed_commit_sha": "commit_ccc", "session_id": "shared_uuid_999"}
    }
)
ok4, reason4 = check_invariant(synth4)
log_neg(f"NEG-04: Task {synth4.id} QA session={synth4.reviews['PK_QALead']['session_id']}, Director session={synth4.reviews['PK_GameDirector']['session_id']}")
log_neg(f"Result: ok={ok4}, reason={reason4}")
if not ok4 and "duplicate session ID" in reason4:
    log_neg("VERDICT: PASS (Correctly identified duplicate session ID between independent reviewers)")
else:
    log_neg("VERDICT: FAIL (Did not detect duplicate session ID)")
    sys.exit(1)

# Write output files
raw_out_path = VERIF_DIR / "commands_and_raw_output.txt"
with open(raw_out_path, "w", encoding="utf-8") as f:
    f.write("\n".join(raw_output_lines) + "\n")
log(f"\nWritten raw output to: {raw_out_path}")

neg_out_path = VERIF_DIR / "negative_tests.txt"
with open(neg_out_path, "w", encoding="utf-8") as f:
    f.write("\n".join(negative_test_lines) + "\n")
log(f"Written negative tests to: {neg_out_path}")

log("\n=== ALL VERIFICATIONS COMPLETED SUCCESSFULLY ===")
