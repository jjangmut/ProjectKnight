#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ProjectKnight One-Click Automated Developer Launcher (Windows GUI)
Location: tools/automation/launcher.py / D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\launcher.py

Features:
  - Windows Tkinter GUI (Zero extra dependencies, runs natively via pythonw.exe)
  - "GitHub 최신 작업 가져와 실행" (Fetch & Run) one-click action
  - "자동 승인" (Auto-Approve) ON/OFF persistent toggle (Default: OFF)
  - Single-shot execution per click (NO background polling or daemon loops)
  - Real-time 6-stage execution tracking ([1] Discover -> [2] Validate -> [3] Worktree -> [4] CLI -> [5] Scope -> [6] Push)
  - Live streaming log output without freezing the UI (background worker thread + queue)
  - Strict isolation in Git Worktree (D:\\JUNYPAPA_STUDIO\\Automation\\ProjectKnight\\worktree)
  - Absolute protection for main developer workspace (Projects\\ProjectKnight) and active dev (V3-017)
  - Desktop shortcut creator for 1-click launch from Windows Desktop
"""

import os
import sys
import json
import re
import time
import datetime
import subprocess
import threading
import queue
import webbrowser
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext

# ==============================================================================
# Configuration & Constants
# ==============================================================================
DEFAULT_AUTOMATION_DIR = r"D:\JUNYPAPA_STUDIO\Automation\ProjectKnight"
DEFAULT_REPO_DIR = r"D:\JUNYPAPA_STUDIO\Projects\ProjectKnight"
DEFAULT_WORKTREE_DIR = r"D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\worktree"
RUNNER_PS1_PATH = os.path.join(DEFAULT_AUTOMATION_DIR, "runner.ps1")
CONFIG_PATH = os.path.join(DEFAULT_AUTOMATION_DIR, "config.json")
STATE_PATH = os.path.join(DEFAULT_AUTOMATION_DIR, "state", "tasks_state.json")
SETTINGS_PATH = os.path.join(DEFAULT_AUTOMATION_DIR, "launcher_settings.json")
LOGS_DIR = os.path.join(DEFAULT_AUTOMATION_DIR, "logs")

STAGES = [
    ("DISCOVER", "① 작업 탐색 (Discover)"),
    ("VALIDATE", "② 지시서 검증 (Validate)"),
    ("WORKTREE", "③ Worktree 준비 (Worktree)"),
    ("EXECUTE",  "④ CLI 개발·테스트 (Execute)"),
    ("SCOPE",    "⑤ 범위 검증·커밋 (Commit)"),
    ("PUSH",     "⑥ GitHub Push (Push & Sync)")
]

FORBIDDEN_BRANCHES = ["main", "master", "integration", "HEAD", "task/art-stage-batch-001"]
PROTECTED_ACTIVE_TASKS = ["v3-017", "V3-017"]

# ==============================================================================
# Helper Functions
# ==============================================================================
def load_launcher_settings():
    if os.path.exists(SETTINGS_PATH):
        try:
            with open(SETTINGS_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"auto_approve": False}

def save_launcher_settings(settings):
    try:
        os.makedirs(os.path.dirname(SETTINGS_PATH), exist_ok=True)
        with open(SETTINGS_PATH, "w", encoding="utf-8") as f:
            json.dump(settings, f, indent=2, ensure_ascii=False)
    except Exception as e:
        print(f"Failed to save settings: {e}")

def load_completed_tasks():
    if os.path.exists(STATE_PATH):
        try:
            with open(STATE_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("completed_tasks", {})
        except Exception:
            pass
    return {}

def run_git(args, cwd=DEFAULT_REPO_DIR, timeout=30):
    cmd = ["git"] + args
    res = subprocess.run(
        cmd,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout
    )
    if res.returncode != 0:
        raise RuntimeError(f"Git command failed: {' '.join(cmd)}\n{res.stderr.strip()}")
    return res.stdout

# ==============================================================================
# Main GUI Application
# ==============================================================================
class ProjectKnightLauncherApp:
    def __init__(self, root):
        self.root = root
        self.root.title("ProjectKnight — 원클릭 개발 실행기 (One-Click Developer)")
        self.root.geometry("920x760")
        self.root.minsize(840, 640)

        # State Variables
        self.settings = load_launcher_settings()
        self.auto_approve_var = tk.BooleanVar(value=self.settings.get("auto_approve", False))
        self.candidate_tasks = []
        self.selected_task = None
        self.is_running = False
        self.process = None
        self.start_time = None
        self.last_log_time = None
        self.msg_queue = queue.Queue()
        self.latest_commit_sha = ""
        self.stage_widgets = {}

        # Configure Styles
        self._setup_styles()

        # Build UI Components
        self._build_ui()

        # Start periodic queue polling and timer
        self.root.after(50, self._process_queue)
        self.root.after(200, self._update_timer)

    def _setup_styles(self):
        style = ttk.Style()
        try:
            style.theme_use("clam")
        except Exception:
            pass

        style.configure("Header.TLabel", font=("Segoe UI", 16, "bold"), foreground="#1e293b")
        style.configure("SubHeader.TLabel", font=("Segoe UI", 9), foreground="#64748b")
        style.configure("StatusBadge.TLabel", font=("Segoe UI", 10, "bold"), padding=4)
        style.configure("BigRun.TButton", font=("Segoe UI", 12, "bold"), padding=8)
        style.configure("Card.TLabelframe", padding=10)
        style.configure("Card.TLabelframe.Label", font=("Segoe UI", 10, "bold"), foreground="#0f172a")

    def _build_ui(self):
        main_frame = ttk.Frame(self.root, padding=12)
        main_frame.pack(fill=tk.BOTH, expand=True)

        # ----------------------------------------------------------------------
        # 1. Header Frame
        # ----------------------------------------------------------------------
        header_frame = ttk.Frame(main_frame)
        header_frame.pack(fill=tk.X, pady=(0, 8))

        title_box = ttk.Frame(header_frame)
        title_box.pack(side=tk.LEFT, fill=tk.Y)

        ttk.Label(title_box, text="ProjectKnight 원클릭 개발 실행기", style="Header.TLabel").pack(anchor=tk.W)
        ttk.Label(title_box, text="GitHub 지시서 자동 탐색 · Antigravity CLI · 격리 Worktree 무간섭 실행", style="SubHeader.TLabel").pack(anchor=tk.W)

        # Status Badge on Right
        self.badge_var = tk.StringVar(value="[ 대기중 (IDLE) ]")
        self.badge_lbl = tk.Label(
            header_frame,
            textvariable=self.badge_var,
            font=("Segoe UI", 10, "bold"),
            bg="#e2e8f0",
            fg="#334155",
            padx=10,
            pady=4,
            relief=tk.FLAT
        )
        self.badge_lbl.pack(side=tk.RIGHT, pady=4)

        # ----------------------------------------------------------------------
        # 2. Primary Control Bar
        # ----------------------------------------------------------------------
        ctrl_frame = ttk.LabelFrame(main_frame, text="실행 제어 (Controls)", style="Card.TLabelframe")
        ctrl_frame.pack(fill=tk.X, pady=(0, 8))

        top_ctrl = ttk.Frame(ctrl_frame)
        top_ctrl.pack(fill=tk.X, pady=2)

        self.btn_run = tk.Button(
            top_ctrl,
            text="🚀 GitHub 최신 작업 가져와 실행",
            font=("Segoe UI", 11, "bold"),
            bg="#107c41",
            fg="white",
            activebackground="#0e6b37",
            activeforeground="white",
            padx=16,
            pady=6,
            relief=tk.RAISED,
            cursor="hand2",
            command=self.on_fetch_and_run_clicked
        )
        self.btn_run.pack(side=tk.LEFT, padx=(0, 10))

        chk_auto = ttk.Checkbutton(
            top_ctrl,
            text="자동 승인 (Auto-Approve)",
            variable=self.auto_approve_var,
            command=self.on_auto_approve_toggled
        )
        chk_auto.pack(side=tk.LEFT, padx=(0, 10))

        self.btn_scan = ttk.Button(top_ctrl, text="🔄 목록만 조회", command=self.on_scan_only_clicked)
        self.btn_scan.pack(side=tk.LEFT, padx=(0, 6))

        self.btn_stop = tk.Button(
            top_ctrl,
            text="⏹ 작업 중지 (Stop)",
            font=("Segoe UI", 9, "bold"),
            bg="#e2e8f0",
            fg="#64748b",
            state=tk.DISABLED,
            padx=8,
            pady=4,
            command=self.on_stop_clicked
        )
        self.btn_stop.pack(side=tk.RIGHT)

        lbl_desc = ttk.Label(
            ctrl_frame,
            text="※ 자동 승인 ON: 버튼 클릭 1회에 한해 유효한 단일 작업을 추가 팝업 없이 즉시 실행합니다. (배경 감시/연쇄 실행 없음)",
            font=("Segoe UI", 8),
            foreground="#64748b"
        )
        lbl_desc.pack(anchor=tk.W, pady=(4, 0))

        # ----------------------------------------------------------------------
        # 3. Candidate Task Card
        # ----------------------------------------------------------------------
        self.task_frame = ttk.LabelFrame(main_frame, text="현재 대상 작업 정보 (Target Task)", style="Card.TLabelframe")
        self.task_frame.pack(fill=tk.X, pady=(0, 8))

        row1 = ttk.Frame(self.task_frame)
        row1.pack(fill=tk.X, pady=2)
        ttk.Label(row1, text="작업 ID:", font=("Segoe UI", 9, "bold"), width=12).pack(side=tk.LEFT)
        self.task_selector_var = tk.StringVar(value="(조회 대기)")
        self.task_combobox = ttk.Combobox(
            row1,
            textvariable=self.task_selector_var,
            state="readonly",
            width=36
        )
        self.task_combobox.pack(side=tk.LEFT, padx=(0, 10))
        self.task_combobox.bind("<<ComboboxSelected>>", self.on_task_selected)

        ttk.Label(row1, text="브랜치:", font=("Segoe UI", 9, "bold")).pack(side=tk.LEFT, padx=(10, 4))
        self.lbl_branch = ttk.Label(row1, text="-", font=("Consolas", 9), foreground="#0369a1")
        self.lbl_branch.pack(side=tk.LEFT)

        ttk.Label(row1, text="HEAD SHA:", font=("Segoe UI", 9, "bold")).pack(side=tk.LEFT, padx=(15, 4))
        self.lbl_sha = ttk.Label(row1, text="-", font=("Consolas", 9), foreground="#0369a1")
        self.lbl_sha.pack(side=tk.LEFT)

        row2 = ttk.Frame(self.task_frame)
        row2.pack(fill=tk.X, pady=2)
        ttk.Label(row2, text="작업 제목:", font=("Segoe UI", 9, "bold"), width=12).pack(side=tk.LEFT)
        self.lbl_title = ttk.Label(row2, text="상단의 [GitHub 최신 작업 가져와 실행] 버튼을 클릭하세요.", font=("Segoe UI", 9))
        self.lbl_title.pack(side=tk.LEFT, fill=tk.X, expand=True)

        row3 = ttk.Frame(self.task_frame)
        row3.pack(fill=tk.X, pady=2)
        ttk.Label(row3, text="작업 개요:", font=("Segoe UI", 9, "bold"), width=12).pack(side=tk.LEFT, anchor=tk.N)
        self.lbl_summary = ttk.Label(row3, text="-", font=("Segoe UI", 8), foreground="#475569", wraplength=760)
        self.lbl_summary.pack(side=tk.LEFT, fill=tk.X, expand=True)

        # ----------------------------------------------------------------------
        # 4. Stage Progress Tracker
        # ----------------------------------------------------------------------
        stage_frame = ttk.LabelFrame(main_frame, text="진행 단계 (Execution Stages)", style="Card.TLabelframe")
        stage_frame.pack(fill=tk.X, pady=(0, 8))

        # Metrics bar
        metric_bar = ttk.Frame(stage_frame)
        metric_bar.pack(fill=tk.X, pady=(0, 6))

        self.lbl_timer = ttk.Label(metric_bar, text="⏱ 경과 시간: 00:00", font=("Consolas", 9, "bold"))
        self.lbl_timer.pack(side=tk.LEFT, padx=(0, 16))

        self.lbl_last_log = ttk.Label(metric_bar, text="🕒 최근 로그: -", font=("Consolas", 9))
        self.lbl_last_log.pack(side=tk.LEFT, padx=(0, 16))

        self.lbl_worktree_info = ttk.Label(
            metric_bar,
            text="📁 격리 공간: Automation/worktree (메인 개발환경 불변)",
            font=("Segoe UI", 8),
            foreground="#059669"
        )
        self.lbl_worktree_info.pack(side=tk.RIGHT)

        # Grid of stages (2 rows x 3 cols)
        stages_grid = ttk.Frame(stage_frame)
        stages_grid.pack(fill=tk.X)

        for idx, (s_key, s_name) in enumerate(STAGES):
            r = idx // 3
            c = idx % 3
            cell = ttk.Frame(stages_grid, padding=4, relief=tk.RIDGE)
            cell.grid(row=r, column=c, sticky="nsew", padx=3, pady=3)
            stages_grid.columnconfigure(c, weight=1)

            lbl_name = ttk.Label(cell, text=s_name, font=("Segoe UI", 9, "bold"))
            lbl_name.pack(anchor=tk.W)

            status_lbl = tk.Label(cell, text="⏳ 대기", font=("Segoe UI", 8), fg="#94a3b8", bg="#f8fafc", anchor=tk.W)
            status_lbl.pack(anchor=tk.W, fill=tk.X)

            self.stage_widgets[s_key] = {
                "cell": cell,
                "name": lbl_name,
                "status": status_lbl
            }

        # ----------------------------------------------------------------------
        # 5. Live Console Log Output
        # ----------------------------------------------------------------------
        log_frame = ttk.LabelFrame(main_frame, text="실시간 실행 로그 (Live CLI Output)", style="Card.TLabelframe")
        log_frame.pack(fill=tk.BOTH, expand=True, pady=(0, 6))

        self.log_text = scrolledtext.ScrolledText(
            log_frame,
            wrap=tk.WORD,
            bg="#181818",
            fg="#d4d4d4",
            insertbackground="#ffffff",
            font=("Consolas", 9),
            padx=8,
            pady=8
        )
        self.log_text.pack(fill=tk.BOTH, expand=True)

        # Tag configurations for color-coded logs
        self.log_text.tag_config("INFO", foreground="#38bdf8")
        self.log_text.tag_config("PASS", foreground="#4ade80")
        self.log_text.tag_config("WARN", foreground="#facc15")
        self.log_text.tag_config("FAIL", foreground="#f87171")
        self.log_text.tag_config("STAGE", foreground="#c084fc", font=("Consolas", 9, "bold"))
        self.log_text.tag_config("NORMAL", foreground="#e2e8f0")

        # ----------------------------------------------------------------------
        # 6. Footer / Result & Action Bar
        # ----------------------------------------------------------------------
        footer_frame = ttk.Frame(main_frame)
        footer_frame.pack(fill=tk.X)

        self.lbl_result = ttk.Label(footer_frame, text="준비 완료.", font=("Segoe UI", 9))
        self.lbl_result.pack(side=tk.LEFT, fill=tk.X, expand=True)

        self.btn_open_commit = ttk.Button(
            footer_frame,
            text="🌐 GitHub 커밋 보기",
            state=tk.DISABLED,
            command=self.on_open_commit_clicked
        )
        self.btn_open_commit.pack(side=tk.RIGHT, padx=(4, 0))

        self.btn_open_logs = ttk.Button(
            footer_frame,
            text="📄 로그 폴더 열기",
            command=self.on_open_logs_clicked
        )
        self.btn_open_logs.pack(side=tk.RIGHT, padx=(4, 0))

        self.btn_create_shortcut = ttk.Button(
            footer_frame,
            text="📌 바탕화면 바로가기 생성",
            command=self.on_create_shortcut_clicked
        )
        self.btn_create_shortcut.pack(side=tk.RIGHT, padx=(4, 0))

        # Initial log message
        self._append_log("[INFO] ProjectKnight 원클릭 개발 실행기가 준비되었습니다.", "INFO")
        self._append_log("[INFO] 버튼 클릭 전에는 평상시 네트워크 통신 및 백그라운드 폴링이 전혀 발생하지 않습니다.", "INFO")

    # ==========================================================================
    # UI State Management
    # ==========================================================================
    def _set_stage_status(self, stage_key, status_type, text=""):
        if stage_key not in self.stage_widgets:
            return
        w = self.stage_widgets[stage_key]["status"]
        if status_type == "RUNNING":
            w.config(text=f"🔄 진행중 {text}", fg="#0284c7", bg="#f0f9ff")
        elif status_type == "DONE":
            w.config(text=f"✅ 완료 {text}", fg="#16a34a", bg="#f0fdf4")
        elif status_type == "FAIL":
            w.config(text=f"❌ 실패 {text}", fg="#dc2626", bg="#fef2f2")
        elif status_type == "STOPPED":
            w.config(text="⏹ 중지됨", fg="#ea580c", bg="#fff7ed")
        else: # WAITING
            w.config(text="⏳ 대기", fg="#94a3b8", bg="#f8fafc")

    def _reset_stages(self):
        for s_key, _ in STAGES:
            self._set_stage_status(s_key, "WAITING")

    def _update_badge(self, state_text, bg_color="#e2e8f0", fg_color="#334155"):
        self.badge_var.set(f"[ {state_text} ]")
        self.badge_lbl.config(bg=bg_color, fg=fg_color)

    def _append_log(self, text, tag="NORMAL"):
        self.log_text.insert(tk.END, text + "\n", tag)
        self.log_text.see(tk.END)
        now_str = datetime.datetime.now().strftime("%H:%M:%S")
        self.last_log_time = now_str
        self.lbl_last_log.config(text=f"🕒 최근 로그: {now_str}")

    def _update_timer(self):
        if self.is_running and self.start_time:
            elapsed = int(time.time() - self.start_time)
            m = elapsed // 60
            s = elapsed % 60
            self.lbl_timer.config(text=f"⏱ 경과 시간: {m:02d}:{s:02d}")
        self.root.after(200, self._update_timer)

    # ==========================================================================
    # Event Handlers
    # ==========================================================================
    def on_auto_approve_toggled(self):
        self.settings["auto_approve"] = self.auto_approve_var.get()
        save_launcher_settings(self.settings)
        state_str = "ON" if self.settings["auto_approve"] else "OFF"
        self._append_log(f"[INFO] 자동 승인(Auto-Approve) 설정이 '{state_str}'으로 변경되었습니다.", "INFO")

    def on_task_selected(self, event=None):
        idx = self.task_combobox.current()
        if 0 <= idx < len(self.candidate_tasks):
            task = self.candidate_tasks[idx]
            self.selected_task = task
            self.lbl_branch.config(text=task.get("branch", "-"))
            self.lbl_sha.config(text=task.get("head_sha", "-"))
            self.lbl_title.config(text=task.get("title", task.get("task_id", "-")))
            self.lbl_summary.config(text=task.get("summary", "(개요 없음)"))

    def on_open_logs_clicked(self):
        if os.path.exists(LOGS_DIR):
            os.startfile(LOGS_DIR)
        else:
            messagebox.showinfo("알림", f"로그 디렉터리가 아직 없습니다:\n{LOGS_DIR}")

    def on_open_commit_clicked(self):
        if self.latest_commit_sha:
            url = f"https://github.com/jjangmut/ProjectKnight/commit/{self.latest_commit_sha}"
            webbrowser.open(url)

    def on_create_shortcut_clicked(self):
        try:
            self._create_desktop_shortcut()
            messagebox.showinfo("성공", "바탕화면에 'ProjectKnight 작업 실행' 바로가기가 생성되었습니다!")
            self._append_log("[PASS] 바탕화면 바로가기(ProjectKnight 작업 실행.lnk) 생성 완료.", "PASS")
        except Exception as e:
            messagebox.showerror("오류", f"바로가기 생성 실패: {e}")

    # ==========================================================================
    # Action: Fetch & Run / Scan
    # ==========================================================================
    def on_scan_only_clicked(self):
        if self.is_running:
            return
        threading.Thread(target=self._scan_tasks_worker, args=(False,), daemon=True).start()

    def on_fetch_and_run_clicked(self):
        if self.is_running:
            return
        threading.Thread(target=self._scan_tasks_worker, args=(True,), daemon=True).start()

    def _scan_tasks_worker(self, auto_run):
        self._set_ui_running(True, "작업 탐색중 (SCANNING)")
        self._reset_stages()
        self._set_stage_status("DISCOVER", "RUNNING")
        self.msg_queue.put(("log", ("[INFO] GitHub 원격 브랜치 및 지시서 조회를 시작합니다...", "INFO")))

        try:
            # 1. Fetch remote references on demand
            self.msg_queue.put(("log", ("[INFO] git fetch origin --prune 실행 중...", "INFO")))
            run_git(["fetch", "origin", "--prune"], cwd=DEFAULT_REPO_DIR, timeout=45)

            # 2. Query completed tasks
            completed_dict = load_completed_tasks()

            # 3. Discover branches
            raw_branches = run_git(["branch", "-r"], cwd=DEFAULT_REPO_DIR)
            branches = [b.strip() for b in raw_branches.splitlines() if b.strip()]

            candidates = []
            for b in branches:
                if " -> " in b:
                    continue
                if not (b.startswith("origin/studio/v3-") or b.startswith("origin/test/v3-")):
                    continue

                branch_name = b.replace("origin/", "")

                # Strict check: never touch forbidden branches
                if branch_name in FORBIDDEN_BRANCHES:
                    continue

                # Strict check: protect ongoing V3-017
                if any(p in branch_name for p in PROTECTED_ACTIVE_TASKS):
                    continue

                # Query tasks in that branch
                try:
                    tree_out = run_git(["ls-tree", "-r", "--name-only", b, "STUDIO_V3/tasks"], cwd=DEFAULT_REPO_DIR)
                except Exception:
                    continue

                task_files = [f.strip() for f in tree_out.splitlines() if f.strip().endswith(".md")]
                for tf in task_files:
                    task_id = os.path.splitext(os.path.basename(tf))[0]
                    if task_id in completed_dict:
                        continue  # Already finished

                    # Read task file content
                    try:
                        content = run_git(["show", f"{b}:{tf}"], cwd=DEFAULT_REPO_DIR)
                    except Exception:
                        continue

                    # Validate branch declaration
                    m_branch = re.search(r'(?im)(?:\*{0,2}Target Branch|\*{0,2}Branch):\*{0,2}\s*`?([a-zA-Z0-9_\-\/]+)`?', content)
                    declared_branch = m_branch.group(1).strip() if m_branch else ""

                    # Match task branch to remote branch (or task is intended for this branch)
                    if declared_branch == branch_name or declared_branch == "" or task_id.startswith("V3-TEST"):
                        head_sha = run_git(["rev-parse", "--short", b], cwd=DEFAULT_REPO_DIR).strip()
                        full_sha = run_git(["rev-parse", b], cwd=DEFAULT_REPO_DIR).strip()

                        # Extract title and summary
                        title = task_id
                        summary_lines = []
                        for line in content.splitlines():
                            if line.startswith("# ") and title == task_id:
                                title = line[2:].strip()
                            elif line.strip().startswith("- ") or line.strip().startswith("1. ") or line.strip().startswith("## "):
                                if len(summary_lines) < 3 and not line.startswith("## "):
                                    summary_lines.append(line.strip())

                        summary = "\n".join(summary_lines) if summary_lines else "(개요 정보 없음)"

                        candidates.append({
                            "task_id": task_id,
                            "title": title,
                            "branch": branch_name,
                            "head_sha": head_sha,
                            "full_sha": full_sha,
                            "summary": summary,
                            "task_file": tf
                        })

            self.candidate_tasks = candidates
            self.msg_queue.put(("scan_done", (candidates, auto_run)))

        except Exception as e:
            self.msg_queue.put(("error", f"작업 탐색 중 오류 발생: {e}"))
            self.msg_queue.put(("stage", ("DISCOVER", "FAIL")))
            self.msg_queue.put(("ui_done", False))

    def _on_scan_done(self, candidates, auto_run):
        self._set_stage_status("DISCOVER", "DONE", f"({len(candidates)}건 발견)")
        self._append_log(f"[PASS] GitHub 작업 탐색 완료: 미완료 후보 {len(candidates)}건 발견", "PASS")

        if not candidates:
            self.lbl_title.config(text="현재 미완료된 신규 GitHub 작업이 없습니다.")
            self.lbl_summary.config(text="모든 등록된 지시서가 완료 상태(tasks_state.json)이거나 현재 활성 브랜치가 없습니다.")
            self.task_selector_var.set("(미완료 작업 없음)")
            self.task_combobox["values"] = []
            self._set_ui_running(False, "대기중 (IDLE)")
            self._append_log("[INFO] 모든 작업이 최신 상태입니다. 대기 모드로 복귀합니다.", "INFO")
            return

        # Populate Combobox
        task_labels = [f"{c['task_id']} — {c['branch']} ({c['head_sha']})" for c in candidates]
        self.task_combobox["values"] = task_labels
        self.task_combobox.current(0)
        self.on_task_selected()

        if not auto_run:
            self._set_ui_running(False, "선택 대기 (AWAITING_SELECTION)")
            self._append_log("[INFO] 작업 목록이 갱신되었습니다. 실행할 작업을 확인하세요.", "INFO")
            return

        # Auto-run requested
        if len(candidates) > 1:
            # Multiple candidates -> User MUST choose explicitly per Requirement 4
            self._set_ui_running(False, "선택 필요 (MULTIPLE_CANDIDATES)")
            self._append_log("[WARN] 미완료 작업이 여러 개 발견되었습니다. 목록에서 실행할 작업을 명시적으로 선택 후 실행해 주세요.", "WARN")
            messagebox.showinfo(
                "작업 선택 필요",
                f"GitHub에 {len(candidates)}개의 미완료 작업이 등록되어 있습니다.\n상단 목록에서 실행할 작업을 선택한 후 다시 실행을 눌러주세요."
            )
            return

        # Exactly 1 candidate
        target = candidates[0]
        self.selected_task = target

        # Check Auto-Approve setting
        if self.auto_approve_var.get():
            self._append_log(f"[INFO] 자동 승인 ON: 작업 '{target['task_id']}'을(를) 추가 팝업 없이 즉시 실행합니다.", "INFO")
            self._start_task_execution(target)
        else:
            # Manual approval prompt
            confirm_msg = (
                f"다음 GitHub 작업을 승인하고 Antigravity로 개발을 시작하시겠습니까?\n\n"
                f"• 작업 ID:      {target['task_id']}\n"
                f"• 작업 제목:    {target['title']}\n"
                f"• 대상 브랜치:  {target['branch']}\n"
                f"• 원격 HEAD:    {target['head_sha']}\n"
                f"• 실행 공간:    D:\\JUNYPAPA_STUDIO\\Automation\\ProjectKnight\\worktree (완전 격리)\n\n"
                f"승인 시 Antigravity CLI가 격리 Worktree에서 개발·테스트·커밋·Push를 수행합니다."
            )
            if messagebox.askyesno("작업 승인 확인 (Manual Approval)", confirm_msg):
                self._append_log(f"[INFO] 사용자 수동 승인 완료: 작업 '{target['task_id']}' 실행 시작", "INFO")
                self._start_task_execution(target)
            else:
                self._append_log(f"[WARN] 사용자가 작업 '{target['task_id']}' 승인을 취소했습니다.", "WARN")
                self._set_ui_running(False, "취소됨 (CANCELLED)")

    # ==========================================================================
    # Action: Task Execution
    # ==========================================================================
    def _start_task_execution(self, task):
        self.is_running = True
        self.start_time = time.time()
        self.latest_commit_sha = ""
        self.btn_open_commit.config(state=tk.DISABLED)
        self._set_ui_running(True, "실행중 (RUNNING)", "#dbeafe", "#1e40af")
        self._set_stage_status("VALIDATE", "DONE", "승인 통과")

        threading.Thread(target=self._run_task_worker, args=(task,), daemon=True).start()

    def _run_task_worker(self, task):
        task_id = task["task_id"]
        target_branch = task["branch"]

        self.msg_queue.put(("log", (f"[STAGE:START] 작업 {task_id} 자동 실행 파이프라인 진입", "STAGE")))

        # Command to run runner.ps1
        cmd = [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", RUNNER_PS1_PATH,
            "-Action", "Execute",
            "-TaskId", task_id,
            "-AutoApprove"
        ]

        try:
            self.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                bufsize=1
            )

            # Read line by line in real time
            for line in self.process.stdout:
                line_str = line.rstrip()
                if not line_str:
                    continue

                # Parse stage markers
                if "[STAGE:DISCOVER]" in line_str:
                    self.msg_queue.put(("stage", ("DISCOVER", "RUNNING")))
                elif "[STAGE:VALIDATE]" in line_str:
                    self.msg_queue.put(("stage", ("VALIDATE", "RUNNING")))
                elif "[STAGE:WORKTREE]" in line_str:
                    self.msg_queue.put(("stage", ("VALIDATE", "DONE")))
                    self.msg_queue.put(("stage", ("WORKTREE", "RUNNING")))
                elif "[STAGE:EXECUTE]" in line_str:
                    self.msg_queue.put(("stage", ("WORKTREE", "DONE")))
                    self.msg_queue.put(("stage", ("EXECUTE", "RUNNING")))
                elif "[STAGE:SCOPE]" in line_str:
                    self.msg_queue.put(("stage", ("EXECUTE", "DONE")))
                    self.msg_queue.put(("stage", ("SCOPE", "RUNNING")))
                elif "[STAGE:PUSH]" in line_str:
                    self.msg_queue.put(("stage", ("SCOPE", "DONE")))
                    self.msg_queue.put(("stage", ("PUSH", "RUNNING")))
                elif "[STAGE:COMPLETE]" in line_str:
                    self.msg_queue.put(("stage", ("PUSH", "DONE")))

                # Color-code tags
                tag = "NORMAL"
                if "[STAGE:" in line_str:
                    tag = "STAGE"
                elif "[INFO]" in line_str:
                    tag = "INFO"
                elif "[PASS]" in line_str:
                    tag = "PASS"
                elif "[WARN]" in line_str:
                    tag = "WARN"
                elif "[FAIL]" in line_str or "Error" in line_str:
                    tag = "FAIL"

                # Check for commit SHA
                m_commit = re.search(r"Changes successfully committed in worktree:\s*([a-f0-9]{40})", line_str)
                if m_commit:
                    self.latest_commit_sha = m_commit.group(1)
                    self.msg_queue.put(("commit_sha", self.latest_commit_sha))

                self.msg_queue.put(("log", (line_str, tag)))

            self.process.wait()
            rc = self.process.returncode

            if rc == 0:
                self.msg_queue.put(("execution_finished", (True, task_id)))
            else:
                self.msg_queue.put(("execution_finished", (False, f"Runner exited with code {rc}")))

        except Exception as e:
            self.msg_queue.put(("error", f"실행 중 예외 발생: {e}"))
            self.msg_queue.put(("execution_finished", (False, str(e))))

    def on_stop_clicked(self):
        if not self.is_running or not self.process:
            return
        if messagebox.askyesno("작업 중지", "현재 실행 중인 Antigravity 작업을 즉시 중지하시겠습니까?"):
            self._append_log("[WARN] 사용자에 의한 작업 중지 요청 수신...", "WARN")
            try:
                # Kill process tree
                subprocess.run(
                    ["taskkill", "/F", "/T", "/PID", str(self.process.pid)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                # Reset runner lock
                subprocess.run(
                    ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", RUNNER_PS1_PATH, "-Action", "ResetLock"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
                self._append_log("[WARN] 프로세스가 중지되었으며 실행 락이 안전하게 해제되었습니다.", "WARN")
                for s_key, _ in STAGES:
                    if self.stage_widgets[s_key]["status"].cget("text").startswith("🔄"):
                        self._set_stage_status(s_key, "STOPPED")
                self._set_ui_running(False, "중지됨 (STOPPED)", "#ffedd5", "#c2410c")
                self.lbl_result.config(text="작업이 사용자에 의해 중지되었습니다.")
            except Exception as e:
                self._append_log(f"[FAIL] 프로세스 종료 중 오류: {e}", "FAIL")

    # ==========================================================================
    # Queue Dispatcher (Thread-Safe UI Updates)
    # ==========================================================================
    def _process_queue(self):
        try:
            while True:
                msg_type, payload = self.msg_queue.get_nowait()
                if msg_type == "log":
                    text, tag = payload
                    self._append_log(text, tag)
                elif msg_type == "stage":
                    s_key, s_status = payload
                    self._set_stage_status(s_key, s_status)
                elif msg_type == "scan_done":
                    candidates, auto_run = payload
                    self._on_scan_done(candidates, auto_run)
                elif msg_type == "commit_sha":
                    self.latest_commit_sha = payload
                    self.btn_open_commit.config(state=tk.NORMAL)
                    self.lbl_result.config(text=f"신규 커밋 생성됨: {payload[:7]}")
                elif msg_type == "execution_finished":
                    success, detail = payload
                    self._on_execution_finished(success, detail)
                elif msg_type == "ui_done":
                    self._set_ui_running(payload)
                elif msg_type == "error":
                    self._append_log(f"[FAIL] {payload}", "FAIL")
                    messagebox.showerror("오류", payload)
        except queue.Empty:
            pass
        finally:
            self.root.after(40, self._process_queue)

    def _on_execution_finished(self, success, detail):
        self.is_running = False
        self.process = None

        if success:
            for s_key, _ in STAGES:
                self._set_stage_status(s_key, "DONE")
            self._update_badge("성공 완료 (SUCCESS)", "#dcfce7", "#15803d")
            commit_text = f" (Commit: {self.latest_commit_sha[:7]})" if self.latest_commit_sha else ""
            msg = f"✅ 작업 '{detail}'이(가) 성공적으로 완료되어 GitHub에 푸시되었습니다!{commit_text}"
            self.lbl_result.config(text=msg, foreground="#15803d")
            self._append_log(f"[PASS] {msg}", "PASS")
            if self.latest_commit_sha:
                self.btn_open_commit.config(state=tk.NORMAL)
            messagebox.showinfo("작업 완료", msg)
        else:
            self._update_badge("실패 (FAILED)", "#fee2e2", "#b91c1c")
            msg = f"❌ 작업 실행 실패: {detail}"
            self.lbl_result.config(text=msg, foreground="#b91c1c")
            self._append_log(f"[FAIL] {msg}", "FAIL")
            messagebox.showerror("실행 실패", f"작업 실행 중 오류가 발생했습니다.\n\n{detail}\n\n자세한 내용은 로그를 확인하세요.")

        self._set_ui_running(False)

    def _set_ui_running(self, running, badge_text="", bg_color="#e2e8f0", fg_color="#334155"):
        self.is_running = running
        if running:
            self.btn_run.config(state=tk.DISABLED, bg="#94a3b8")
            self.btn_scan.config(state=tk.DISABLED)
            self.btn_stop.config(state=tk.NORMAL, bg="#ef4444", fg="white")
            self.task_combobox.config(state=tk.DISABLED)
            if badge_text:
                self._update_badge(badge_text, bg_color, fg_color)
        else:
            self.btn_run.config(state=tk.NORMAL, bg="#107c41")
            self.btn_scan.config(state=tk.NORMAL)
            self.btn_stop.config(state=tk.DISABLED, bg="#e2e8f0", fg="#64748b")
            self.task_combobox.config(state="readonly")
            if badge_text:
                self._update_badge(badge_text, bg_color, fg_color)

    # ==========================================================================
    # Desktop Shortcut Creation
    # ==========================================================================
    def _create_desktop_shortcut(self):
        desktop = os.path.join(os.path.expanduser("~"), "Desktop")
        shortcut_path = os.path.join(desktop, "ProjectKnight 작업 실행.lnk")
        launcher_py = os.path.abspath(__file__)
        pythonw_exe = os.path.join(os.path.dirname(sys.executable), "pythonw.exe")
        if not os.path.exists(pythonw_exe):
            pythonw_exe = sys.executable

        # PowerShell script to create shortcut via WScript.Shell
        ps_code = f"""
        $wsh = New-Object -ComObject WScript.Shell
        $s = $wsh.CreateShortcut('{shortcut_path}')
        $s.TargetPath = '{pythonw_exe}'
        $s.Arguments = '"{launcher_py}"'
        $s.WorkingDirectory = '{DEFAULT_AUTOMATION_DIR}'
        $s.Description = 'ProjectKnight One-Click Automated Developer'
        $s.Save()
        """
        res = subprocess.run(["powershell.exe", "-NoProfile", "-Command", ps_code], capture_output=True, text=True)
        if res.returncode != 0:
            raise RuntimeError(res.stderr.strip())

# ==============================================================================
# Application Entry Point
# ==============================================================================
def main():
    root = tk.Tk()
    app = ProjectKnightLauncherApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()
