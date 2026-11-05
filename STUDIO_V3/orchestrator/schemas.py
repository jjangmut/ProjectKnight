"""Data schemas and types for Studio V3 Orchestrator (V3-002-R1)."""
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


class ExecutionStatus(str, Enum):
    SESSION_CREATED = "SESSION_CREATED"
    RUNNING = "RUNNING"
    SUCCEEDED = "SUCCEEDED"
    FAILED = "FAILED"
    TIMED_OUT = "TIMED_OUT"
    CANCELLED = "CANCELLED"
    UNKNOWN = "UNKNOWN"
    AGENT_COMPLETION_NOT_VERIFIED = "AGENT_COMPLETION_NOT_VERIFIED"


class Severity(str, Enum):
    P0 = "P0"  # Blocker (milestone blocked immediately)
    P1 = "P1"  # Major (blocks milestone approval)
    P2 = "P2"  # Minor (backlog polish)
    P3 = "P3"  # Optional polish


@dataclass
class EvidenceItem:
    evidence_id: str
    task_id: str
    iteration: int
    source_commit_sha: str
    working_branch: str
    agent_invocation_id: str
    file_path: str
    sha256: str
    creation_time: str
    verification_method: str = "SHA256_HASH_VERIFIED"

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> EvidenceItem:
        return cls(**data)


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
    task_id: str
    iteration: int
    agent_role: str
    provider: str
    invocation_id: str
    session_id: str
    reviewed_commit_sha: str
    evidence_hashes: Dict[str, str] = field(default_factory=dict)  # path -> sha256
    result: str = "PASS"  # "PASS" or "FIX_REQUIRED"
    evidence_paths: List[str] = field(default_factory=list)
    issues: List[Issue] = field(default_factory=list)
    notes: str = ""
    timestamp: str = field(default_factory=lambda: datetime.datetime.now(datetime.timezone.utc).isoformat())

    def to_dict(self) -> Dict[str, Any]:
        return {
            "task_id": self.task_id,
            "iteration": self.iteration,
            "agent_role": self.agent_role,
            "provider": self.provider,
            "invocation_id": self.invocation_id,
            "session_id": self.session_id,
            "reviewed_commit_sha": self.reviewed_commit_sha,
            "evidence_hashes": self.evidence_hashes,
            "result": self.result,
            "evidence_paths": self.evidence_paths,
            "issues": [i.to_dict() for i in self.issues],
            "notes": self.notes,
            "timestamp": self.timestamp,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> ReviewVerdict:
        issues = [Issue.from_dict(i) for i in data.get("issues", [])]
        return cls(
            task_id=data.get("task_id", ""),
            iteration=data.get("iteration", 1),
            agent_role=data.get("agent_role", data.get("reviewer_id", "")),
            provider=data.get("provider", "UNKNOWN"),
            invocation_id=data.get("invocation_id", ""),
            session_id=data.get("session_id", ""),
            reviewed_commit_sha=data.get("reviewed_commit_sha", ""),
            evidence_hashes=data.get("evidence_hashes", {}),
            result=data["result"],
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
    status: ExecutionStatus
    evidence_manifest: List[EvidenceItem] = field(default_factory=list)
    output_text: str = ""
    error: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["status"] = self.status.value
        d["evidence_manifest"] = [e.to_dict() for e in self.evidence_manifest]
        return d

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> ExecutionRecord:
        data_copy = dict(data)
        if isinstance(data_copy.get("status"), str):
            data_copy["status"] = ExecutionStatus(data_copy["status"])
        if "evidence_manifest" in data_copy:
            data_copy["evidence_manifest"] = [
                EvidenceItem.from_dict(e) if isinstance(e, dict) else e
                for e in data_copy["evidence_manifest"]
            ]
        return cls(**data_copy)


@dataclass
class InvocationRecord:
    invocation_id: str
    run_id: str
    task_id: str
    iteration: int
    role: str
    provider: str
    session_id: str
    worktree: str
    branch: str
    target_commit_sha: str
    started_at: str
    completed_at: Optional[str] = None
    terminal_status: str = "RUNNING"
    result_hash: str = ""
    output_text: str = ""
    error: Optional[str] = None
    created_at: str = field(default_factory=lambda: datetime.datetime.now(datetime.timezone.utc).isoformat())

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> InvocationRecord:
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
    evidence_manifest: List[EvidenceItem] = field(default_factory=list)
    reviews: Dict[str, Dict[str, Any]] = field(default_factory=dict)
    iteration: int = 0
    priority: int = 0
    active_branch: str = ""
    current_commit_sha: str = ""
    version: int = 1  # optimistic lock counter
    lease_owner: Optional[str] = None
    lease_expires_at: Optional[str] = None
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
            "evidence_manifest": [e.to_dict() for e in self.evidence_manifest],
            "reviews": self.reviews,
            "iteration": self.iteration,
            "priority": self.priority,
            "active_branch": self.active_branch,
            "current_commit_sha": self.current_commit_sha,
            "version": self.version,
            "lease_owner": self.lease_owner,
            "lease_expires_at": self.lease_expires_at,
            "issues": [i.to_dict() for i in self.issues],
            "notes": self.notes,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> Task:
        data_copy = dict(data)
        data_copy["status"] = TaskState(data_copy["status"])
        if "issues" in data_copy:
            data_copy["issues"] = [Issue.from_dict(i) if isinstance(i, dict) else i for i in data_copy["issues"]]
        if "evidence_manifest" in data_copy:
            data_copy["evidence_manifest"] = [
                EvidenceItem.from_dict(e) if isinstance(e, dict) else e
                for e in data_copy["evidence_manifest"]
            ]
        # Compatibility defaults
        data_copy.setdefault("current_commit_sha", "")
        data_copy.setdefault("version", 1)
        data_copy.setdefault("lease_owner", None)
        data_copy.setdefault("lease_expires_at", None)
        return cls(**data_copy)
