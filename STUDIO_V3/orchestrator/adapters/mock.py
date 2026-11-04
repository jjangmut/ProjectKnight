"""Deterministic mock adapter for test suites (V3-002-R1). Marked strictly as SIMULATED_MOCK."""
from __future__ import annotations
import uuid
import datetime
from pathlib import Path
from typing import Dict, Any, Optional, List, Callable
from .base import AgentAdapter
from ..schemas import ExecutionRecord, ExecutionStatus, EvidenceItem
from ..policies import calculate_sha256


class MockAdapter(AgentAdapter):
    """Deterministic simulated agent adapter strictly for isolated automated tests."""

    def __init__(self, repo_root: Path):
        self.repo_root = repo_root
        self.invocations: List[ExecutionRecord] = []
        self.behavior_hook: Optional[Callable[[str, str, str, int], ExecutionRecord]] = None
        self._canceled_ids: set[str] = set()
        self._session_counter: int = 0

    def probe(self) -> Dict[str, Any]:
        return {
            "provider": "SIMULATED_MOCK",
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
        self._session_counter += 1
        # Distinct session ID per invocation and role
        session_id = f"mock-sess-{role.lower()}-{self._session_counter}-{uuid.uuid4().hex[:6]}"
        start_time = datetime.datetime.now(datetime.timezone.utc).isoformat()

        if self.behavior_hook:
            rec = self.behavior_hook(task_id, role, prompt, timeout_sec)
            self.invocations.append(rec)
            return rec

        end_time = datetime.datetime.now(datetime.timezone.utc).isoformat()
        rec = ExecutionRecord(
            invocation_id=inv_id,
            task_id=task_id,
            agent_id=role,
            provider="SIMULATED_MOCK",
            session_id=session_id,
            start_time=start_time,
            end_time=end_time,
            working_branch="test/mock-branch",
            commit_sha="0000000000000000000000000000000000000000",
            exit_code=0,
            status=ExecutionStatus.SUCCEEDED,
            evidence_manifest=[],
            output_text=f"Mock response for {role}: completed task {task_id}",
            error=None,
        )
        self.invocations.append(rec)
        return rec

    def observe(self, invocation_id: str) -> Dict[str, Any]:
        return {
            "invocation_id": invocation_id,
            "status": "COMPLETED",
            "running": False,
            "provider": "SIMULATED_MOCK",
        }

    def cancel(self, invocation_id: str) -> bool:
        self._canceled_ids.add(invocation_id)
        return True
