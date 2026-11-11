using System.Diagnostics;
using System.Text.RegularExpressions;
using ProjectKnight.Launcher.Models;
using ProjectKnight.Launcher.Services;

namespace ProjectKnight.Launcher;

public class MainForm : Form
{
    private const string AutomationBaseDir = @"D:\JUNYPAPA_STUDIO\Automation\ProjectKnight";
    private const string RepoPath = @"D:\JUNYPAPA_STUDIO\Projects\ProjectKnight";
    private const string WorktreePath = @"D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\worktree";
    private const string RunnerScriptPath = @"D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\runner.ps1";
    private const string StateFilePath = @"D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\state\tasks_state.json";
    private const string SettingsFilePath = @"D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\launcher_settings.json";

    private readonly TaskDiscoveryService _discoveryService;
    private readonly AutomationRunnerService _runnerService;
    private readonly LauncherSettings _settings;
    private readonly List<ExecutionStage> _stages;
    private readonly System.Windows.Forms.Timer _timer;

    private CancellationTokenSource? _cts;
    private List<TaskCandidate> _candidates = new();
    private TaskCandidate? _selectedCandidate;
    private string? _lastCommitSha;
    private string? _lastLogFilePath;
    private DateTime? _executionStartTime;

    // UI Controls
    private Label _lblStatusBadge = null!;
    private Button _btnMainAction = null!;
    private Button _btnRefresh = null!;
    private Button _btnRunSelected = null!;
    private Button _btnStop = null!;
    private CheckBox _chkAutoApprove = null!;
    private ComboBox _cboTasks = null!;
    private GroupBox _grpTaskDetails = null!;
    private Label _lblTaskDetails = null!;
    private TableLayoutPanel _stagePanel = null!;
    private Dictionary<string, (Label Name, Label Status, Label Elapsed)> _stageControls = new();
    private Label _lblTotalTimer = null!;
    private RichTextBox _rtbLog = null!;
    private CheckBox _chkAutoScroll = null!;
    private Button _btnCopyLog = null!;
    private Button _btnOpenLog = null!;
    private Button _btnOpenCommit = null!;
    private Button _btnInstallShortcut = null!;

    public MainForm()
    {
        Text = "ProjectKnight 자동 개발 실행기";
        Size = new Size(1080, 840);
        MinimumSize = new Size(950, 750);
        StartPosition = FormStartPosition.CenterScreen;
        Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);
        BackColor = Color.FromArgb(245, 247, 250);

        _settings = LauncherSettings.Load(SettingsFilePath);
        _discoveryService = new TaskDiscoveryService(RepoPath, StateFilePath);
        _runnerService = new AutomationRunnerService(RunnerScriptPath, WorktreePath);

        _stages = new List<ExecutionStage>
        {
            new("DISCOVER", "① 작업 탐색"),
            new("VALIDATE", "② 지시서 검증"),
            new("WORKTREE", "③ Worktree 준비"),
            new("EXECUTE",  "④ CLI 개발·테스트"),
            new("SCOPE",    "⑤ 범위 검증·커밋"),
            new("PUSH",     "⑥ GitHub Push")
        };

        _timer = new System.Windows.Forms.Timer { Interval = 1000 };
        _timer.Tick += (s, e) => UpdateTimerDisplay();

        InitializeComponent();
        ApplySettingsToUi();

