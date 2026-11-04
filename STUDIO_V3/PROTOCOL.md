# Production Protocol v3

## Status transitions
READY -> IN_PROGRESS (assigned owner)
IN_PROGRESS -> IN_REVIEW (owner submits checked-in evidence)
IN_REVIEW -> FIX_REQUIRED (reviewer rejection)
FIX_REQUIRED -> IN_PROGRESS (owner retries)
IN_REVIEW -> APPROVED (both designated independent reviewers PASS)

BLOCKED requires written rationale. A run that reaches time/budget limits remains FIX_REQUIRED, not APPROVED.
Never award APPROVED without actual independent evidence.

## Evidence gates
Technical: exact source revision, executed commands, raw logs, test result, reproducible steps.
Visual: same camera/viewport before and after, real rendered screenshots or gameplay video, subjective notes tied to images.
Play: input-driven real game interactions; fixtures and assertions only count as functional tests.
Performance: windowed measurements, hardware, graphics backend, resolution, VSync state, per-sector distributions. Android only on actual device.

## Issue requirements
Each issue has owner, severity (P0/P1/P2/P3), reproduction, expected/actual, evidence, and retest.
P0/P1 unresolved => no milestone approval. Subjective numeric score is not a substitute for visual inspection.

## Agent independence
Owner and reviewer must be different. When a reviewer implemented the change, reassign review.
Agent prompts alone do not establish runtime autonomy. External dispatcher must explicitly record invocation and outputs.

## Safety
No force-push, destructive merges, game asset deletion, save reset, balance change or feature rewrite without scoped approval.
Maintain a dedicated branch/worktree. Source control is the recovery mechanism for retired operating files.
