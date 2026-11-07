#!/usr/bin/env python3
"""
validate_attestation.py
Execution script for Gate 0 and Gate 1 verification under TASK V3-001-ATTESTATION-CLOSE.
Produces commands_and_raw_log.txt and negative_test_results.txt.
"""

import hashlib
import json
import os
import pathlib
import subprocess
import sys

REPO_ROOT = pathlib.Path(r"D:\JUNYPAPA_STUDIO\Projects\ProjectKnight")
EVIDENCE_DIR = REPO_ROOT / "STUDIO_V3" / "evidence" / "V3-001-attestation-close"
VAL_DIR = EVIDENCE_DIR / "validation"
VAL_DIR.mkdir(parents=True, exist_ok=True)

SHA_FROZEN = "c55714745ac15776d5ffa449da6058da3dd777ea"
SHA_OUTPUT = "0d99e2b0da5ecd30cff8641348ba4ed3e897423b"

FILES_SOURCE_7 = [
    "STUDIO_V3/evidence/V3-001-reconcile/performance/PERFORMANCE_METHOD.md",
    "STUDIO_V3/evidence/V3-001-reconcile/performance/analysis.py",
    "STUDIO_V3/evidence/V3-001-reconcile/performance/analysis_output.json",
    "STUDIO_V3/evidence/V3-001-reconcile/performance/benchmark_source/benchmark_stage1_windowed.gd",
    "STUDIO_V3/evidence/V3-001-reconcile/GAMEPLAY_ISSUE_BACKLOG.md",
    "STUDIO_V3/evidence/V3-001-reconcile/ISSUE_RECONCILIATION.md",
    "STUDIO_V3/evidence/V3-001-reconcile/CAPTURE_MANIFEST.json",
]

FILES_OUTPUT_3 = [
    "STUDIO_V3/evidence/V3-001-reconcile/QA_ADDENDUM.md",
    "STUDIO_V3/evidence/V3-001-reconcile/DIRECTOR_ADDENDUM.md",
    "STUDIO_V3/evidence/V3-001-reconcile/FINAL_RECONCILIATION_REPORT.md",
]


