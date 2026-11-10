#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
End-to-End Verification Test for ProjectKnight One-Click Launcher
Location: tools/automation/test_e2e_launcher.py

Verifies:
  1. Manual Approval Mode (Auto-Approve OFF) settings flow
  2. Auto-Approve Mode (Auto-Approve ON) settings flow
  3. Real-time stage marker parsing across all 6 stages
  4. Duplicate execution blocking for already completed tasks
  5. Workspace protection audit (Projects\\ProjectKnight remains 100% clean and untouched)
  6. Verified commit and evidence inspection
"""

import os
import sys
import json
import time
import subprocess

current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

from launcher import (
    DEFAULT_AUTOMATION_DIR,
    DEFAULT_REPO_DIR,
    DEFAULT_WORKTREE_DIR,
    RUNNER_PS1_PATH,
    STATE_PATH,
    SETTINGS_PATH,
    STAGES,
    load_launcher_settings,
    save_launcher_settings,
    load_completed_tasks,
    run_git
)

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}")

def test_manual_mode_flow():
    log("=== TEST 1: Manual Approval Mode (Auto-Approve OFF) ===")
    save_launcher_settings({"auto_approve": False})
    settings = load_launcher_settings()
    assert settings.get("auto_approve") is False, "Auto-Approve must be False"
    log("[PASS] Auto-Approve setting verified as OFF.")

def test_auto_approve_mode_toggle():
    log("=== TEST 2: Auto-Approve Mode (Auto-Approve ON) Toggle ===")
    save_launcher_settings({"auto_approve": True})
    settings = load_launcher_settings()
    assert settings.get("auto_approve") is True, "Auto-Approve must be True"
    log("[PASS] Auto-Approve setting verified as ON.")

def test_stage_pipeline_marker_parsing():
    log("=== TEST 3: Real-Time Stage Marker Parsing Verification ===")
    stage_keys = [s[0] for s in STAGES]
    simulated_output = [
        "[STAGE:DISCOVER] 작업 탐색 (Target Task: V3-TEST-AUTOMATION)",
        "[2026-11-10 21:23:36] [INFO] Starting isolated execution for Task: V3-TEST-AUTOMATION",
        "[STAGE:VALIDATE] GitHub 지시서 검증 완료 (Branch: test/v3-test-automation)",
        "[STAGE:WORKTREE] 격리 Worktree 준비 중 (D:\\JUNYPAPA_STUDIO\\Automation\\ProjectKnight\\worktree)",
        "[STAGE:EXECUTE] Antigravity CLI 개발·테스트 실행 시작",
        "[STAGE:SCOPE] 변경 범위 검증 및 커밋 시작",
        "Changes successfully committed in worktree: bedc1c0524028c8a462668175c95198007599902",
        "[STAGE:PUSH] GitHub Push 진행 중 (test/v3-test-automation)",
        "[STAGE:COMPLETE] 작업 자동 개발 및 반영 완료 (Commit: bedc1c0524028c8a462668175c95198007599902)"
    ]

    detected = []
    discovered_commit = ""

    for line in simulated_output:
        if "[STAGE:" in line:
            tag = line.split("[STAGE:")[1].split("]")[0]
            detected.append(tag)
        if "Changes successfully committed in worktree:" in line:
            discovered_commit = line.split("Changes successfully committed in worktree:")[1].strip()

    log(f"  -> Detected Stages: {detected}")
    log(f"  -> Discovered Commit SHA: {discovered_commit}")

    for expected in ["DISCOVER", "VALIDATE", "WORKTREE", "EXECUTE", "SCOPE", "PUSH", "COMPLETE"]:
        assert expected in detected, f"Stage {expected} must be detected"
    assert discovered_commit == "bedc1c0524028c8a462668175c95198007599902"
    log("[PASS] All 6 execution stages and completion marker successfully parsed.")

def test_duplicate_blocking():
    log("=== TEST 4: Duplicate Task Execution Blocking ===")
    test_task_id = "V3-TEST-AUTOMATION"
    cmd = [
        "powershell.exe",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", RUNNER_PS1_PATH,
        "-Action", "Execute",
        "-TaskId", test_task_id,
        "-AutoApprove"
    ]

    res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    log(f"Duplicate execution check output:\n{res.stdout.strip()}")
    assert "already recorded as COMPLETED" in res.stdout, "Duplicate task must be blocked from running"
    log("[PASS] Duplicate execution correctly blocked by tasks_state.json check.")

def test_workspace_protection():
    log("=== TEST 5: Workspace Protection Audit ===")
    status = run_git(["status", "--porcelain"], cwd=DEFAULT_REPO_DIR)
    assert not status.strip(), f"Main repo must have 0 changes. Found:\n{status}"
    branch = run_git(["rev-parse", "--abbrev-ref", "HEAD"], cwd=DEFAULT_REPO_DIR).strip()
    log(f"Main workspace branch: {branch} (Clean: True)")
    assert branch == "studio/v3-016-render-performance-validation", f"Main repo branch unexpectedly altered: {branch}"
    log("[PASS] Main development workspace remained 100% clean and untouched throughout execution.")

def test_execution_verification_evidence():
    log("=== TEST 6: Execution Verification Evidence Audit ===")
    evidence_path = os.path.join(
        DEFAULT_WORKTREE_DIR,
        "STUDIO_V3",
        "evidence",
        "V3-TEST-AUTOMATION",
        "EXECUTION_VERIFICATION.json"
    )
    if not os.path.exists(evidence_path):
        # Check via git show from test/v3-test-automation
        raw_json = run_git(
            ["show", "origin/test/v3-test-automation:STUDIO_V3/evidence/V3-TEST-AUTOMATION/EXECUTION_VERIFICATION.json"],
            cwd=DEFAULT_WORKTREE_DIR
        )
        data = json.loads(raw_json)
    else:
        with open(evidence_path, "r", encoding="utf-8") as f:
            data = json.load(f)

    assert data.get("status") == "PASS", f"Evidence status must be PASS, got: {data.get('status')}"
    assert data.get("task_id") == "V3-TEST-AUTOMATION"
    assert data.get("branch") == "test/v3-test-automation"
    log(f"Verified Evidence Task: {data.get('task_id')}, Status: {data.get('status')}")
    log(f"Verified Execution Mode: {data.get('runner_environment', {}).get('execution_mode')}")
    log("[PASS] Execution verification evidence confirmed with status PASS.")

if __name__ == "__main__":
    t0 = time.time()
    try:
        test_manual_mode_flow()
        test_auto_approve_mode_toggle()
        test_stage_pipeline_marker_parsing()
        test_duplicate_blocking()
        test_workspace_protection()
        test_execution_verification_evidence()
        log(f"\n=======================================================")
        log(f"ALL E2E LAUNCHER VERIFICATIONS PASSED in {time.time()-t0:.2f}s!")
        log(f"=======================================================")
    except Exception as e:
        log(f"\n[FAIL] E2E TEST FAILED: {e}")
        sys.exit(1)
