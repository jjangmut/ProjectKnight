#!/usr/bin/env python3
"""Local evidence-first state engine. DOES NOT run autonomous AI agents."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DB = ROOT / "queue.json"
VALID = {"READY", "IN_PROGRESS", "IN_REVIEW", "FIX_REQUIRED", "APPROVED", "BLOCKED"}

def load():
    data = json.loads(DB.read_text(encoding="utf-8"))
    return data

def save(data):
    DB.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

def task(data, tid):
    for t in data["tasks"]:
        if t["id"] == tid:
            return t
    raise ValueError("unknown task " + tid)

def evidence(paths):
    if not paths:
        raise ValueError("real evidence path required")
    output = []
    for raw in paths:
        p = Path(raw)
        resolved = p if p.is_absolute() else ROOT.parent / p
        if not resolved.is_file():
            raise ValueError("evidence file not found: " + raw)
        output.append(str(resolved.relative_to(ROOT.parent)) if resolved.is_relative_to(ROOT.parent) else str(resolved))
    return output

def run():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("show")
    for verb in ("start", "submit", "review"):
        p = sub.add_parser(verb)
        p.add_argument("task_id")
        p.add_argument("--actor", required=True)
        if verb in ("submit", "review"):
            p.add_argument("--evidence", nargs="+", required=True)
        if verb == "review":
            p.add_argument("--result", choices=("PASS", "FIX_REQUIRED"), required=True)
    args = parser.parse_args()
    db = load()
    if args.command == "show":
        for t in db["tasks"]:
            print(t["id"], t["status"], "owner=" + t["owner"], "reviews=" + str(t.get("reviews", {})))
        print("Agent dispatch:", db["agent_dispatch"])
        return
    t = task(db, args.task_id)
    if args.command == "start":
        if args.actor != t["owner"] or t["status"] not in ("READY", "FIX_REQUIRED"):
            raise ValueError("invalid start authorization or state")
        if any(task(db, dep)["status"] != "APPROVED" for dep in t.get("blocked_by", [])):
            raise ValueError("task dependencies not approved")
        t["status"] = "IN_PROGRESS"
        t["iteration"] += 1
        t["reviews"] = {}
    elif args.command == "submit":
        if args.actor != t["owner"] or t["status"] != "IN_PROGRESS":
            raise ValueError("owner must be working")
        t["evidence"] = evidence(args.evidence)
        t["status"] = "IN_REVIEW"
    elif args.command == "review":
        if t["status"] != "IN_REVIEW" or args.actor not in t["reviewers"] or args.actor == t["owner"]:
            raise ValueError("independent authorized reviewer required")
        docs = evidence(args.evidence)
        t["reviews"][args.actor] = {"result": args.result, "evidence": docs}
        if args.result == "FIX_REQUIRED":
            t["status"] = "FIX_REQUIRED"
        elif all(t["reviews"].get(r, {}).get("result") == "PASS" for r in t["reviewers"]):
            t["status"] = "APPROVED"
    assert t["status"] in VALID
    save(db)
    print(t["id"] + " -> " + t["status"])

if __name__ == "__main__":
    try:
        run()
    except (ValueError, KeyError) as exc:
        raise SystemExit("ERROR: " + str(exc))
