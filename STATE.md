# ProjectKnight Studio V3 — V3-002 Parent Approval Preparation

Updated: 2026-11-07
Current task branch: `studio/v3-002-parent-approval`
Task specification: `STUDIO_V3/tasks/V3-002-PARENT-APPROVAL.md`
Instruction branch base: `8172175c9434dbc2765400e2c38ec2b84e035b2b`

## Accepted underlying evidence (not a parent milestone auto-approval)
- `V3-001` baseline **audit evidence**: external review ACCEPTED, as verified by `STUDIO_V3/reviews/V3-001-ATTESTATION-CLOSE-INDEPENDENT-REVIEW.md`; the game itself remains NOT_APPROVED for release with 3 open P1 defects.
- `V3-002-CLOSE` infrastructure closure child: internal APPROVED, external independent code/evidence review ACCEPTED. Frozen implementation source SHA `214000678186b6ebb42349eeb28336b4dcfe0e42`, with Python 57/57 and isolated Godot stamina fixture 74/74 PASS logs on GitHub.
- Antigravity IDE-native Worker → QA rejection → Worker revision → QA retest → Director acceptance chain is historically recorded; **standalone Python headless native agent launching is NOT independently established**.
- `V3-001-ATTESTATION-CLOSE` internal APPROVED and external review accepted after Git source/output evidence SHA lineage independently verified. No more baseline re-audit cycles required.

## Next action now READY
- **V3-002-PARENT-APPROVAL: READY**. Only formal parent acceptance matrix, frozen approval packet, actual native QA+Director parent review, correct SQLite/dispatcher state transition and follow-up external verification. This task has NOT run.
- `V3-002` parent **FIX_REQUIRED**, owner PK_Producer, official review evidence not yet submitted; no manual or automatic status promotion based on child acceptance.
- `V3-003` **BLOCKED** until V3-001 evidence acceptance and V3-002 parent formal acceptance/gate review are both complete. Game code changes are out of scope now.

## Source SHA vs review packet SHA: never conflate
- Underlying infrastructure code: `214000678186b6ebb42349eeb28336b4dcfe0e42`.
- Parent review packet: new `PARENT_REVIEWED_SHA` only after source evidence matrix and logs have been committed, not yet created.
- Reviewer outputs: future separate `PARENT_REVIEW_OUTPUT_SHA` after QA/Director completion. These do not exist inside the frozen parent review commit.

## Game defects held for V3-003
1. ISSUE-V3-001-02 P1: implement Option C Z=0 gameplay plane, while preserving 2.5D rendered setting.
2. ISSUE-V3-001-01 P1: mobile left/right, jump, attack, guard/parry, dash UI.
3. ISSUE-V3-001-07 P1: eliminate boss fight foreground wall/pillar occlusion.
4. Two P2 and two P3 remain in the canonical `STUDIO_V3/evidence/V3-001-reconcile/GAMEPLAY_ISSUE_BACKLOG.md`.
These are **gameplay release blockers**, not reasons to retroactively fail a valid audit-only baseline.

## Safety
Do not modify `CLIENT/Game/`, main/integration, original screenshot PNGs or raw performance CSV. No R4 redesign. Parent QA/Director must be real separate sessions with verified identity and frozen packet SHA. No self-approval, no destructive history rewrite, no speculative performance or CLI capability claims.
