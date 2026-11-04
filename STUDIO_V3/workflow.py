#!/usr/bin/env python3
"""Local evidence-first state engine bridging to Studio V3 Orchestrator."""
import sys
from pathlib import Path

# Add repo root to sys.path
REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from STUDIO_V3.orchestrator.cli import main

if __name__ == "__main__":
    main()
