"""Command line interface for Studio V3 Orchestrator."""
from __future__ import annotations
import argparse
import sys
from pathlib import Path

from .schemas import ReviewVerdict, Issue, Severity
from .queue_store import QueueStore
from .event_log import EventLog
from .dispatcher import TaskDispatcher
from .adapters.antigravity_cli import AntigravityCLIAdapter
from .policies import PolicyViolation


def main():
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

    # review
    p_rev = subparsers.add_parser("review", help="Review work deliverables")
    p_rev.add_argument("task_id", help="Task ID")
    p_rev.add_argument("--actor", required=True, help="Reviewer name")
    p_rev.add_argument("--result", choices=["PASS", "FIX_REQUIRED"], required=True, help="Review verdict")
    p_rev.add_argument("--evidence", nargs="+", required=True, help="Review evidence paths")
    p_rev.add_argument("--notes", default="", help="Review notes")
    p_rev.add_argument("--issue-id", default=None, help="Issue ID if FIX_REQUIRED")
    p_rev.add_argument("--issue-title", default=None, help="Issue title if FIX_REQUIRED")
    p_rev.add_argument("--severity", choices=["P0", "P1", "P2", "P3"], default="P1", help="Issue severity")

    # restore
    p_res = subparsers.add_parser("restore", help="Restore database from snapshot")
    p_res.add_argument("--snapshot", required=True, help="Snapshot JSON file path")

    args = parser.parse_args()

    try:
        if args.command == "show":
            tasks = store.load_all_tasks()
            print("=" * 60)
            print("STUDIO V3 QUEUE STATUS")
            print("=" * 60)
            for t in tasks.values():
                print(f"[{t.status.value:<12}] {t.id}: {t.title}")
                print(f"               Owner: {t.owner} | Iteration: {t.iteration}")
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
            task = dispatcher.submit_work(args.task_id, actor=args.actor, evidence_paths=args.evidence)
            print(f"Task {task.id} -> {task.status.value}")

        elif args.command == "review":
            issues = []
            if args.result == "FIX_REQUIRED" and args.issue_id and args.issue_title:
                t = store.get_task(args.task_id)
                issues.append(Issue(
                    id=args.issue_id,
                    task_id=args.task_id,
                    iteration=t.iteration if t else 1,
                    severity=Severity(args.severity),
                    title=args.issue_title,
                    reproduction_steps="See review evidence",
                    expected="Compliant deliverable",
                    actual="Defect reported in review",
                    evidence=args.evidence,
                ))
            verdict = ReviewVerdict(
                result=args.result,
                reviewer_id=args.actor,
                evidence_paths=args.evidence,
                issues=issues,
                notes=args.notes,
            )
            task = dispatcher.review_task(args.task_id, reviewer=args.actor, verdict=verdict)
            print(f"Task {task.id} -> {task.status.value}")

        elif args.command == "restore":
            store.import_snapshot(Path(args.snapshot))
            print(f"Queue restored successfully from {args.snapshot}")

    except (PolicyViolation, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
