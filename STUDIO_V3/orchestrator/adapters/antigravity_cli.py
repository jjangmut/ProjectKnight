"""Real Antigravity CLI and AgentAPI execution adapter."""
from __future__ import annotations
import subprocess
import shutil
import json
import uuid
import datetime
from pathlib import Path
from typing import Dict, Any, Optional
from .base import AgentAdapter
from ..schemas import ExecutionRecord


class AntigravityCLIAdapter(AgentAdapter):
    """Adapter interfacing with Antigravity CLI and AgentAPI language server."""

    def __init__(self, agentapi_path: Optional[Path] = None, agy_cmd: str = "agy"):
        self.agy_cmd = agy_cmd
        default_agentapi = Path(r"C:\Users\jjang\.gemini\antigravity\bin\agentapi.bat")
        self.agentapi_path = agentapi_path or (default_agentapi if default_agentapi.exists() else None)
        self._active_processes: Dict[str, subprocess.Popen] = {}

    def probe(self) -> Dict[str, Any]:
        """Perform a clean audit of CLI and AgentAPI availability."""
        cli_found = shutil.which(self.agy_cmd) is not None
        cli_version = ""
        cli_agents = []
        if cli_found:
            try:
                res = subprocess.run([self.agy_cmd, "--version"], capture_output=True, text=True, timeout=5)
                cli_version = res.stdout.strip()
            except Exception:
                cli_found = False

        agentapi_found = self.agentapi_path is not None and self.agentapi_path.exists()
        agentapi_meta = {}
        if agentapi_found:
            try:
                res = subprocess.run([str(self.agentapi_path), "--help"], capture_output=True, text=True, timeout=5)
                agentapi_found = (res.returncode == 0)
            except Exception:
                agentapi_found = False

        status = "READY" if (cli_found or agentapi_found) else "AGENT_RUNTIME_NOT_AVAILABLE"

        return {
            "provider": "ANTIGRAVITY",
            "cli_available": cli_found,
            "cli_command": self.agy_cmd,
            "cli_version": cli_version,
            "agentapi_available": agentapi_found,
            "agentapi_path": str(self.agentapi_path) if self.agentapi_path else "",
            "native_subagents_supported": True,
            "status": status,
        }

    def dispatch(
        self,
        task_id: str,
        role: str,
        prompt: str,
        worktree: str,
        timeout_sec: int = 120,
    ) -> ExecutionRecord:
        """Dispatch task to Antigravity CLI or AgentAPI."""
        inv_id = f"inv-{uuid.uuid4().hex[:12]}"
        start_time = datetime.datetime.now(datetime.timezone.utc).isoformat()
        probe_info = self.probe()

        if not probe_info["cli_available"] and not probe_info["agentapi_available"]:
            end_time = datetime.datetime.now(datetime.timezone.utc).isoformat()
            return ExecutionRecord(
                invocation_id=inv_id,
                task_id=task_id,
                agent_id=role,
                provider="ANTIGRAVITY_LIVE",
                session_id="",
                start_time=start_time,
                end_time=end_time,
                working_branch="",
                commit_sha="",
                exit_code=127,
                execution_result="ERROR",
                evidence_paths=[],
                error="AGENT_RUNTIME_NOT_AVAILABLE: Neither agy CLI nor agentapi binary is accessible in environment.",
            )

        # If agy CLI is available, run CLI headless
        if probe_info["cli_available"]:
            cmd = [
                self.agy_cmd,
                "-p", prompt,
                "--agent", role,
                "--output-format", "json",
                "--print-timeout", f"{timeout_sec}s",
            ]
            try:
                proc = subprocess.run(cmd, cwd=worktree, capture_output=True, text=True, timeout=timeout_sec)
                end_time = datetime.datetime.now(datetime.timezone.utc).isoformat()
                exit_code = proc.returncode
                session_id = ""
                error = proc.stderr if exit_code != 0 else None
                result = "SUCCESS" if exit_code == 0 else "FAILURE"
                return ExecutionRecord(
                    invocation_id=inv_id,
                    task_id=task_id,
                    agent_id=role,
                    provider="ANTIGRAVITY_CLI",
                    session_id=session_id,
                    start_time=start_time,
                    end_time=end_time,
                    working_branch="",
                    commit_sha="",
                    exit_code=exit_code,
                    execution_result=result,
                    evidence_paths=[],
                    error=error,
                )
            except subprocess.TimeoutExpired:
                end_time = datetime.datetime.now(datetime.timezone.utc).isoformat()
                return ExecutionRecord(
                    invocation_id=inv_id,
                    task_id=task_id,
                    agent_id=role,
                    provider="ANTIGRAVITY_CLI",
                    session_id="",
                    start_time=start_time,
                    end_time=end_time,
                    working_branch="",
                    commit_sha="",
                    exit_code=124,
                    execution_result="TIMEOUT",
                    evidence_paths=[],
                    error=f"Execution timed out after {timeout_sec}s",
                )

        # Fallback to agentapi binary probe/invocation
        if probe_info["agentapi_available"] and self.agentapi_path:
            cmd = [
                str(self.agentapi_path),
                "new-conversation",
                f"[{role}] {prompt}",
            ]
            try:
                proc = subprocess.run(cmd, cwd=worktree, capture_output=True, text=True, timeout=timeout_sec)
                end_time = datetime.datetime.now(datetime.timezone.utc).isoformat()
                exit_code = proc.returncode
                stdout_text = proc.stdout.strip()
                session_id = ""
                # Attempt to parse json conversation id
                try:
                    meta = json.loads(stdout_text)
                    session_id = meta.get("response", {}).get("conversationId", "")
                except Exception:
                    pass

                result = "SUCCESS" if exit_code == 0 else "FAILURE"
                return ExecutionRecord(
                    invocation_id=inv_id,
                    task_id=task_id,
                    agent_id=role,
                    provider="ANTIGRAVITY_AGENTAPI",
                    session_id=session_id,
                    start_time=start_time,
                    end_time=end_time,
                    working_branch="",
                    commit_sha="",
                    exit_code=exit_code,
                    execution_result=result,
                    evidence_paths=[],
                    error=proc.stderr if exit_code != 0 else None,
                )
            except subprocess.TimeoutExpired:
                end_time = datetime.datetime.now(datetime.timezone.utc).isoformat()
                return ExecutionRecord(
                    invocation_id=inv_id,
                    task_id=task_id,
                    agent_id=role,
                    provider="ANTIGRAVITY_AGENTAPI",
                    session_id="",
                    start_time=start_time,
                    end_time=end_time,
                    working_branch="",
                    commit_sha="",
                    exit_code=124,
                    execution_result="TIMEOUT",
                    evidence_paths=[],
                    error=f"Execution timed out after {timeout_sec}s",
                )

    def observe(self, invocation_id: str) -> Dict[str, Any]:
        proc = self._active_processes.get(invocation_id)
        if not proc:
            return {"status": "UNKNOWN", "running": False}
        poll = proc.poll()
        return {
            "status": "RUNNING" if poll is None else "COMPLETED",
            "running": poll is None,
            "exit_code": poll,
        }

    def cancel(self, invocation_id: str) -> bool:
        proc = self._active_processes.get(invocation_id)
        if proc and proc.poll() is None:
            proc.kill()
            return True
        return False
