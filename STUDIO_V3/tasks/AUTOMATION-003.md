# AUTOMATION-003 — GitHub Task Inbox → Local Antigravity Runner (Safe Public-Repo Path)

**Repository:** `jjangmut/ProjectKnight` (verified **PUBLIC** on 2026-11-10)
**Existing automation branch:** `studio/v3-automation-system`
**Main development workspace:** `D:\JUNYPAPA_STUDIO\Projects\ProjectKnight`
**Isolated automation worktree:** `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\worktree`
**Local runner:** `D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\runner.ps1`

## Critical discovery & change of plan
GitHub API confirms `private: false`, `visibility: public`, and repository **default branch** `task/art-stage-batch-001` (not `main`). GitHub Actions `workflow_dispatch` needs the workflow on **the actual default branch**. Existing workflow appears only on non-default automation/test branches. **DO NOT register a persistent self-hosted GitHub Actions runner on this user's personal workstation for a public repository**, and do not copy the existing privileged `runs-on: [self-hosted, windows]` workflow into the default branch. GitHub's security docs explicitly warn of persistent compromise risk for self-hosted runners on public repos. Do not change repository visibility unilaterally.

## Objective
Build a small, local **pull-based** inbox checker in the user's existing Windows automation folder. It should fetch only authoritative task specs authored on approved GitHub branches (GitHub API/remote refs), validate them, queue them for **local user approval**, and then invoke existing isolated `runner.ps1 -Action Execute -TaskId ...`. This enables user to submit new work from ChatGPT/GitHub without copy-pasting into Antigravity; there is **no requirement to expose the workstation to GitHub Actions**.

## Work items
1. Inspect **actual** existing `runner.ps1`, `config.json`, `security_settings.json`, `tasks_state.json`; preserve tested functionality and distinguish reported safeguards from tested ones. Don't assume `command(*)` deny rules are OS sandboxing: arbitrary Python/Git/tool commands can bypass naive string matching.
2. Implement `inbox.ps1` with `-Action Scan`, `-Action Watch`, `-Action Approve -TaskId`, `-Action Status`, and `-Action Stop`, or a simpler equivalent. Scan/poll remote GitHub task branch refs at modest interval (>= 60 sec); fetch remote, verify branch pattern `studio/v3-.../test/v3-...`, task metadata and expected SHA against actual GitHub, and prevent duplicate runs. **Never auto-trust a task purely because its name matches**. Pin task commit SHA at approval and recheck before execution; fail closed if changed. Do not auto-execute all public repository pushes.
3. **Default execution policy: approved task only.** Explicit local approval should record exact task ID + branch + commit SHA; automatic dispatch is allowed *after* this local approval. Do not default to `AutoApprove = true`, bypass CLI safeguards, create a long-lived network listener, or open inbound firewall ports.
4. Preserve one-task-at-a-time lock, isolated worktree, existing V3-017 work, and prior completed state. Hard-deny `main/master/integration/task/art-stage-batch-001`, unauthorized paths, workflow/credential changes, and untracked executable files for normal game tasks. Validate all changed files before staging, and compare scope to actual task requirements. No automatic force push, no automatic merge, no broad `git add -A` without whitelist check, no interpreter string-evaluation of GitHub task text.
5. Make Windows Scheduler **optional**: provide exact user-reviewed commands for a non-admin, least-privilege scheduled scanner running on login. Do not silently register services/tasks or install the GitHub Self-Hosted Runner. Explicitly avoid requiring admin or storing auth tokens in repository.
6. Safe end-to-end test: create or reuse dedicated `test/v3-...` branch with harmless task that writes one result JSON under `STUDIO_V3/evidence/<TEST_ID>/` and proves Scan → approval → CLI invocation → allowed commit → push → state DONE → duplicate prevention. Verify main dev folder unchanged. Use actual GitHub commit links. If security gate cannot enforce a boundary, label as open risk and stop; no self-certified security guarantees.
7. User-facing README: copy/paste commands for starting local polling, approving a newly detected `V3-018`, checking status/logs, and stopping. Explain that **ChatGPT doesn't automatically receive results / initiate next steps** unless a separate explicit monitoring workflow is configured.
8. Commit only safe documentation/source changes to `studio/v3-automation-system` (do not merge to default branch by default). Keep local credential/config secrets off GitHub. Clearly report what is only local and what is verifiable on GitHub.

## Acceptance
- Polling and exact-SHA local approval are tested with real harmless task; existing V3-017 is untouched.
- No Self-Hosted Runner installed; no public-repo GitHub Actions runner jobs.
- If user later migrates to a private repository + isolated runner machine, a separate approval and threat-model exercise is required.

**Priority:** safe minimal bridge that actually starts Antigravity on local approval, not further speculative infrastructure.
