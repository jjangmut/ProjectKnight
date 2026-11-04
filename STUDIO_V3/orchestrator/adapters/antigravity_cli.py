"""Real Antigravity CLI and AgentAPI execution adapter (V3-002-R1)."""
from __future__ import annotations
import subprocess
import shutil
import json
import uuid
import datetime
from pathlib import Path
from typing import Dict, Any, Optional
from .base import AgentAdapter
from ..schemas import ExecutionRecord, ExecutionStatus


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
        if cli_found:
            try:
                res = subprocess.run([self.agy_cmd, "--version"], capture_output=True, text=True, timeout=5)
                cli_version = res.stdout.strip()
            except Exception:
                cli_found = False

        agentapi_found = self.agentapi_path is not None and self.agentapi_path.exists()
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
        """Dispatch task to Antigravity CLI or AgentAPI with strict completion verification."""
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
                status=ExecutionStatus.FAILED,
                evidence_manifest=[],
                output_text="",
                error="AGENT_RUNTIME_NOT_AVAILABLE: Neither agy CLI nor agentapi binary is accessible in environment.",
            )

        # 1. Official standalone CLI path
        if probe_info["cli_available"]:
            cmd = [
                self.agy_cmd,
                "-p", prompt,
                "--agent", role,
                "--output-format", "json",
                "--print-timeout", f"{timeout_sec}s",
            ]
            try:
                proc = subprocess.Popen(
                    cmd, cwd=worktree, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
                )
                self._active_processes[inv_id] = proc
                stdout, stderr = proc.communicate(timeout=timeout_sec)
                end_time = datetime.datetime.now(datetime.timezone.utc).isoformat()
                exit_code = proc.returncode

                # Validate JSON status response from CLI
                status = ExecutionStatus.FAILED
                session_id = ""
                try:
                    payload = json.loads(stdout.strip())
                    if payload.get("status") == "SUCCESS":
                        status = ExecutionStatus.SUCCEEDED
                        session_id = payload.get("conversation_id", "")
                    else:
                        status = ExecutionStatus.FAILED
                except Exception:
                    status = ExecutionStatus.SUCCEEDED if exit_code == 0 else ExecutionStatus.FAILED

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
                    status=status,
                    evidence_manifest=[],
                    output_text=stdout,
                    error=stderr if exit_code != 0 else None,
                )
            except subprocess.TimeoutExpired:
                proc = self._active_processes.get(inv_id)
                if proc:
                    proc.kill()
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
                    status=ExecutionStatus.TIMED_OUT,
                    evidence_manifest=[],
                    output_text="",
                    error=f"Execution timed out after {timeout_sec}s",
                )
            finally:
                self._active_processes.pop(inv_id, None)

        # 2. AgentAPI fallback path
        if probe_info["agentapi_available"] and self.agentapi_path:
            cmd = [
                str(self.agentapi_path),
                "new-conversation",
                f"[{role}] {prompt}",
            ]
            try:
                proc = subprocess.Popen(
                    cmd, cwd=worktree, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
                )
                self._active_processes[inv_id] = proc
                stdout, stderr = proc.communicate(timeout=timeout_sec)
                end_time = datetime.datetime.now(datetime.timezone.utc).isoformat()
                exit_code = proc.returncode

                session_id = ""
                try:
                    meta = json.loads(stdout.strip())
                    session_id = meta.get("response", {}).get("newConversation", {}).get("conversationId", "")
                except Exception:
                    pass

                # BLOCKER 02 FIX: Do NOT equate session creation with task completion!
                # If returncode is 0, session was created, but background work completion cannot be verified headlessly
                if exit_code == 0 and session_id:
                    status = ExecutionStatus.AGENT_COMPLETION_NOT_VERIFIED
                    err_msg = "AgentAPI conversation created successfully, but headless completion verification is unsupported by CLI; requires native subagent or operator-mediated observation."
                else:
                    status = ExecutionStatus.FAILED
                    err_msg = stderr or "Failed to spawn conversation in AgentAPI."

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
                    status=status,
                    evidence_manifest=[],
                    output_text=stdout,
                    error=err_msg,
                )
            except subprocess.TimeoutExpired:
                proc = self._active_processes.get(inv_id)
                if proc:
                    proc.kill()
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
                    status=ExecutionStatus.TIMED_OUT,
                    evidence_manifest=[],
                    output_text="",
                    error=f"Execution timed out after {timeout_sec}s",
                )
            finally:
                self._active_processes.pop(inv_id, None)

        return ExecutionRecord(
            invocation_id=inv_id,
            task_id=task_id,
            agent_id=role,
            provider="ANTIGRAVITY_LIVE",
            session_id="",
            start_time=start_time,
            end_time=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            working_branch="",
            commit_sha="",
            exit_code=1,
            status=ExecutionStatus.UNKNOWN,
            evidence_manifest=[],
            output_text="",
            error="Unhandled dispatch state",
        )

    def observe(self, invocation_id: str) -> Dict[str, Any]:
        """Observe active subprocess if tracked, otherwise return UNSUPPORTED."""
        proc = self._active_processes.get(invocation_id)
        if not proc:
            return {
                "invocation_id": invocation_id,
                "status": "UNSUPPORTED",
                "running": False,
                "message": "Subprocess not actively tracked by local adapter process table.",
            }
        poll = proc.poll()
        return {
            "invocation_id": invocation_id,
            "status": "RUNNING" if poll is None else "COMPLETED",
            "running": poll is None,
            "exit_code": poll,
        }

    def cancel(self, invocation_id: str) -> bool:
        """Cancel tracked subprocess. Returns False if unsupported or process not found."""
        proc = self._active_processes.get(invocation_id)
        if proc and proc.poll() is None:
            proc.kill()
            return True
        return False
