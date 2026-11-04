"""Data schemas and types for Studio V3 Orchestrator."""
from __future__ import annotations
from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import List, Dict, Any, Optional
import datetime


class TaskState(str, Enum):
    READY = "READY"
    IN_PROGRESS = "IN_PROGRESS"
    IMPLEMENTATION_COMPLETE = "IMPLEMENTATION_COMPLETE"
    IN_REVIEW = "IN_REVIEW"
    FIX_REQUIRED = "FIX_REQUIRED"
    APPROVED = "APPROVED"
    BLOCKED = "BLOCKED"


class Severity(str, Enum):
    P0 = "P0"  # Blocker (milestone blocked immediately)
    P1 = "P1"  # Major (blocks milestone approval)
    P2 = "P2"  # Minor (backlog polish)
    P3 = "P3"  # Optional polish


@dataclass
class Issue:
    id: str
    task_id: str
    iteration: int
    severity: Severity
    title: str
    reproduction_steps: str
    expected: str
    actual: str
    evidence: List[str] = field(default_factory=list)
    status: str = "OPEN"  # OPEN, RESOLVED
    resolved_by: Optional[str] = None
    created_at: str = field(default_factory=lambda: datetime.datetime.now(datetime.timezone.utc).isoformat())
    resolved_at: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["severity"] = self.severity.value
        return d

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> Issue:
        data_copy = dict(data)
        if isinstance(data_copy.get("severity"), str):
            data_copy["severity"] = Severity(data_copy["severity"])
        return cls(**data_copy)


@dataclass
class ReviewVerdict:
    result: str  # "PASS" or "FIX_REQUIRED"
    reviewer_id: str
    evidence_paths: List[str] = field(default_factory=list)
    issues: List[Issue] = field(default_factory=list)
    notes: str = ""
    timestamp: str = field(default_factory=lambda: datetime.datetime.now(datetime.timezone.utc).isoformat())

    def to_dict(self) -> Dict[str, Any]:
        return {
            "result": self.result,
            "reviewer_id": self.reviewer_id,
            "evidence_paths": self.evidence_paths,
            "issues": [i.to_dict() for i in self.issues],
            "notes": self.notes,
            "timestamp": self.timestamp,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> ReviewVerdict:
        issues = [Issue.from_dict(i) for i in data.get("issues", [])]
        return cls(
            result=data["result"],
            reviewer_id=data["reviewer_id"],
            evidence_paths=data.get("evidence_paths", []),
            issues=issues,
            notes=data.get("notes", ""),
            timestamp=data.get("timestamp", datetime.datetime.now(datetime.timezone.utc).isoformat()),
        )


@dataclass
class ExecutionRecord:
    invocation_id: str
    task_id: str
    agent_id: str
    provider: str
    session_id: str
    start_time: str
    end_time: str
    working_branch: str
    commit_sha: str
    exit_code: int
    execution_result: str  # "SUCCESS", "FAILURE", "ERROR", "TIMEOUT", "CANCELLED"
    evidence_paths: List[str] = field(default_factory=list)
    error: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> ExecutionRecord:
        return cls(**data)


@dataclass
class Task:
    id: str
    title: str
    status: TaskState
    owner: str
    reviewers: List[str]
    blocked_by: List[str] = field(default_factory=list)
    evidence: List[str] = field(default_factory=list)
    reviews: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    iteration: int = 0
    priority: int = 0
    active_branch: str = ""
    issues: List[Issue] = field(default_factory=list)
    notes: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "status": self.status.value,
            "owner": self.owner,
            "reviewers": self.reviewers,
            "blocked_by": self.blocked_by,
            "evidence": self.evidence,
            "reviews": self.reviews,
            "iteration": self.iteration,
            "priority": self.priority,
            "active_branch": self.active_branch,
            "issues": [i.to_dict() for i in self.issues],
            "notes": self.notes,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> Task:
        data_copy = dict(data)
        data_copy["status"] = TaskState(data_copy["status"])
        if "issues" in data_copy:
            data_copy["issues"] = [Issue.from_dict(i) if isinstance(i, dict) else i for i in data_copy["issues"]]
        return cls(**data_copy)
