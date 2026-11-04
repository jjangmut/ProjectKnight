"""Append-only audit event log for Studio V3."""
from __future__ import annotations
import json
import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional


class EventLog:
    def __init__(self, log_path: Path):
        self.log_path = log_path
        self.log_path.parent.mkdir(parents=True, exist_ok=True)

    def record_event(
        self,
        event_type: str,
        task_id: str,
        actor: str,
        provider: str = "LOCAL",
        parent_run_id: Optional[str] = None,
        workspace: str = "",
        branch: str = "",
        commit_sha: str = "",
        evidence_paths: Optional[List[str]] = None,
        result: Optional[str] = None,
        verdict: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Record an immutable, append-only event in JSONL format."""
        entry = {
            "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "event_type": event_type,
            "task_id": task_id,
            "actor": actor,
            "provider": provider,
            "parent_run_id": parent_run_id or "",
            "workspace": workspace,
            "branch": branch,
            "commit_sha": commit_sha,
            "evidence_paths": evidence_paths or [],
            "result": result or "",
            "verdict": verdict or "",
            "details": details or {},
        }
        with open(self.log_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        return entry

    def read_events(self, task_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """Read all logged events, optionally filtering by task_id."""
        if not self.log_path.exists():
            return []
        events = []
        with open(self.log_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        e = json.loads(line)
                        if task_id is None or e.get("task_id") == task_id:
                            events.append(e)
                    except json.JSONDecodeError:
                        continue
        return events
