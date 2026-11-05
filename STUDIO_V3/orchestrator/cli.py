"""Command line interface for Studio V3 Orchestrator (V3-002-R1)."""
from __future__ import annotations
import argparse
import sys
import uuid
from pathlib import Path

from .schemas import ReviewVerdict, Issue, Severity
from .queue_store import QueueStore
from .event_log import EventLog
from .dispatcher import TaskDispatcher
from .adapters.antigravity_cli import AntigravityCLIAdapter
from .policies import PolicyViolation


def main():
    if sys.platform == "win32":
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass

    repo_root = Path(__file__).resolve().parent.parent.parent
    studio_dir = repo_root / "STUDIO_V3"
    db_path = studio_dir / "queue.db"
    json_path = studio_dir / "queue.json"
    log_path = studio_dir / "events.jsonl"

    store = QueueStore(db_path, json_path)
    event_log = EventLog(log_path)
    dispatcher = TaskDispatcher(store, event_log, repo_root)

    parser = argparse.ArgumentParser(description="Studio V3 Multi-Agent Orchestrator CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # show
    subparsers.add_parser("show", help="Show all tasks, iterations, and statuses")

    # issues
    p_issues = subparsers.add_parser("issues", help="List open issues")
    p_issues.add_argument("--task", default=None, help="Filter by task ID")

    # probe
    subparsers.add_parser("probe", help="Probe Antigravity CLI and AgentAPI capabilities")

    # start
    p_start = subparsers.add_parser("start", help="Start a task (owner only)")
    p_start.add_argument("task_id", help="Task ID")
    p_start.add_argument("--actor", required=True, help="Actor name")

    # submit
    p_sub = subparsers.add_parser("submit", help="Submit work deliverables")
    p_sub.add_argument("task_id", help="Task ID")
    p_sub.add_argument("--actor", required=True, help="Actor name")
    p_sub.add_argument("--evidence", nargs="+", required=True, help="Evidence file paths")
    p_sub.add_argument("--invocation-id", default="", help="Worker invocation ID")

    # review
    p_rev = subparsers.add_parser("review", help="Review work deliverables")
    p_rev.add_argument("task_id", help="Task ID")
    p_rev.add_argument("--actor", required=True, help="Reviewer role name")
    p_rev.add_argument("--result", choices=["PASS", "FIX_REQUIRED"], required=True, help="Review verdict")
    p_rev.add_argument("--evidence", nargs="+", required=True, help="Review evidence paths")
    p_rev.add_argument("--session-id", default=None, help="Authenticated session ID of reviewer")
    p_rev.add_argument("--invocation-id", default=None, help="Invocation ID of reviewer")
    p_rev.add_argument("--notes", default="", help="Review notes")
    p_rev.add_argument("--issue-id", default=None, help="Issue ID if FIX_REQUIRED")
    p_rev.add_argument("--issue-title", default=None, help="Issue title if FIX_REQUIRED")
    p_rev.add_argument("--severity", choices=["P0", "P1", "P2", "P3"], default="P1", help="Issue severity")

    # restore
    p_res = subparsers.add_parser("restore", help="Restore database from snapshot")
    p_res.add_argument("--snapshot", required=True, help="Snapshot JSON file path")

    # reconcile
    subparsers.add_parser("reconcile", help="Non-destructively reconcile local queue.db with queue.json snapshot")

    # run-loop
    p_loop = subparsers.add_parser("run-loop", help="Execute autonomous quality loop on a task")
    p_loop.add_argument("task_id", help="Task ID to run")
    p_loop.add_argument("--adapter", choices=["mock", "antigravity", "bridge"], default="mock", help="Adapter type")
    p_loop.add_argument("--max-cycles", type=int, default=3, help="Max rework cycles")

    args = parser.parse_args()

    try:
        if args.command == "show":
            tasks = store.load_all_tasks()
            print("=" * 60)
            print("STUDIO V3 QUEUE STATUS")
            print("=" * 60)
            for t in tasks.values():
                print(f"[{t.status.value:<12}] {t.id}: {t.title}")
                print(f"               Owner: {t.owner} | Iteration: {t.iteration} | Version: {t.version}")
                print(f"               Reviewers: {', '.join(t.reviewers)}")
                if t.reviews:
                    revs = [f"{k}={v.get('result')}" for k, v in t.reviews.items()]
                    print(f"               Reviews: {', '.join(revs)}")
                if t.blocked_by:
                    print(f"               Blocked by: {', '.join(t.blocked_by)}")
                if t.issues:
                    open_issues = [i for i in t.issues if i.status == "OPEN"]
                    if open_issues:
                        print(f"               Open Issues: {[i.id for i in open_issues]}")
            print("=" * 60)
            print(f"Agent dispatch: {store.get_meta('agent_dispatch', 'NOT_CONNECTED')}")

        elif args.command == "issues":
            issues = store.get_open_issues(args.task)
            if not issues:
                print("No open issues found.")
            else:
                for i in issues:
                    print(f"[{i.severity.value}] {i.id} (Task {i.task_id}, Iteration {i.iteration}): {i.title}")
                    print(f"     Steps: {i.reproduction_steps}")
                    print(f"     Expected: {i.expected} | Actual: {i.actual}")

        elif args.command == "probe":
            adapter = AntigravityCLIAdapter()
            info = adapter.probe()
            print("ANTIGRAVITY CAPABILITY PROBE RESULT:")
            for k, v in info.items():
                print(f"  {k}: {v}")

        elif args.command == "start":
            task = dispatcher.start_task(args.task_id, actor=args.actor)
            print(f"Task {task.id} -> {task.status.value} (Iteration {task.iteration})")

        elif args.command == "submit":
            task = dispatcher.submit_work(
                args.task_id,
                actor=args.actor,
                evidence_paths=args.evidence,
                invocation_id=args.invocation_id,
            )
            print(f"Task {task.id} -> {task.status.value}")

        elif args.command == "review":
            t = store.get_task(args.task_id)
            if not t:
                raise ValueError(f"Task {args.task_id} not found.")

            session_id = args.session_id or f"operator-sess-{uuid.uuid4().hex[:8]}"
            invocation_id = args.invocation_id or f"operator-inv-{uuid.uuid4().hex[:8]}"

            issues = []
            if args.result == "FIX_REQUIRED" and args.issue_id and args.issue_title:
                issues.append(Issue(
                    id=args.issue_id,
                    task_id=args.task_id,
                    iteration=t.iteration,
                    severity=Severity(args.severity),
                    title=args.issue_title,
                    reproduction_steps="See review evidence",
                    expected="Compliant deliverable",
                    actual="Defect reported in review",
                    evidence=args.evidence,
                ))

            verdict = ReviewVerdict(
                task_id=t.id,
                iteration=t.iteration,
                agent_role=args.actor,
                provider="OPERATOR_CLI",
                invocation_id=invocation_id,
                session_id=session_id,
                reviewed_commit_sha=t.current_commit_sha,
                result=args.result,
                evidence_paths=args.evidence,
                issues=issues,
                notes=args.notes,
            )
            task = dispatcher.review_task(args.task_id, verdict=verdict)
            print(f"Task {task.id} -> {task.status.value}")

        elif args.command == "restore":
            store.import_snapshot(Path(args.snapshot))
            print(f"Queue restored successfully from {args.snapshot}")

        elif args.command == "reconcile":
            res = store.reconcile_snapshot(json_path)
            print(f"Queue reconciled with snapshot: {res}")

        elif args.command == "run-loop":
            import json
            if args.adapter == "mock":
                from .adapters.mock import MockAdapter
                adapter = MockAdapter(repo_root)
            elif args.adapter == "bridge":
                from .adapters.subagent_bridge import AntigravitySubagentBridgeAdapter
                adapter = AntigravitySubagentBridgeAdapter(repo_root)
            else:
                from .adapters.antigravity_cli import AntigravityCLIAdapter
                adapter = AntigravityCLIAdapter()

            res = dispatcher.execute_autonomous_loop(
                task_id=args.task_id,
                adapter=adapter,
                max_cycles=args.max_cycles,
            )
            print(json.dumps(res, indent=2))

    except (PolicyViolation, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
