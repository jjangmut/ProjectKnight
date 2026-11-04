"""Base interface for agent execution adapters."""
from __future__ import annotations
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional
from ..schemas import ExecutionRecord


class AgentAdapter(ABC):
    """Abstract base adapter for dispatching work to an AI agent or runner."""

    @abstractmethod
    def probe(self) -> Dict[str, Any]:
        """Check runtime capabilities, versions, and accounts without leaking secrets."""
        pass

    @abstractmethod
    def dispatch(
        self,
        task_id: str,
        role: str,
        prompt: str,
        worktree: str,
        timeout_sec: int = 120,
    ) -> ExecutionRecord:
        """Dispatch a prompt to the specified agent role."""
        pass

    @abstractmethod
    def observe(self, invocation_id: str) -> Dict[str, Any]:
        """Observe running status or terminal outcome of an invocation."""
        pass

    @abstractmethod
    def cancel(self, invocation_id: str) -> bool:
        """Cancel an in-flight invocation safely."""
        pass
