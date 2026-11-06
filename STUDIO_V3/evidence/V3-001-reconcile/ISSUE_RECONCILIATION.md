# V3-001 — Issue Reconciliation & Governance Addendum

**Task ID:** `V3-001-EVIDENCE-RECONCILE`  
**Purpose:** Reconcile Issue Counting, Ledger Integrity, and Status Governance across V3-001 Audit Records  
**Canonical Backlog:** [`GAMEPLAY_ISSUE_BACKLOG.md`](GAMEPLAY_ISSUE_BACKLOG.md)  
**Historical Evidence:** [`STUDIO_V3/evidence/V3-001/ISSUES.md`](../V3-001/ISSUES.md) (Preserved 100% untouched)  
**Date:** 2026-11-07  

---

## 1. Discrepancy Analysis & Reconciled Facts

During the external independent review of `V3-001`, three key governance issues were identified regarding the defect ledger:

1. **6 vs. 7 Issue Count Discrepancy:**
   - `BASELINE.md` and `QA_REVIEW.md` reported **6 issues (2 P1, 2 P2, 2 P3)**.
   - `FINAL_EXECUTION_REPORT.md` and `DIRECTOR_REVIEW.md` reported **7 issues (3 P1, 2 P2, 2 P3)**.
   - **Chronological Root Cause:**
     During the initial audit pass, PK_ClientLead documented 6 issues (`01` through `06`). When `PK_GameDirector` performed the subsequent creative & milestone review, the Director closely inspected [`09_boss_combat.png`](../V3-001/captures/originals/09_boss_combat.png) and discovered that the foreground castle battlement and pillar severely occluded the combat plane during the boss phase ($X > 8.0$). The Director filed this as a new P1 blocker (`ISSUE-V3-001-07`). While `FINAL_EXECUTION_REPORT.md` and `DIRECTOR_REVIEW.md` incorporated this 7th defect, the previously written `QA_REVIEW.md` and `BASELINE.md` retained the initial 6-issue count.
   - **Reconciliation:** The definitive and correct total is **7 Unique Issues (3 P1, 2 P2, 2 P3)**.

2. **Deduplication of `ISSUE-V3-001-07` in `ISSUES.md`:**
   - In `STUDIO_V3/evidence/V3-001/ISSUES.md`, the Markdown summary table displayed 9 rows because `ISSUE-V3-001-07` was inadvertently pasted three times during document finalization.
   - **Reconciliation:** The duplicate rows are a cosmetic Markdown table artifact. The issue tracker defines exactly **7 unique issue IDs**. The original `ISSUES.md` is preserved as an immutable historical artifact, while [`GAMEPLAY_ISSUE_BACKLOG.md`](GAMEPLAY_ISSUE_BACKLOG.md) provides the clean, deduplicated canonical ledger.

3. **Status Correction for `ISSUE-V3-001-02`:**
   - In `ISSUES.md`, `ISSUE-V3-001-02` (2.5D Belt-Scroll vs 2D Plane) was labeled `RESOLVED (Decision: Option C)`.
   - **Correction:** Selecting Option C in [`DESIGN_DECISION.md`](../V3-001/DESIGN_DECISION.md) establishes the architectural directive, but does **NOT** resolve the gameplay defect in code. Because `CLIENT/Game/` was kept strictly read-only during `V3-001`, no code changes were made to `SideQVPlayer.gd` or enemy scripts.
   - **Reconciled Status:** Formally updated to **`DECIDED / IMPLEMENTATION_PENDING`**. This issue remains active and will only transition to `RESOLVED` after implementation and gameplay verification in downstream task `V3-003`.

---

## 2. Reconciled Canonical Issue Summary

| Issue ID | Severity | Title | Owner | Reconciled Status |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-V3-001-01** | **P1 (MAJOR)** | Mobile Touch Joystick & Action Buttons Missing | PK_ClientLead | **OPEN** |
| **ISSUE-V3-001-02** | **P1 (MAJOR)** | Core Gameplay Motion Model Discrepancy | PK_ClientLead | **DECIDED / IMPLEMENTATION_PENDING** |
| **ISSUE-V3-001-03** | **P2 (MINOR)** | Script Error on Boot: `add_child()` Called While Node Busy | PK_ClientLead | **OPEN** |
| **ISSUE-V3-001-04** | **P2 (MINOR)** | Billboard Sprite3D Ground Contact & Elevation Offset | PK_ArtDirector | **OPEN** |
| **ISSUE-V3-001-05** | **P3 (POLISH)** | Boss Commander Shield Charge Windup Telegraph Unclear | PK_GameDesign | **OPEN** |
| **ISSUE-V3-001-06** | **P3 (POLISH)** | Stage Clear Lacks Dedicated Victory / Reward Result Screen | PK_GameDesign | **OPEN** |
| **ISSUE-V3-001-07** | **P1 (MAJOR)** | Foreground Wall / Pillar Occludes Combat Area During Boss | PK_ArtDirector / PK_ClientLead | **OPEN** |

---

## 3. Critical Governance Separation: Audit Completeness vs. Gameplay Release Readiness

A fundamental requirement of ProjectKnight Production System v3 is that **the status of an audit task must never be conflated with the quality or release readiness of the game itself**:

1. **Meaning of `V3-001` Task Approval:**
   - In `queue.json`, `V3-001.status = APPROVED` and `issues: []` record that **the audit task itself satisfied all its execution and evidence gates**:
     - Genuine Godot 4.7.2 windowed execution was achieved.
     - 11 authentic unedited captures were acquired and indexed.
     - 14,404 continuous frames of PC telemetry were profiled.
     - All 7 discovered defects were truthfully cataloged with reproducible evidence.
     - A definitive motion plane decision (Option C) was ratified by the Game Director.
   - `issues: []` in `queue.json` denotes that there were **zero blocking failures in the audit deliverables**.
2. **Meaning of Gameplay Defect Status:**
   - The game itself contains **3 open P1 blockers** (mobile touch controls missing, Z-depth gameplay discrepancy, and foreground boss camera occlusion).
   - **The game client `CLIENT/Game/` is NOT approved for release.**
   - All 7 gameplay defects are formally carried forward in [`GAMEPLAY_ISSUE_BACKLOG.md`](GAMEPLAY_ISSUE_BACKLOG.md) as the mandatory development input for `V3-003` (Stage 1 Polish & Fix).
3. **Task Dependency Gate:**
   - `V3-003` remains strictly **`BLOCKED`** until both `V3-001` evidence reconciliation and parent milestone `V3-002` receive external independent review approval.