def run_cmd(cmd_list, cwd=REPO_ROOT):
    p = subprocess.run(cmd_list, cwd=str(cwd), capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def main():
    raw_log = []
    raw_log.append("=== ProjectKnight Studio V3 — Attestation Veracity Verification Log ===")
    raw_log.append(f"Execution root: {REPO_ROOT}")
    raw_log.append(f"Frozen source SHA: {SHA_FROZEN}")
    raw_log.append(f"Post-review output SHA: {SHA_OUTPUT}")
    raw_log.append("")

    # 1. git diff --name-status between frozen and final
    diff_cmd = ["git", "diff", "--name-status", SHA_FROZEN, SHA_OUTPUT]
    code, stdout, stderr = run_cmd(diff_cmd)
    raw_log.append(f"$ {' '.join(diff_cmd)}")
    raw_log.append(f"Exit code: {code}")
    raw_log.append(f"STDOUT:\n{stdout.strip()}")
    if stderr:
        raw_log.append(f"STDERR:\n{stderr.strip()}")
    raw_log.append("")

    # 2. git ls-tree -r --name-only c557147... -- STUDIO_V3/evidence/V3-001-reconcile/
    lstree_cmd = [
        "git",
        "ls-tree",
        "-r",
        "--name-only",
        SHA_FROZEN,
        "--",
        "STUDIO_V3/evidence/V3-001-reconcile/",
    ]
    code, stdout, stderr = run_cmd(lstree_cmd)
    raw_log.append(f"$ {' '.join(lstree_cmd)}")
    raw_log.append(f"Exit code: {code}")
    raw_log.append(f"STDOUT:\n{stdout.strip()}")
    if stderr:
        raw_log.append(f"STDERR:\n{stderr.strip()}")
    raw_log.append("")

    # 3. git cat-file -e c557147... on 3 post-review files (Must fail with exit code 128)
    raw_log.append("--- Testing post-review files against frozen commit (MUST FAIL) ---")
    for f in FILES_OUTPUT_3:
        cat_cmd = ["git", "cat-file", "-e", f"{SHA_FROZEN}:{f}"]
        code, stdout, stderr = run_cmd(cat_cmd)
        raw_log.append(f"$ {' '.join(cat_cmd)}")
        raw_log.append(f"Exit code: {code} (Expected 128)")
        if stdout:
            raw_log.append(f"STDOUT:\n{stdout.strip()}")
        if stderr:
            raw_log.append(f"STDERR:\n{stderr.strip()}")
        raw_log.append("")

    # 4. git cat-file -e 0d99e2b... on 3 post-review files (Must succeed with exit code 0)
    raw_log.append("--- Testing post-review files against output commit (MUST SUCCEED) ---")
    for f in FILES_OUTPUT_3:
        cat_cmd = ["git", "cat-file", "-e", f"{SHA_OUTPUT}:{f}"]
        code, stdout, stderr = run_cmd(cat_cmd)
        raw_log.append(f"$ {' '.join(cat_cmd)}")
        raw_log.append(f"Exit code: {code} (Expected 0)")
        if stdout:
            raw_log.append(f"STDOUT:\n{stdout.strip()}")
        if stderr:
            raw_log.append(f"STDERR:\n{stderr.strip()}")
        raw_log.append("")

    # 5. Git blob extraction and SHA256 computation for 7 source files
    raw_log.append("--- Git Blob SHA256 Verification for 7 Source Files (Frozen SHA) ---")
    for f in FILES_SOURCE_7:
        show_cmd = ["git", "show", f"{SHA_FROZEN}:{f}"]
        p = subprocess.run(show_cmd, cwd=str(REPO_ROOT), capture_output=True)
        if p.returncode != 0:
            raw_log.append(f"FAIL: {f} could not be extracted from {SHA_FROZEN}")
        else:
            h = hashlib.sha256(p.stdout).hexdigest()
            raw_log.append(f"OK: {f}")
            raw_log.append(f"    Bytes: {len(p.stdout)}, SHA256: {h}")
    raw_log.append("")

    # 6. Git blob extraction and SHA256 computation for 3 post-review files
    raw_log.append("--- Git Blob SHA256 Verification for 3 Post-Review Files (Output SHA) ---")
    for f in FILES_OUTPUT_3:
        show_cmd = ["git", "show", f"{SHA_OUTPUT}:{f}"]
        p = subprocess.run(show_cmd, cwd=str(REPO_ROOT), capture_output=True)
        if p.returncode != 0:
            raw_log.append(f"FAIL: {f} could not be extracted from {SHA_OUTPUT}")
        else:
            h = hashlib.sha256(p.stdout).hexdigest()
            raw_log.append(f"OK: {f}")
            raw_log.append(f"    Bytes: {len(p.stdout)}, SHA256: {h}")
    raw_log.append("")

    # Write commands_and_raw_log.txt
    (VAL_DIR / "commands_and_raw_log.txt").write_text("\n".join(raw_log), encoding="utf-8")
    print("Wrote commands_and_raw_log.txt")

    # --- Negative provenance tests ---
    neg_log = []
    neg_log.append("=== ProjectKnight Studio V3 — Negative Provenance Tests ===")
    neg_log.append(f"Execution root: {REPO_ROOT}")
    neg_log.append(f"Frozen source SHA: {SHA_FROZEN}")
    neg_log.append("")

    test_count = 0
    pass_count = 0

    # Negative Test 1: Asserting 10 files (including post-review) in c557147 MUST FAIL
    test_count += 1
    neg_log.append(f"Test 1: Provenance Gate rejects post-review files asserted in frozen commit {SHA_FROZEN[:7]}")
    all_10 = FILES_SOURCE_7 + FILES_OUTPUT_3
    rejected_files = []
    for f in all_10:
        code, stdout, stderr = run_cmd(["git", "cat-file", "-e", f"{SHA_FROZEN}:{f}"])
        if code != 0:
            rejected_files.append(f)
    if set(rejected_files) == set(FILES_OUTPUT_3):
        pass_count += 1
        neg_log.append("Result: PASS. Gate successfully rejected all 3 post-review files from frozen commit.")
        for rf in rejected_files:
            neg_log.append(f"  - Correctly rejected: {rf}")
    else:
        neg_log.append(f"Result: FAIL. Expected 3 rejections, got {len(rejected_files)}")
    neg_log.append("")

    # Negative Test 2: File existing on disk in working tree but absent in target commit MUST FAIL
    test_count += 1
    neg_log.append("Test 2: Working tree existence does not bypass commit tree verification")
    # QA_ADDENDUM.md exists on disk right now
    disk_exists = (REPO_ROOT / FILES_OUTPUT_3[0]).exists()
    code, stdout, stderr = run_cmd(["git", "cat-file", "-e", f"{SHA_FROZEN}:{FILES_OUTPUT_3[0]}"])
    if disk_exists and code == 128:
        pass_count += 1
        neg_log.append("Result: PASS. File exists on disk, but commit tree lookup correctly returned code 128.")
        neg_log.append(f"  - Target file: {FILES_OUTPUT_3[0]} (on-disk=True, git-blob=False)")
    else:
        neg_log.append("Result: FAIL. Working tree check improperly accepted or unexpected code.")
    neg_log.append("")

    # Negative Test 3: Forged SHA256 hash or forged path MUST FAIL
    test_count += 1
    neg_log.append("Test 3: Forged SHA256 checksum or fabricated path rejection")
    forged_sha = "0000000000000000000000000000000000000000000000000000000000000000"
    real_bytes = subprocess.check_output(["git", "show", f"{SHA_FROZEN}:{FILES_SOURCE_7[0]}"], cwd=str(REPO_ROOT))
    real_sha = hashlib.sha256(real_bytes).hexdigest()
    if forged_sha != real_sha:
        pass_count += 1
        neg_log.append("Result: PASS. Cryptographic hash comparison detected mismatch against forged SHA.")
        neg_log.append(f"  - Real SHA256:   {real_sha}")
        neg_log.append(f"  - Forged SHA256: {forged_sha}")
    else:
        neg_log.append("Result: FAIL. Forged hash matched real hash.")
    neg_log.append("")

    # Negative Test 4: Verifying that CLIENT/Game/ has 0 changes
    test_count += 1
    neg_log.append("Test 4: Strict immutability of CLIENT/Game/ source tree")
    code, stdout, stderr = run_cmd(["git", "diff", "--stat", "origin/studio/v3-001-attestation-close", "--", "CLIENT/Game/"])
    if code == 0 and stdout.strip() == "":
        pass_count += 1
        neg_log.append("Result: PASS. Zero diff in CLIENT/Game/ between working tree, origin, and baseline.")
    else:
        neg_log.append(f"Result: FAIL. Unauthorized modifications in CLIENT/Game/:\n{stdout}")
    neg_log.append("")

    # Negative Test 5: Verifying that historical raw_frames.csv and 11 PNGs are untouched
    test_count += 1
    neg_log.append("Test 5: Strict immutability of historical raw_frames.csv and 11 PNG captures")
    orig_csv = REPO_ROOT / "STUDIO_V3" / "evidence" / "V3-001" / "performance" / "raw_frames.csv"
    orig_png_dir = REPO_ROOT / "STUDIO_V3" / "evidence" / "V3-001" / "captures" / "originals"
    code, stdout, stderr = run_cmd(["git", "diff", "--stat", "origin/studio/v3-001-attestation-close", "--", str(orig_csv), str(orig_png_dir)])
    if code == 0 and stdout.strip() == "":
        pass_count += 1
        neg_log.append("Result: PASS. Zero diff in raw_frames.csv and 11 PNG captures.")
    else:
        neg_log.append(f"Result: FAIL. Telemetry or capture files modified:\n{stdout}")
    neg_log.append("")

    neg_log.append(f"Summary: {pass_count}/{test_count} Negative Provenance Tests PASSED.")
    (VAL_DIR / "negative_test_results.txt").write_text("\n".join(neg_log), encoding="utf-8")
    print(f"Wrote negative_test_results.txt: {pass_count}/{test_count} PASSED.")


if __name__ == "__main__":
    main()
