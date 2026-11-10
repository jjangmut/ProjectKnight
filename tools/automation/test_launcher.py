#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Unit and Integration Test Suite for ProjectKnight One-Click Launcher
Location: tools/automation/test_launcher.py
"""

import os
import sys
import unittest
import json
import tempfile
import queue

current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

from launcher import (
    DEFAULT_AUTOMATION_DIR,
    DEFAULT_REPO_DIR,
    DEFAULT_WORKTREE_DIR,
    SETTINGS_PATH,
    STATE_PATH,
    STAGES,
    load_launcher_settings,
    save_launcher_settings,
    load_completed_tasks,
    run_git
)

class TestProjectKnightLauncher(unittest.TestCase):
    def test_settings_persistence(self):
        """Verify that Auto-Approve toggle state correctly saves and loads."""
        initial = load_launcher_settings()
        try:
            save_launcher_settings({"auto_approve": True})
            s1 = load_launcher_settings()
            self.assertTrue(s1.get("auto_approve"))

            save_launcher_settings({"auto_approve": False})
            s2 = load_launcher_settings()
            self.assertFalse(s2.get("auto_approve"))
        finally:
            save_launcher_settings(initial)

    def test_completed_tasks_loader(self):
        """Verify tasks_state.json parser loads completed task IDs."""
        completed = load_completed_tasks()
        self.assertIsInstance(completed, dict)
        self.assertIn("V3-001", completed)
        self.assertIn("V3-016", completed)

    def test_worktree_isolation_integrity(self):
        """Verify that main repo path differs strictly from worktree path."""
        self.assertNotEqual(
            os.path.abspath(DEFAULT_REPO_DIR).lower(),
            os.path.abspath(DEFAULT_WORKTREE_DIR).lower(),
            "Main repo and isolated worktree must not share the same physical path!"
        )

    def test_stage_definitions(self):
        """Verify all 6 execution stages are defined with descriptions."""
        self.assertEqual(len(STAGES), 6)
        stage_keys = [s[0] for s in STAGES]
        self.assertIn("DISCOVER", stage_keys)
        self.assertIn("VALIDATE", stage_keys)
        self.assertIn("WORKTREE", stage_keys)
        self.assertIn("EXECUTE", stage_keys)
        self.assertIn("SCOPE", stage_keys)
        self.assertIn("PUSH", stage_keys)

    def test_desktop_shortcut_existence(self):
        """Verify that Desktop shortcut exists."""
        desktop_dir = os.path.join(os.environ.get("USERPROFILE", ""), "Desktop")
        shortcut_file = os.path.join(desktop_dir, "ProjectKnight 작업 실행.lnk")
        self.assertTrue(
            os.path.exists(shortcut_file),
            f"Desktop shortcut does not exist at {shortcut_file}"
        )

    def test_log_queue_processing(self):
        """Verify live log streaming queue delivers items in order."""
        log_q = queue.Queue()
        test_messages = [
            ("stdout", "[STAGE:DISCOVER] 작업 탐색"),
            ("stdout", "[STAGE:VALIDATE] GitHub 지시서 검증"),
            ("stderr", "[WARN] Non-fatal notification"),
            ("stdout", "[STAGE:COMPLETE] 작업 자동 개발 및 반영 완료")
        ]
        for item in test_messages:
            log_q.put(item)

        drained = []
        while not log_q.empty():
            drained.append(log_q.get_nowait())

        self.assertEqual(len(drained), 4)
        self.assertEqual(drained[0][1], "[STAGE:DISCOVER] 작업 탐색")
        self.assertEqual(drained[3][1], "[STAGE:COMPLETE] 작업 자동 개발 및 반영 완료")

if __name__ == "__main__":
    unittest.main()
