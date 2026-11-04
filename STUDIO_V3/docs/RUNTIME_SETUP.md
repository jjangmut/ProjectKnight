# Studio V3 — Runtime Setup Guide

## Overview
This document describes the environment configuration, capability audit, and execution topology for the ProjectKnight Studio V3 multi-agent orchestrator.

## Environment Audit Results (Windows Host)

### 1. Antigravity CLI (`agy`)
- **Command:** `where.exe agy` / `Get-Command agy`
- **Result:** Not found in system PATH.
- **Status:** Headless standalone terminal CLI (`agy`) is not installed on this host.
- **Handling:** Fallback to Antigravity App Native Subagents and the Programmatic AgentAPI (`agentapi.bat`). When CLI headless execution is requested without the binary, the adapter reports `AGENT_RUNTIME_NOT_AVAILABLE` without fabricating output.

### 2. Antigravity AgentAPI Language Server
- **Path:** `C:\Users\jjang\.gemini\antigravity\bin\agentapi.bat`
- **Status:** Installed, verified operational (exit code 0).
- **Commands:**
  - `agentapi.bat new-conversation [--model=...] <prompt>`
  - `agentapi.bat get-conversation-metadata <conversation_id>`
  - `agentapi.bat send-message <recipient_id> <content>`

### 3. Antigravity Native Subagents
- **Engine:** Google DeepMind Advanced Agentic Coding (Antigravity 2.0 Desktop / IDE)
- **Status:** Fully functional and operational.
- **Registered Roles:**
  - `PK_Producer` (State and dispatch controller)
  - `PK_GameDirector` (Product vision and final milestone authority)
  - `PK_GameDesign` (Player experience and gameplay mechanics)
  - `PK_ArtDirector` (Visual direction and 3D/2D coherence)
  - `PK_ClientLead` (Godot client programming and performance)
  - `PK_QALead` (Independent QA and verification gatekeeper)

## Custom Agent Registration
Custom agents are defined in two places for complete discovery:
1. Workspace VCS Definitions: `Projects/ProjectKnight/.agents/agents/*.md`
2. Local Antigravity Root: `D:\JUNYPAPA_STUDIO\.agents\agents/*.md`

Each definition conforms to official Antigravity frontmatter:
```yaml
---
name: PK_RoleName
description: Role description
mainAgent: false
subagent: true
tools:
  - run_command
  - read_file
  - write_file
  - edit_file
---
```

## Running the Test Suite
All tests use Python's built-in `unittest` module:
```powershell
python -m unittest discover -s STUDIO_V3/tests -p "test_*.py" -v
```