        // Asynchronously scan for tasks on load
        Shown += async (s, e) => await RefreshCandidatesAsync();
    }

    private void InitializeComponent()
    {
        var mainLayout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 5,
            Padding = new Padding(16)
        };
        mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 50));  // Header
        mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 110)); // Actions & Options
        mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 115)); // Task Details
        mainLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 85));  // Stages
        mainLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100)); // Console

        // 1. Header
        var headerPanel = new Panel { Dock = DockStyle.Fill };
        var lblTitle = new Label
        {
            Text = "⚔️ ProjectKnight Antigravity 원클릭 실행기",
            Font = new Font("Segoe UI", 13f, FontStyle.Bold),
            ForeColor = Color.FromArgb(20, 30, 45),
            AutoSize = true,
            Location = new Point(0, 10)
        };
        _lblStatusBadge = new Label
        {
            Text = "대기 중 (Idle)",
            Font = new Font("Segoe UI", 9f, FontStyle.Bold),
            ForeColor = Color.White,
            BackColor = Color.FromArgb(90, 105, 120),
            AutoSize = true,
            Padding = new Padding(8, 4, 8, 4),
            Location = new Point(lblTitle.Right + 20, 10)
        };
        var lblEnv = new Label
        {
            Text = "Windows x64 | .NET 8/9 WinForms | Worktree 격리",
            Font = new Font("Segoe UI", 8.5f, FontStyle.Regular),
            ForeColor = Color.Gray,
            AutoSize = true,
            Anchor = AnchorStyles.Top | AnchorStyles.Right,
            Location = new Point(700, 14)
        };
        headerPanel.Controls.AddRange(new Control[] { lblTitle, _lblStatusBadge, lblEnv });

        // 2. Actions & Options
        var actionPanel = new Panel { Dock = DockStyle.Fill };
        _btnMainAction = new Button
        {
            Text = "🚀 GitHub 작업 가져와 실행",
            Font = new Font("Segoe UI", 11f, FontStyle.Bold),
            ForeColor = Color.White,
            BackColor = Color.FromArgb(24, 119, 242),
            FlatStyle = FlatStyle.Flat,
            Size = new Size(260, 48),
            Location = new Point(0, 5),
            Cursor = Cursors.Hand
        };
        _btnMainAction.FlatAppearance.BorderSize = 0;
        _btnMainAction.Click += async (s, e) => await OnMainActionClickAsync();

        _btnRefresh = new Button
        {
            Text = "🔄 새로고침",
            Font = new Font("Segoe UI", 9.5f, FontStyle.Regular),
            Size = new Size(110, 48),
            Location = new Point(270, 5),
            Cursor = Cursors.Hand
        };
        _btnRefresh.Click += async (s, e) => await RefreshCandidatesAsync();

        _btnRunSelected = new Button
        {
            Text = "▶ 선택 작업 실행",
            Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
            ForeColor = Color.White,
            BackColor = Color.FromArgb(40, 167, 69),
            FlatStyle = FlatStyle.Flat,
            Size = new Size(140, 48),
            Location = new Point(390, 5),
            Cursor = Cursors.Hand,
            Enabled = false
        };
        _btnRunSelected.FlatAppearance.BorderSize = 0;
        _btnRunSelected.Click += async (s, e) => await RunSelectedTaskAsync();

        _btnStop = new Button
        {
            Text = "⏹ 작업 중지",
            Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
            ForeColor = Color.White,
            BackColor = Color.FromArgb(220, 53, 69),
            FlatStyle = FlatStyle.Flat,
            Size = new Size(110, 48),
            Location = new Point(540, 5),
            Cursor = Cursors.Hand,
            Enabled = false
        };
        _btnStop.FlatAppearance.BorderSize = 0;
        _btnStop.Click += (s, e) => StopExecution();

        _chkAutoApprove = new CheckBox
        {
            Text = "자동 승인 (Auto-Approve)",
            Font = new Font("Segoe UI", 10f, FontStyle.Bold),
            AutoSize = true,
            Location = new Point(670, 16),
            Cursor = Cursors.Hand
        };
        _chkAutoApprove.CheckedChanged += (s, e) =>
        {
            _settings.AutoApprove = _chkAutoApprove.Checked;
            _settings.Save(SettingsFilePath);
            AppendLog("SYSTEM", $"[CONFIG] 자동 승인 모드가 {(_chkAutoApprove.Checked ? "ON (원클릭 자동 실행)" : "OFF (수동 확인 필요)")}으로 변경되었습니다.");
        };

        var lblAutoApproveDesc = new Label
        {
            Text = "※ ON 시: 「GitHub 작업 가져와 실행」 클릭 시 추가 확인 대화상자 없이 즉시 단일 검증 작업 실행 (기본값: OFF)",
            Font = new Font("Segoe UI", 8f),
            ForeColor = Color.DimGray,
            AutoSize = true,
            Location = new Point(670, 40)
        };

        var lblSelect = new Label
        {
            Text = "대상 작업 선택:",
            Font = new Font("Segoe UI", 9f, FontStyle.Bold),
            AutoSize = true,
            Location = new Point(0, 68)
        };
        _cboTasks = new ComboBox
        {
            DropDownStyle = ComboBoxStyle.DropDownList,
            Font = new Font("Consolas", 9.5f),
            Size = new Size(780, 28),
            Location = new Point(100, 65)
        };
        _cboTasks.SelectedIndexChanged += (s, e) => OnTaskSelectionChanged();

        actionPanel.Controls.AddRange(new Control[]
        {
            _btnMainAction, _btnRefresh, _btnRunSelected, _btnStop,
            _chkAutoApprove, lblAutoApproveDesc, lblSelect, _cboTasks
        });

        // 3. Task Details Panel
        _grpTaskDetails = new GroupBox
        {
            Text = "선택된 작업 세부 정보",
            Dock = DockStyle.Fill,
            Font = new Font("Segoe UI", 9f, FontStyle.Bold)
        };
        _lblTaskDetails = new Label
        {
            Dock = DockStyle.Fill,
            Font = new Font("Segoe UI", 9f, FontStyle.Regular),
            Text = "작업 목록을 조회하거나 선택하세요.",
            Padding = new Padding(8)
        };
        _grpTaskDetails.Controls.Add(_lblTaskDetails);

        // 4. Stages Panel
        var stageContainer = new Panel { Dock = DockStyle.Fill };
        _stagePanel = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            Height = 55,
            ColumnCount = 6,
            RowCount = 1
        };
        for (int i = 0; i < 6; i++)
        {
            _stagePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f / 6f));
        }

        foreach (var stage in _stages)
        {
            var pnl = new Panel
            {
                Dock = DockStyle.Fill,
                BorderStyle = BorderStyle.FixedSingle,
                BackColor = Color.White,
                Margin = new Padding(2)
            };
            var lblName = new Label
            {
                Text = stage.DisplayName,
                Font = new Font("Segoe UI", 8f, FontStyle.Bold),
                Dock = DockStyle.Top,
                TextAlign = ContentAlignment.MiddleCenter,
                Height = 20
            };
            var lblStatus = new Label
            {
                Text = "대기",
                Font = new Font("Segoe UI", 7.5f),
                ForeColor = Color.Gray,
                Dock = DockStyle.Top,
                TextAlign = ContentAlignment.MiddleCenter,
                Height = 16
            };
            var lblElapsed = new Label
            {
                Text = "",
                Font = new Font("Segoe UI", 7f),
                ForeColor = Color.DimGray,
                Dock = DockStyle.Bottom,
                TextAlign = ContentAlignment.MiddleCenter,
                Height = 14
            };
            pnl.Controls.AddRange(new Control[] { lblElapsed, lblStatus, lblName });
            _stagePanel.Controls.Add(pnl);
            _stageControls[stage.Key] = (lblName, lblStatus, lblElapsed);
        }

        _lblTotalTimer = new Label
        {
            Text = "소요 시간: 00:00",
            Font = new Font("Consolas", 8.5f, FontStyle.Bold),
            ForeColor = Color.DimGray,
            AutoSize = true,
            Dock = DockStyle.Bottom
        };
        stageContainer.Controls.AddRange(new Control[] { _stagePanel, _lblTotalTimer });

        // 5. Console & Toolbar
        var consolePanel = new Panel { Dock = DockStyle.Fill };
        _rtbLog = new RichTextBox
        {
            Dock = DockStyle.Fill,
            BackColor = Color.FromArgb(28, 28, 28),
            ForeColor = Color.FromArgb(220, 220, 220),
            Font = new Font("Consolas", 9.5f),
            ReadOnly = true,
            BorderStyle = BorderStyle.None,
            ScrollBars = RichTextBoxScrollBars.Vertical
        };

        var bottomToolbar = new FlowLayoutPanel
        {
            Dock = DockStyle.Bottom,
            Height = 36,
            FlowDirection = FlowDirection.LeftToRight,
            Padding = new Padding(0, 4, 0, 0)
        };
        _chkAutoScroll = new CheckBox
        {
            Text = "자동 스크롤",
            Checked = true,
            AutoSize = true,
            Margin = new Padding(0, 6, 12, 0)
        };
        _btnCopyLog = new Button { Text = "📋 로그 복사", AutoSize = true };
        _btnCopyLog.Click += (s, e) => CopyLogToClipboard();

        _btnOpenLog = new Button { Text = "📂 로그 파일 열기", AutoSize = true, Enabled = false };
        _btnOpenLog.Click += (s, e) => OpenLogFile();

        _btnOpenCommit = new Button { Text = "🔗 GitHub 커밋 보기", AutoSize = true, Enabled = false };
        _btnOpenCommit.Click += (s, e) => OpenGitHubCommit();

        _btnInstallShortcut = new Button { Text = "📌 바탕화면 바로가기 등록", AutoSize = true };
        _btnInstallShortcut.Click += (s, e) => InstallDesktopShortcut();

        bottomToolbar.Controls.AddRange(new Control[]
        {
            _chkAutoScroll, _btnCopyLog, _btnOpenLog, _btnOpenCommit, _btnInstallShortcut
        });

        consolePanel.Controls.Add(_rtbLog);
        consolePanel.Controls.Add(bottomToolbar);

        mainLayout.Controls.Add(headerPanel, 0, 0);
        mainLayout.Controls.Add(actionPanel, 0, 1);
        mainLayout.Controls.Add(_grpTaskDetails, 0, 2);
        mainLayout.Controls.Add(stageContainer, 0, 3);
        mainLayout.Controls.Add(consolePanel, 0, 4);

        Controls.Add(mainLayout);
    }

    private void ApplySettingsToUi()
    {
        _chkAutoApprove.Checked = _settings.AutoApprove;
        _chkAutoScroll.Checked = _settings.AutoScrollLog;
    }

    private async Task RefreshCandidatesAsync()
    {
        SetUiBusy(true, "작업 목록 조회 중...");
        AppendLog("SYSTEM", "[DISCOVERY] GitHub 원격 브랜치 및 STUDIO_V3/tasks 지시서 목록 조회 중...");

        try
        {
            _candidates = await _discoveryService.DiscoverCandidatesAsync();
            _cboTasks.Items.Clear();

            foreach (var c in _candidates)
            {
                _cboTasks.Items.Add(c);
            }

            if (_candidates.Count > 0)
            {
                // Restore previous selection if possible, otherwise first non-completed item
                int targetIdx = 0;
                if (!string.IsNullOrEmpty(_settings.LastSelectedTaskId))
                {
                    var found = _candidates.FindIndex(c => c.TaskId.Equals(_settings.LastSelectedTaskId, StringComparison.OrdinalIgnoreCase));
                    if (found >= 0) targetIdx = found;
                }
                else
                {
                    var firstIncomplete = _candidates.FindIndex(c => !c.IsCompleted && c.IsValid);
                    if (firstIncomplete >= 0) targetIdx = firstIncomplete;
                }

                _cboTasks.SelectedIndex = targetIdx;
                AppendLog("SYSTEM", $"[DISCOVERY] 총 {_candidates.Count}개 작업 발견 (미완료: {_candidates.Count(c => !c.IsCompleted && c.IsValid)}개).");
            }
            else
            {
                _selectedCandidate = null;
                _lblTaskDetails.Text = "조회 가능한 GitHub 작업지시서가 없습니다.";
                _btnRunSelected.Enabled = false;
                AppendLog("WARN", "[DISCOVERY] 조회된 유효 작업지시서가 없습니다.");
            }
        }
        catch (Exception ex)
        {
            AppendLog("ERROR", $"[DISCOVERY FAILED] {ex.Message}");
            MessageBox.Show($"작업 목록 조회 중 오류가 발생했습니다:\n{ex.Message}", "조회 오류", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            SetUiBusy(false, "대기 중 (Idle)");
        }
    }

    private void OnTaskSelectionChanged()
    {
        if (_cboTasks.SelectedItem is TaskCandidate candidate)
        {
            _selectedCandidate = candidate;
            _settings.LastSelectedTaskId = candidate.TaskId;
            _settings.Save(SettingsFilePath);

            var statusStr = candidate.IsCompleted ? "✅ 완료됨 (COMPLETED)" : (candidate.IsValid ? "🟢 대기 중 (READY)" : $"❌ 오류: {candidate.ErrorMessage}");
            _lblTaskDetails.Text = $"Task ID: {candidate.TaskId}   |   브랜치: {candidate.Branch}   |   원격 SHA: {candidate.ShortSha}\n" +
                                   $"제목: {candidate.Title}\n" +
                                   $"상태: {statusStr}\n" +
                                   $"개요: {candidate.Summary}";

            _btnRunSelected.Enabled = candidate.IsValid && !candidate.IsCompleted;
        }
        else
        {
            _selectedCandidate = null;
            _lblTaskDetails.Text = "작업을 선택하세요.";
            _btnRunSelected.Enabled = false;
        }
    }

    private async Task OnMainActionClickAsync()
    {
        // 1. If no candidates, refresh first
        if (_candidates.Count == 0)
        {
            await RefreshCandidatesAsync();
            if (_candidates.Count == 0) return;
        }

        // 2. Identify candidate: if multiple candidates, require explicit user selection
        var eligibleCandidates = _candidates.Where(c => !c.IsCompleted && c.IsValid).ToList();
        if (eligibleCandidates.Count == 0)
        {
            MessageBox.Show("실행할 수 있는 미완료 작업이 없습니다. 모든 작업이 완료되었거나 메타데이터에 오류가 있습니다.", "알림", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        TaskCandidate? candidateToRun = null;
        if (_selectedCandidate != null && !_selectedCandidate.IsCompleted && _selectedCandidate.IsValid)
        {
            candidateToRun = _selectedCandidate;
        }
        else if (eligibleCandidates.Count == 1)
        {
            candidateToRun = eligibleCandidates[0];
            _cboTasks.SelectedItem = candidateToRun;
        }
        else
        {
            // Multiple eligible candidates and none explicitly chosen -> do NOT pick first automatically
            MessageBox.Show(
                $"미완료 작업 {eligibleCandidates.Count}건이 대기 중입니다.\n\n" +
                "안전한 개발 진행을 위해 상단 '작업 선택' 목록에서 실행할 작업을 먼저 선택해 주세요.",
                "작업 선택 필요",
                MessageBoxButtons.OK,
                MessageBoxIcon.Information);
            _cboTasks.Focus();
            return;
        }

        // 3. User Confirmation Gate
        if (!_chkAutoApprove.Checked)
        {
            var promptResult = MessageBox.Show(
                $"다음 작업을 격리 Worktree에서 개발·테스트 실행하시겠습니까?\n\n" +
                $" - Task ID: {candidateToRun.TaskId}\n" +
                $" - 제목: {candidateToRun.Title}\n" +
                $" - 대상 브랜치: {candidateToRun.Branch}\n" +
                $" - 원격 SHA: {candidateToRun.ShortSha}",
                "작업 실행 확인",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);

            if (promptResult != DialogResult.Yes) return;
        }
        else
        {
            AppendLog("SYSTEM", $"[AUTO-APPROVE] 자동 승인 옵션에 따라 작업 {candidateToRun.TaskId}을(를) 추가 확인 없이 실행합니다.");
        }

        await ExecuteTaskInternalAsync(candidateToRun);
    }

    private async Task RunSelectedTaskAsync()
    {
        if (_selectedCandidate == null) return;

        if (!_chkAutoApprove.Checked)
        {
            var promptResult = MessageBox.Show(
                $"선택된 작업 '{_selectedCandidate.TaskId}'을(를) 실행하시겠습니까?\n\n" +
                $" - 브랜치: {_selectedCandidate.Branch}\n" +
                $" - 커밋 SHA: {_selectedCandidate.ShortSha}",
                "선택 작업 실행",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);

            if (promptResult != DialogResult.Yes) return;
        }

        await ExecuteTaskInternalAsync(_selectedCandidate);
    }

    private async Task ExecuteTaskInternalAsync(TaskCandidate candidate)
    {
        SetUiRunning(true, $"실행 중: {candidate.TaskId}");
        ResetStages();
        _executionStartTime = DateTime.Now;
        _timer.Start();

        _cts = new CancellationTokenSource();
        _lastCommitSha = null;
        _lastLogFilePath = null;
        _btnOpenLog.Enabled = false;
        _btnOpenCommit.Enabled = false;

        AppendLog("STAGE", $"==================================================");
        AppendLog("STAGE", $"[START] Task {candidate.TaskId} 자동 개발 파이프라인 착수");
        AppendLog("STAGE", $" - 대상 브랜치: {candidate.Branch}");
        AppendLog("STAGE", $" - 예상 SHA: {candidate.CommitSha}");
        AppendLog("STAGE", $" - 격리 Worktree: {WorktreePath}");
        AppendLog("STAGE", $"==================================================");

        var logProgress = new Progress<LogEntry>(entry =>
        {
            AppendLog(entry.Stream, entry.Text);
        });

        var stageProgress = new Progress<StageTransition>(st =>
        {
            UpdateStage(st.StageKey, st.Status, st.Message);
        });

        try
        {
            var result = await _runnerService.ExecuteTaskAsync(
                candidate,
                _chkAutoApprove.Checked,
                logProgress,
                stageProgress,
                _cts.Token);

            _timer.Stop();
            UpdateTimerDisplay();

            _lastCommitSha = result.CommitSha;
            _lastLogFilePath = result.LogFilePath;
            if (!string.IsNullOrEmpty(_lastLogFilePath)) _btnOpenLog.Enabled = true;
            if (!string.IsNullOrEmpty(_lastCommitSha)) _btnOpenCommit.Enabled = true;

            if (result.Success && result.FinalStatus == "COMPLETED")
            {
                SetUiRunning(false, "완료 (COMPLETED)", Color.FromArgb(40, 167, 69));
                AppendLog("PASS", $"[COMPLETED] Task {candidate.TaskId} 개발·테스트·커밋·Push 완료!");
                AppendLog("PASS", $" - 커밋 SHA: {result.CommitSha ?? "N/A"}");
                AppendLog("PASS", $" - 최종 상태: {result.FinalStatus}");
                AppendLog("PASS", $" - 총 소요 시간: {result.Duration.TotalSeconds:F1}초");

                MessageBox.Show(
                    $"Task {candidate.TaskId} 개발 및 반영이 성공적으로 완료되었습니다!\n\n" +
                    $"커밋 SHA: {result.CommitSha}\n" +
                    $"상태: {result.FinalStatus}\n" +
                    $"소요 시간: {result.Duration.TotalSeconds:F1}초",
                    "실행 완료",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);

                // Refresh candidate list to reflect completion
                await RefreshCandidatesAsync();
            }
            else if (result.FinalStatus == "NO_CHANGES" || result.FinalStatus == "PUSH_SKIPPED")
            {
                SetUiRunning(false, $"종료 ({result.FinalStatus})", Color.FromArgb(255, 193, 7));
                AppendLog("WARN", $"[{result.FinalStatus}] Task {candidate.TaskId} 실행 종료 (상태: {result.FinalStatus})");

                MessageBox.Show(
                    $"Task {candidate.TaskId} 실행이 종료되었으나 변경 사항이 없거나 Push가 생략되었습니다.\n\n" +
                    $"상태: {result.FinalStatus}\n" +
                    $"커밋 SHA: {result.CommitSha ?? "N/A"}",
                    "알림",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning);
            }
            else
            {
                SetUiRunning(false, $"실패 ({result.FinalStatus})", Color.FromArgb(220, 53, 69));
                AppendLog("ERROR", $"[FAILED] Task {candidate.TaskId} 실행 실패: {result.ErrorMessage}");

                MessageBox.Show(
                    $"Task {candidate.TaskId} 실행 중 오류가 발생했습니다.\n\n" +
                    $"오류 내용: {result.ErrorMessage}\n\n" +
                    $"하단 콘솔 로그를 확인하세요.",
                    "실행 실패",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            }
        }
        catch (OperationCanceledException)
        {
            _timer.Stop();
            SetUiRunning(false, "중지됨 (Cancelled)", Color.FromArgb(255, 193, 7));
            AppendLog("WARN", $"[CANCELLED] 사용자에 의해 실행이 중지되었습니다.");
        }
        catch (Exception ex)
        {
            _timer.Stop();
            SetUiRunning(false, "오류 (Error)", Color.FromArgb(220, 53, 69));
            AppendLog("ERROR", $"[EXCEPTION] {ex.Message}");
        }
        finally
        {
            _cts?.Dispose();
            _cts = null;
        }
    }

    private void StopExecution()
    {
        if (_cts != null && !_cts.IsCancellationRequested)
        {
            var res = MessageBox.Show("실행 중인 Antigravity 개발 작업을 안전하게 중지하시겠습니까?", "작업 중지 확인", MessageBoxButtons.YesNo, MessageBoxIcon.Warning);
            if (res == DialogResult.Yes)
            {
                AppendLog("WARN", "[STOP] 작업 중지 요청을 전송했습니다...");
                _cts.Cancel();
            }
        }
    }

    private void ResetStages()
    {
        foreach (var stage in _stages)
        {
            stage.Reset();
            if (_stageControls.TryGetValue(stage.Key, out var ctrl))
            {
                if (ctrl.Name.Parent != null) ctrl.Name.Parent.BackColor = Color.White;
                ctrl.Status.Text = "대기";
                ctrl.Status.ForeColor = Color.Gray;
                ctrl.Elapsed.Text = "";
            }
        }
    }

    private void UpdateStage(string key, StageStatus status, string message)
    {
        var stage = _stages.FirstOrDefault(s => s.Key.Equals(key, StringComparison.OrdinalIgnoreCase));
        if (stage == null) return;

        if (status == StageStatus.Running)
        {
            stage.Start();
        }
        else if (status == StageStatus.Passed || status == StageStatus.Failed)
        {
            stage.Complete(status == StageStatus.Passed, message);
        }

        if (_stageControls.TryGetValue(stage.Key, out var ctrl))
        {
            if (ctrl.Name.Parent != null)
            {
                switch (status)
                {
                    case StageStatus.Running:
                        ctrl.Name.Parent.BackColor = Color.FromArgb(235, 243, 254);
                        ctrl.Status.Text = "진행 중...";
                        ctrl.Status.ForeColor = Color.FromArgb(24, 119, 242);
                        break;
                    case StageStatus.Passed:
                        ctrl.Name.Parent.BackColor = Color.FromArgb(235, 250, 238);
                        ctrl.Status.Text = "✓ 완료";
                        ctrl.Status.ForeColor = Color.FromArgb(40, 167, 69);
                        break;
                    case StageStatus.Failed:
                        ctrl.Name.Parent.BackColor = Color.FromArgb(254, 238, 238);
                        ctrl.Status.Text = "✗ 실패";
                        ctrl.Status.ForeColor = Color.FromArgb(220, 53, 69);
                        break;
                }
            }
            if (stage.Elapsed > TimeSpan.Zero)
            {
                ctrl.Elapsed.Text = $"{stage.Elapsed.TotalSeconds:F0}s";
            }
        }
    }

    private void UpdateTimerDisplay()
    {
        if (_executionStartTime.HasValue)
        {
            var total = DateTime.Now - _executionStartTime.Value;
            _lblTotalTimer.Text = $"소요 시간: {total.Minutes:D2}:{total.Seconds:D2}";
        }
    }

    private void SetUiBusy(bool busy, string statusText)
    {
        _lblStatusBadge.Text = statusText;
        _btnMainAction.Enabled = !busy;
        _btnRefresh.Enabled = !busy;
        _cboTasks.Enabled = !busy;
    }

    private void SetUiRunning(bool running, string statusText, Color? badgeColor = null)
    {
        _lblStatusBadge.Text = statusText;
        _lblStatusBadge.BackColor = badgeColor ?? (running ? Color.FromArgb(24, 119, 242) : Color.FromArgb(90, 105, 120));

        _btnMainAction.Enabled = !running;
        _btnRefresh.Enabled = !running;
        _btnRunSelected.Enabled = !running && _selectedCandidate != null && _selectedCandidate.IsValid && !_selectedCandidate.IsCompleted;
        _btnStop.Enabled = running;
        _cboTasks.Enabled = !running;
        _chkAutoApprove.Enabled = !running;
    }

    private void AppendLog(string stream, string text)
    {
        if (InvokeRequired)
        {
            BeginInvoke(new Action(() => AppendLog(stream, text)));
            return;
        }

        Color color = Color.FromArgb(220, 220, 220); // Default

        if (stream.Equals("stderr", StringComparison.OrdinalIgnoreCase) || text.Contains("[ERR") || text.Contains("failed") || text.Contains("Exception"))
        {
            color = Color.FromArgb(244, 71, 71); // Red
        }
        else if (text.Contains("[STAGE:") || stream.Equals("STAGE", StringComparison.OrdinalIgnoreCase))
        {
            color = Color.FromArgb(197, 134, 192); // Purple
        }
        else if (text.Contains("[PASS]") || stream.Equals("PASS", StringComparison.OrdinalIgnoreCase))
        {
            color = Color.FromArgb(181, 206, 168); // Green
        }
        else if (text.Contains("[WARN]") || stream.Equals("WARN", StringComparison.OrdinalIgnoreCase))
        {
            color = Color.FromArgb(220, 220, 170); // Yellow
        }
        else if (text.Contains("[INFO]") || text.Contains("[HEARTBEAT]") || stream.Equals("SYSTEM", StringComparison.OrdinalIgnoreCase))
        {
            color = Color.FromArgb(78, 201, 176); // Cyan
        }

        _rtbLog.SelectionStart = _rtbLog.TextLength;
        _rtbLog.SelectionLength = 0;
        _rtbLog.SelectionColor = color;
        _rtbLog.AppendText(text + Environment.NewLine);
        _rtbLog.SelectionColor = _rtbLog.ForeColor;

        if (_chkAutoScroll.Checked)
        {
            _rtbLog.ScrollToCaret();
        }
    }

    private void CopyLogToClipboard()
    {
        try
        {
            if (!string.IsNullOrEmpty(_rtbLog.Text))
            {
                Clipboard.SetText(_rtbLog.Text);
                MessageBox.Show("콘솔 로그가 클립보드에 복사되었습니다.", "복사 완료", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show($"클립보드 복사 실패: {ex.Message}", "오류", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }

    private void OpenLogFile()
    {
        if (!string.IsNullOrEmpty(_lastLogFilePath) && File.Exists(_lastLogFilePath))
        {
            Process.Start(new ProcessStartInfo("notepad.exe", $"\"{_lastLogFilePath}\"") { UseShellExecute = true });
        }
        else
        {
            MessageBox.Show("로그 파일 경로를 찾을 수 없습니다.", "알림", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }

    private void OpenGitHubCommit()
    {
        if (!string.IsNullOrEmpty(_lastCommitSha))
        {
            var url = $"https://github.com/jjangmut/ProjectKnight/commit/{_lastCommitSha}";
            Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
        }
    }

    private void InstallDesktopShortcut()
    {
        var exePath = Application.ExecutablePath;
        var ok = DesktopShortcutService.CreateOrUpdateShortcut(exePath);
        if (ok)
        {
            MessageBox.Show($"바탕화면 바로가기가 성공적으로 등록되었습니다:\n\n{DesktopShortcutService.ShortcutPath}\n\n-> {exePath}", "바로가기 등록 완료", MessageBoxButtons.OK, MessageBoxIcon.Information);
            AppendLog("PASS", $"[SHORTCUT] 바탕화면 바로가기 등록 완료: {DesktopShortcutService.ShortcutPath}");
        }
        else
        {
            MessageBox.Show("바탕화면 바로가기 등록에 실패했습니다.", "오류", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }
    }
}
