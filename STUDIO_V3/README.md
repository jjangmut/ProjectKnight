# Studio V3 — New Production Organization

This directory is a fresh start, NOT a continuation of Production System v2.

## Scope
Keep all existing playable game source, scene files, models, sprites and runtime tests unchanged for now.
Remove obsolete agent policies, completion claims, review archives, scheduling batches and pseudo-agent audit runners from this branch.
All prior PASS/APPROVED values reset to NOT VERIFIED.

## Operational roles
Six logical roles are defined in agents/*.md: Director, Producer, Designer, Art, Client and QA.
These are role instructions, NOT proof that Antigravity runs them as distinct isolated agents.

## Real workflow
1. Producer selects an unblocked task from queue.json.
2. Assigned worker reads its prompt and performs a scoped change.
3. Worker submits real committed artifacts, screenshots, measurements or test logs.
4. Independent reviewers verify evidence; rework on failure.
5. Director and QA both pass before milestone approval.

## Run
python STUDIO_V3/workflow.py show
python STUDIO_V3/workflow.py start V3-001 --actor PK_ClientLead
python STUDIO_V3/workflow.py submit V3-001 --actor PK_ClientLead --evidence STUDIO_V3/evidence/V3-001/baseline.md
python STUDIO_V3/workflow.py review V3-001 --actor PK_QALead --result FIX_REQUIRED --evidence STUDIO_V3/evidence/V3-001/review.md

The local workflow is a state machine; it does not invoke an LLM or schedule work.
No generic PASS may be inferred from existence of files, old scores, or headless-only tests.
