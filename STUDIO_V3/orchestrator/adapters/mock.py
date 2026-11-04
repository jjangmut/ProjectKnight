"""Deterministic mock adapter for testing orchestration pipelines without real LLM costs."""
from __future__ import annotations
import uuid
import datetime
from pathlib import Path
from typing import Dict, Any, Optional, List, Callable
from .base import AgentAdapter
from ..schemas import ExecutionRecord


class MockAdapter(AgentAdapter):
    """Deterministic simulated agent adapter for test suites."""

    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.invocations: List[ExecutionRecord] = []
        self.behavior_hook: Optional[Callable[[str, str, str, int], ExecutionRecord]] = None
        self._canceled_ids: set[str] = set()

    def probe(self) -> Dict[str, Any]:
        return {
            "provider": "MOCK_SIMULATED",
            "cli_available": True,
            "agentapi_available": True,
            "status": "READY",
            "mock": True,
        }

    def dispatch(
        self,
        task_id: str,
        role: str,
        prompt: str,
        worktree: str,
        timeout_sec: int = 120,
    ) -> ExecutionRecord:
        inv_id = f"mock-inv-{uuid.uuid4().hex[:8]}"
        start_time = datetime.datetime.now(datetime.timezone.utc).isoformat()

        # If a custom behavior hook is set for a specific test scenario
        if self.behavior_hook:
            rec = self.behavior_hook(task_id, role, prompt, timeout_sec)
            self.invocations.append(rec)
            return rec

        end_time = datetime.datetime.now(datetime.timezone.utc).isoformat()
        rec = ExecutionRecord(
            invocation_id=inv_id,
            task_id=task_id,
            agent_id=role,
            provider="MOCK_SIMULATED",
            session_id=f"mock-sess-{uuid.uuid4().hex[:6]}",
            start_time=start_time,
            end_time=end_time,
            working_branch="test/mock-branch",
            commit_sha="0000000000000000000000000000000000000000",
            exit_code=0,
            execution_result="SUCCESS",
            evidence_paths=[],
            error=None,
        )
        self.invocations.append(rec)
        return rec

    def observe(self, invocation_id: str) -> Dict[str, Any]:
        return {"invocation_id": invocation_id, "status": "COMPLETED", "running": False}

    def cancel(self, invocation_id: str) -> bool:
        self._canceled_ids.add(invocation_id)
        return True
