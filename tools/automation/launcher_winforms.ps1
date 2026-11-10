# ==============================================================================
# ProjectKnight WinForms Developer Launcher
# Location: tools/automation/launcher_winforms.ps1
# Description: C# / PowerShell Windows Forms GUI Launcher for Antigravity automated tasks.
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$HeadlessTest = $false,
    [string]$TestTaskId = ""
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$AutomationDir = "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight"
$RepoPath = "D:\JUNYPAPA_STUDIO\Projects\ProjectKnight"
$WorktreePath = "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\worktree"
$RunnerPath = Join-Path $AutomationDir "runner.ps1"
$StatePath = Join-Path $AutomationDir "state\tasks_state.json"
$SettingsPath = Join-Path $AutomationDir "launcher_settings.json"

$ForbiddenBranches = @("main", "master", "integration", "HEAD", "task/art-stage-batch-001")
$ProtectedTaskIds = @("V3-017", "v3-017")

# 1. Settings Loader
function Load-LauncherSettings {
    if (Test-Path $SettingsPath) {
        try {
            return Get-Content $SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {}
    }
    return [PSCustomObject]@{
        auto_approve = $false
        last_selected_task_id = $null
        auto_scroll_log = $true
    }
}

function Save-LauncherSettings ($settingsObj) {
    try {
        $json = $settingsObj | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($SettingsPath, $json, [System.Text.Encoding]::UTF8)
    } catch {}
}

# 2. Task Discovery Service
function Get-TaskCandidates {
    $candidates = @()

    $completedTasks = @{}
    if (Test-Path $StatePath) {
        try {
            $stateJson = Get-Content $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $stateJson.completed_tasks) {
                foreach ($prop in $stateJson.completed_tasks.PSObject.Properties) {
                    $completedTasks[$prop.Name] = $prop.Value
                }
            }
        } catch {}
    }

    $rawRefs = git -C $RepoPath for-each-ref --format="%(refname:short)|%(objectname)" refs/remotes/origin/ 2>$null
    if ($null -eq $rawRefs) { return $candidates }

    $seenKeys = @{}

    foreach ($line in ($rawRefs -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line.Split('|')
        if ($parts.Length -lt 2) { continue }

        $fullBranch = $parts[0].Trim()
        $commitSha = $parts[1].Trim()

        if (-not $fullBranch.StartsWith("origin/")) { continue }
        $branch = $fullBranch.Substring("origin/".Length)

        if ($ForbiddenBranches -contains $branch) { continue }
        if (-not ($branch.StartsWith("studio/v3-") -or $branch.StartsWith("test/v3-"))) { continue }

        $leaf = Split-Path -Leaf $branch
        $taskId = ""
        if ($leaf -match '^(v3-\d{3})') {
            $taskId = $matches[1].ToUpperInvariant()
        } elseif ($leaf -eq "v3-test-automation") {
            $taskId = "V3-TEST-AUTOMATION"
        } elseif ($leaf -like "*winforms-rebuild*") {
            $taskId = "AUTOMATION-005"
        } elseif ($leaf -like "*oneclick-launcher*") {
            $taskId = "AUTOMATION-004"
        } elseif ($leaf -match '^(automation-\d{3})') {
            $taskId = $matches[1].ToUpperInvariant()
        }

        if ([string]::IsNullOrWhiteSpace($taskId)) { continue }
        if ($ProtectedTaskIds -contains $taskId) { continue }

        $specRaw = git -C $RepoPath show "origin/${branch}:STUDIO_V3/tasks/${taskId}.md" 2>$null
        if ($null -eq $specRaw -or $specRaw.Count -eq 0) { continue }
        $spec = ($specRaw -join "`n")
        if ([string]::IsNullOrWhiteSpace($spec)) { continue }

        $title = $taskId
        if ($spec -match '(?m)^#\s+(?<header>[^\r\n]+)') {
            $rawHeader = $matches['header'].Trim()
            $cleanTitle = $rawHeader -replace '^[-A-Za-z0-9_]+\s*[-—:]\s*', ''
            if (-not [string]::IsNullOrWhiteSpace($cleanTitle)) {
                $title = $cleanTitle
            } else {
                $title = $rawHeader
            }
        }

        $isValid = $true
        $errMsg = $null
        if ($spec -match '(?im)\*{0,2}(?:Target Branch|Branch):\*{0,2}\s*`?([a-zA-Z0-9_\-\/]+)`?') {
            $declaredBranch = $matches[1].Trim()
            if ($declaredBranch -ne $branch) {
                $isValid = $false
                $errMsg = "선언 브랜치 불일치: 지시서('$declaredBranch') vs 원격('$branch')"
            }
        } else {
            $isValid = $false
            $errMsg = "지시서 내 Target Branch 메타데이터 부재"
        }

        $summary = $title
        if ($spec -match '(?ims)(?:##\s*(?:목적|Task Objective|Objective|Purpose|개요|1\.\s*결정사항)[^\r\n]*)(.*?)(?:\n##|\Z)') {
            $cleanSummary = $matches[1].Trim() -replace '\r?\n+', ' '
            if ($cleanSummary.Length -gt 150) {
                $summary = $cleanSummary.Substring(0, 150) + '...'
            } else {
                $summary = $cleanSummary
            }
        }
        $isCompleted = $completedTasks.ContainsKey($taskId)
        $status = if ($isCompleted) { "COMPLETED" } elseif ($isValid) { "READY" } else { "INVALID" }

        $uniqueKey = "$taskId@$branch@$commitSha"
        if (-not $seenKeys.ContainsKey($uniqueKey)) {
            $seenKeys[$uniqueKey] = $true
            $shortSha = if ($commitSha.Length -gt 8) { $commitSha.Substring(0, 8) } else { $commitSha }
            $badge = if ($isCompleted) { "[완료]" } elseif ($isValid) { "[대기]" } else { "[오류]" }
            $display = "{0} {1} | {2} ({3}) - {4}" -f $badge, $taskId, $branch, $shortSha, $title

            $candidates += [PSCustomObject]@{
                TaskId = $taskId
                Title = $title
                Branch = $branch
                CommitSha = $commitSha
                ShortSha = $shortSha
                Summary = $summary
                IsCompleted = $isCompleted
                IsValid = $isValid
                Status = $status
                ErrorMessage = $errMsg
                DisplayText = $display
            }
        }
    }

    return $candidates | Sort-Object IsCompleted, { -not $_.IsValid }, { $_.TaskId }
}

# 3. Headless Test Mode
if ($HeadlessTest) {
    Write-Host "`[HEADLESS TEST`] Running WinForms Launcher Verification..." -ForegroundColor Cyan
    $settings = Load-LauncherSettings
    Write-Host "  -> Settings loaded. AutoApprove: $($settings.auto_approve)"
    $tasks = Get-TaskCandidates
    Write-Host "  -> Discovered task candidates count: $($tasks.Count)"
    foreach ($t in $tasks) {
        Write-Host "     - $($t.DisplayText)"
    }
    if ($tasks.Count -gt 0) {
        Write-Host "`[HEADLESS TEST`] Task candidate discovery PASS." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`[HEADLESS TEST`] No candidates found." -ForegroundColor Yellow
        exit 1
    }
}

# 4. GUI Implementation (Windows Forms)
[System.Windows.Forms.Application]::EnableVisualStyles()
$settings = Load-LauncherSettings

$form = New-Object System.Windows.Forms.Form
$form.Text = "ProjectKnight 자동 개발 실행기 (WinForms)"
$form.Size = New-Object System.Drawing.Size(1080, 840)
$form.MinimumSize = New-Object System.Drawing.Size(950, 750)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)

$layout = New-Object System.Windows.Forms.TableLayoutPanel
$layout.Dock = [System.Windows.Forms.DockStyle]::Fill
$layout.ColumnCount = 1
$layout.RowCount = 5
$layout.Padding = New-Object System.Windows.Forms.Padding(16)
[void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50)))
[void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 115)))
[void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 115)))
[void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 85)))
[void]$layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))

# Header
$headerPnl = New-Object System.Windows.Forms.Panel
$headerPnl.Dock = [System.Windows.Forms.DockStyle]::Fill
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "⚔️ ProjectKnight Antigravity 원클릭 실행기 (WinForms)"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12.5, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(20, 30, 45)
$lblTitle.AutoSize = $true
$lblTitle.Location = New-Object System.Drawing.Point(0, 10)

$lblBadge = New-Object System.Windows.Forms.Label
$lblBadge.Text = "대기 중 (Idle)"
$lblBadge.Font = New-Object System.Drawing.Font("Segoe UI", 9.0, [System.Drawing.FontStyle]::Bold)
$lblBadge.ForeColor = [System.Drawing.Color]::White
$lblBadge.BackColor = [System.Drawing.Color]::FromArgb(90, 105, 120)
$lblBadge.AutoSize = $true
$lblBadge.Padding = New-Object System.Windows.Forms.Padding(8, 4, 8, 4)
$lblBadge.Location = New-Object System.Drawing.Point(520, 10)
$headerPnl.Controls.AddRange(@($lblTitle, $lblBadge))

# Actions
$actionPnl = New-Object System.Windows.Forms.Panel
$actionPnl.Dock = [System.Windows.Forms.DockStyle]::Fill

$btnMain = New-Object System.Windows.Forms.Button
$btnMain.Text = "🚀 GitHub 작업 가져와 실행"
$btnMain.Font = New-Object System.Drawing.Font("Segoe UI", 11.0, [System.Drawing.FontStyle]::Bold)
$btnMain.ForeColor = [System.Drawing.Color]::White
$btnMain.BackColor = [System.Drawing.Color]::FromArgb(24, 119, 242)
$btnMain.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnMain.FlatAppearance.BorderSize = 0
$btnMain.Size = New-Object System.Drawing.Size(260, 48)
$btnMain.Location = New-Object System.Drawing.Point(0, 5)
$btnMain.Cursor = [System.Windows.Forms.Cursors]::Hand

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "🔄 새로고침"
$btnRefresh.Size = New-Object System.Drawing.Size(110, 48)
$btnRefresh.Location = New-Object System.Drawing.Point(270, 5)
$btnRefresh.Cursor = [System.Windows.Forms.Cursors]::Hand

$btnRunSelected = New-Object System.Windows.Forms.Button
$btnRunSelected.Text = "▶ 선택 작업 실행"
$btnRunSelected.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnRunSelected.ForeColor = [System.Drawing.Color]::White
$btnRunSelected.BackColor = [System.Drawing.Color]::FromArgb(40, 167, 69)
$btnRunSelected.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnRunSelected.FlatAppearance.BorderSize = 0
$btnRunSelected.Size = New-Object System.Drawing.Size(140, 48)
$btnRunSelected.Location = New-Object System.Drawing.Point(390, 5)
$btnRunSelected.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnRunSelected.Enabled = $false

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "⏹ 작업 중지"
$btnStop.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$btnStop.ForeColor = [System.Drawing.Color]::White
$btnStop.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
$btnStop.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnStop.FlatAppearance.BorderSize = 0
$btnStop.Size = New-Object System.Drawing.Size(110, 48)
$btnStop.Location = New-Object System.Drawing.Point(540, 5)
$btnStop.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnStop.Enabled = $false

$chkAutoApprove = New-Object System.Windows.Forms.CheckBox
$chkAutoApprove.Text = "자동 승인 (Auto-Approve)"
$chkAutoApprove.Font = New-Object System.Drawing.Font("Segoe UI", 10.0, [System.Drawing.FontStyle]::Bold)
$chkAutoApprove.AutoSize = $true
$chkAutoApprove.Location = New-Object System.Drawing.Point(670, 14)
$chkAutoApprove.Checked = [bool]$settings.auto_approve

$lblAutoDesc = New-Object System.Windows.Forms.Label
$lblAutoDesc.Text = "※ ON 시: 「GitHub 작업 가져와 실행」 클릭 시 2차 팝업 없이 즉시 단일 검증 작업 실행 (기본: OFF)"
$lblAutoDesc.Font = New-Object System.Drawing.Font("Segoe UI", 8.0)
$lblAutoDesc.ForeColor = [System.Drawing.Color]::DimGray
$lblAutoDesc.AutoSize = $true
$lblAutoDesc.Location = New-Object System.Drawing.Point(670, 38)

$lblCbo = New-Object System.Windows.Forms.Label
$lblCbo.Text = "대상 작업 선택:"
$lblCbo.Font = New-Object System.Drawing.Font("Segoe UI", 9.0, [System.Drawing.FontStyle]::Bold)
$lblCbo.AutoSize = $true
$lblCbo.Location = New-Object System.Drawing.Point(0, 72)

$cboTasks = New-Object System.Windows.Forms.ComboBox
$cboTasks.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cboTasks.Font = New-Object System.Drawing.Font("Consolas", 9.5)
$cboTasks.Size = New-Object System.Drawing.Size(780, 28)
$cboTasks.Location = New-Object System.Drawing.Point(105, 68)

$actionPnl.Controls.AddRange(@(
    $btnMain, $btnRefresh, $btnRunSelected, $btnStop,
    $chkAutoApprove, $lblAutoDesc, $lblCbo, $cboTasks
))

# Details
$grpDetails = New-Object System.Windows.Forms.GroupBox
$grpDetails.Text = "선택된 작업 세부 정보"
$grpDetails.Dock = [System.Windows.Forms.DockStyle]::Fill
$grpDetails.Font = New-Object System.Drawing.Font("Segoe UI", 9.0, [System.Drawing.FontStyle]::Bold)

$lblDetails = New-Object System.Windows.Forms.Label
$lblDetails.Dock = [System.Windows.Forms.DockStyle]::Fill
$lblDetails.Font = New-Object System.Drawing.Font("Segoe UI", 9.0, [System.Drawing.FontStyle]::Regular)
$lblDetails.Text = "작업 목록을 새로고침하거나 선택하세요."
$lblDetails.Padding = New-Object System.Windows.Forms.Padding(8)
$grpDetails.Controls.Add($lblDetails)

# Stages
$stageContainer = New-Object System.Windows.Forms.Panel
$stageContainer.Dock = [System.Windows.Forms.DockStyle]::Fill

$stagePnl = New-Object System.Windows.Forms.TableLayoutPanel
$stagePnl.Dock = [System.Windows.Forms.DockStyle]::Top
$stagePnl.Height = 55
$stagePnl.ColumnCount = 6
$stagePnl.RowCount = 1
for ($i = 0; $i -lt 6; $i++) {
    [void]$stagePnl.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, (100.0 / 6.0))))
}

$stageDefinitions = @(
    @{ Key = "DISCOVER"; Name = "1. 작업 탐색" },
    @{ Key = "VALIDATE"; Name = "2. 지시서 검증" },
    @{ Key = "WORKTREE"; Name = "3. Worktree 준비" },
    @{ Key = "EXECUTE";  Name = "4. CLI 개발/테스트" },
    @{ Key = "SCOPE";    Name = "5. 범위 검증/커밋" },
    @{ Key = "PUSH";     Name = "6. GitHub Push" }
)

$stageControls = @{}

foreach ($s in $stageDefinitions) {
    $card = New-Object System.Windows.Forms.Panel
    $card.Dock = [System.Windows.Forms.DockStyle]::Fill
    $card.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $card.BackColor = [System.Drawing.Color]::White
    $card.Margin = New-Object System.Windows.Forms.Padding(2)

    $sName = New-Object System.Windows.Forms.Label
    $sName.Text = $s.Name
    $sName.Font = New-Object System.Drawing.Font("Segoe UI", 8.0, [System.Drawing.FontStyle]::Bold)
    $sName.Dock = [System.Windows.Forms.DockStyle]::Top
    $sName.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $sName.Height = 20

    $sStatus = New-Object System.Windows.Forms.Label
    $sStatus.Text = "대기"
    $sStatus.Font = New-Object System.Drawing.Font("Segoe UI", 7.5)
    $sStatus.ForeColor = [System.Drawing.Color]::Gray
    $sStatus.Dock = [System.Windows.Forms.DockStyle]::Top
    $sStatus.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $sStatus.Height = 16

    $sElapsed = New-Object System.Windows.Forms.Label
    $sElapsed.Text = ""
    $sElapsed.Font = New-Object System.Drawing.Font("Segoe UI", 7.0)
    $sElapsed.ForeColor = [System.Drawing.Color]::DimGray
    $sElapsed.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $sElapsed.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $sElapsed.Height = 14

    $card.Controls.AddRange(@($sElapsed, $sStatus, $sName))
    [void]$stagePnl.Controls.Add($card)
    $stageControls[$s.Key] = @{ Card = $card; Status = $sStatus; Elapsed = $sElapsed }
}

$lblTotalTimer = New-Object System.Windows.Forms.Label
$lblTotalTimer.Text = "소요 시간: 00:00"
$lblTotalTimer.Font = New-Object System.Drawing.Font("Consolas", 8.5, [System.Drawing.FontStyle]::Bold)
$lblTotalTimer.ForeColor = [System.Drawing.Color]::DimGray
$lblTotalTimer.AutoSize = $true
$lblTotalTimer.Dock = [System.Windows.Forms.DockStyle]::Bottom

$stageContainer.Controls.AddRange(@($stagePnl, $lblTotalTimer))

# Console
$consolePnl = New-Object System.Windows.Forms.Panel
$consolePnl.Dock = [System.Windows.Forms.DockStyle]::Fill

$rtbLog = New-Object System.Windows.Forms.RichTextBox
$rtbLog.Dock = [System.Windows.Forms.DockStyle]::Fill
$rtbLog.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 28)
$rtbLog.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
$rtbLog.Font = New-Object System.Drawing.Font("Consolas", 9.5)
$rtbLog.ReadOnly = $true
$rtbLog.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$rtbLog.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical

$bottomBar = New-Object System.Windows.Forms.FlowLayoutPanel
$bottomBar.Dock = [System.Windows.Forms.DockStyle]::Bottom
$bottomBar.Height = 36
$bottomBar.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight

$chkAutoScroll = New-Object System.Windows.Forms.CheckBox
$chkAutoScroll.Text = "자동 스크롤"
$chkAutoScroll.Checked = $true
$chkAutoScroll.AutoSize = $true
$chkAutoScroll.Margin = New-Object System.Windows.Forms.Padding(0, 6, 12, 0)

$btnCopyLog = New-Object System.Windows.Forms.Button
$btnCopyLog.Text = "로그 복사"
$btnCopyLog.AutoSize = $true

$btnOpenLog = New-Object System.Windows.Forms.Button
$btnOpenLog.Text = "로그 파일 열기"
$btnOpenLog.AutoSize = $true
$btnOpenLog.Enabled = $false

$btnOpenCommit = New-Object System.Windows.Forms.Button
$btnOpenCommit.Text = "GitHub 커밋 보기"
$btnOpenCommit.AutoSize = $true
$btnOpenCommit.Enabled = $false

$btnShortcut = New-Object System.Windows.Forms.Button
$btnShortcut.Text = "바탕화면 바로가기 등록"
$btnShortcut.AutoSize = $true

$bottomBar.Controls.AddRange(@($chkAutoScroll, $btnCopyLog, $btnOpenLog, $btnOpenCommit, $btnShortcut))
$consolePnl.Controls.AddRange(@($rtbLog, $bottomBar))

[void]$layout.Controls.Add($headerPnl, 0, 0)
[void]$layout.Controls.Add($actionPnl, 0, 1)
[void]$layout.Controls.Add($grpDetails, 0, 2)
[void]$layout.Controls.Add($stageContainer, 0, 3)
[void]$layout.Controls.Add($consolePnl, 0, 4)

$form.Controls.Add($layout)

$currentProcess = $null
$activeCandidates = @()
$selectedTask = $null
$lastLogFile = $null
$lastCommitSha = $null

function Append-Log ($text, $stream = "stdout") {
    if ($form.InvokeRequired) {
        $form.BeginInvoke([Action[string, string]]{ param($t, $s) Append-Log $t $s }, @($text, $stream))
        return
    }

    $color = [System.Drawing.Color]::FromArgb(220, 220, 220)
    if ($text -like "*[STAGE:*" -or $stream -eq "STAGE") {
        $color = [System.Drawing.Color]::FromArgb(197, 134, 192)
    } elseif ($text -like "*[PASS]*" -or $stream -eq "PASS") {
        $color = [System.Drawing.Color]::FromArgb(181, 206, 168)
    } elseif ($text -like "*[WARN]*" -or $stream -eq "WARN") {
        $color = [System.Drawing.Color]::FromArgb(220, 220, 170)
    } elseif ($text -like "*[ERR*" -or $text -like "*failed*" -or $stream -eq "stderr") {
        $color = [System.Drawing.Color]::FromArgb(244, 71, 71)
    } elseif ($text -like "*[INFO]*" -or $stream -eq "SYSTEM") {
        $color = [System.Drawing.Color]::FromArgb(78, 201, 176)
    }

    $rtbLog.SelectionStart = $rtbLog.TextLength
    $rtbLog.SelectionLength = 0
    $rtbLog.SelectionColor = $color
    $rtbLog.AppendText($text + [Environment]::NewLine)
    $rtbLog.SelectionColor = $rtbLog.ForeColor

    if ($chkAutoScroll.Checked) {
        $rtbLog.ScrollToCaret()
    }
}

function Set-StageStatus ($key, $status) {
    if ($stageControls.ContainsKey($key)) {
        $c = $stageControls[$key]
        switch ($status) {
            "Running" {
                $c.Card.BackColor = [System.Drawing.Color]::FromArgb(235, 243, 254)
                $c.Status.Text = "진행 중..."
                $c.Status.ForeColor = [System.Drawing.Color]::FromArgb(24, 119, 242)
            }
            "Passed" {
                $c.Card.BackColor = [System.Drawing.Color]::FromArgb(235, 250, 238)
                $c.Status.Text = "완료"
                $c.Status.ForeColor = [System.Drawing.Color]::FromArgb(40, 167, 69)
            }
            "Failed" {
                $c.Card.BackColor = [System.Drawing.Color]::FromArgb(254, 238, 238)
                $c.Status.Text = "실패"
                $c.Status.ForeColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
            }
            default {
                $c.Card.BackColor = [System.Drawing.Color]::White
                $c.Status.Text = "대기"
                $c.Status.ForeColor = [System.Drawing.Color]::Gray
                $c.Elapsed.Text = ""
            }
        }
    }
}

function Reset-Stages {
    foreach ($k in $stageControls.Keys) {
        Set-StageStatus $k "Pending"
    }
}

function Refresh-Tasks {
    Append-Log "[DISCOVERY] GitHub 원격 브랜치 및 STUDIO_V3/tasks 지시서 목록 조회 중..." "SYSTEM"
    $lblBadge.Text = "조회 중..."
    $lblBadge.BackColor = [System.Drawing.Color]::FromArgb(24, 119, 242)

    $script:activeCandidates = Get-TaskCandidates
    $cboTasks.Items.Clear()

    foreach ($cand in $script:activeCandidates) {
        [void]$cboTasks.Items.Add($cand.DisplayText)
    }

    if ($script:activeCandidates.Count -gt 0) {
        $targetIdx = 0
        if ($null -ne $settings.last_selected_task_id) {
            for ($i = 0; $i -lt $script:activeCandidates.Count; $i++) {
                if ($script:activeCandidates[$i].TaskId -eq $settings.last_selected_task_id) {
                    $targetIdx = $i; break
                }
            }
        } else {
            for ($i = 0; $i -lt $script:activeCandidates.Count; $i++) {
                if (-not $script:activeCandidates[$i].IsCompleted -and $script:activeCandidates[$i].IsValid) {
                    $targetIdx = $i; break
                }
            }
        }
        $cboTasks.SelectedIndex = $targetIdx
        Append-Log "[DISCOVERY] 총 $($script:activeCandidates.Count)개 작업 발견." "SYSTEM"
    } else {
        $lblDetails.Text = "조회 가능한 GitHub 작업지시서가 없습니다."
        $btnRunSelected.Enabled = $false
        Append-Log "[DISCOVERY] 유효한 지시서가 없습니다." "WARN"
    }

    $lblBadge.Text = "대기 중 (Idle)"
    $lblBadge.BackColor = [System.Drawing.Color]::FromArgb(90, 105, 120)
}

$cboTasks.add_SelectedIndexChanged({
    $idx = $cboTasks.SelectedIndex
    if ($idx -ge 0 -and $idx -lt $script:activeCandidates.Count) {
        $cand = $script:activeCandidates[$idx]
        $script:selectedTask = $cand
        $settings.last_selected_task_id = $cand.TaskId
        Save-LauncherSettings $settings

        $statusBadge = if ($cand.IsCompleted) { "[완료됨 (COMPLETED)]" } elseif ($cand.IsValid) { "[대기 중 (READY)]" } else { "[오류: $($cand.ErrorMessage)]" }
        $lblDetails.Text = "Task ID: $($cand.TaskId)   |   브랜치: $($cand.Branch)   |   원격 SHA: $($cand.ShortSha)`n" +
                           "제목: $($cand.Title)`n" +
                           "상태: $statusBadge`n" +
                           "개요: $($cand.Summary)"

        $btnRunSelected.Enabled = $cand.IsValid -and (-not $cand.IsCompleted)
    }
})

$btnRefresh.add_Click({ Refresh-Tasks })

$chkAutoApprove.add_CheckedChanged({
    $settings.auto_approve = $chkAutoApprove.Checked
    Save-LauncherSettings $settings
    $modeStr = if ($chkAutoApprove.Checked) { "ON (원클릭 자동 실행)" } else { "OFF (수동 승인)" }
    Append-Log "[CONFIG] 자동 승인 모드가 $modeStr 으로 변경되었습니다." "SYSTEM"
})

$btnCopyLog.add_Click({
    if (-not [string]::IsNullOrEmpty($rtbLog.Text)) {
        [System.Windows.Forms.Clipboard]::SetText($rtbLog.Text)
        [System.Windows.Forms.MessageBox]::Show("콘솔 로그가 클립보드에 복사되었습니다.", "복사 완료", "OK", "Information")
    }
})

$btnOpenLog.add_Click({
    if ($null -ne $script:lastLogFile -and (Test-Path $script:lastLogFile)) {
        Start-Process "notepad.exe" "`"$($script:lastLogFile)`""
    }
})

$btnOpenCommit.add_Click({
    if ($null -ne $script:lastCommitSha) {
        Start-Process "https://github.com/jjangmut/ProjectKnight/commit/$($script:lastCommitSha)"
    }
})

$btnShortcut.add_Click({
    $desktopDir = [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
    $shortcutPath = Join-Path $desktopDir "ProjectKnight 작업 실행.lnk"
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($shortcutPath)
    $exeCandidate = "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\ProjectKnight.Launcher.exe"
    if (Test-Path $exeCandidate) {
        $sc.TargetPath = $exeCandidate
        $sc.WorkingDirectory = Split-Path -Parent $exeCandidate
    } else {
        $sc.TargetPath = "powershell.exe"
        $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Definition)`""
        $sc.WorkingDirectory = $AutomationDir
    }
    $sc.Description = "ProjectKnight 자동 개발 실행기 (WinForms)"
    $sc.Save()
    Append-Log "[SHORTCUT] 바탕화면 바로가기 등록 완료: $shortcutPath" "PASS"
    [System.Windows.Forms.MessageBox]::Show("바탕화면 바로가기가 등록되었습니다:`n`n$shortcutPath", "바로가기 등록 완료", "OK", "Information")
})

function Start-TaskExecution ($targetCandidate) {
    if ($null -eq $targetCandidate) { return }

    Reset-Stages
    $btnMain.Enabled = $false
    $btnRefresh.Enabled = $false
    $btnRunSelected.Enabled = $false
    $btnStop.Enabled = $true
    $cboTasks.Enabled = $false
    $chkAutoApprove.Enabled = $false

    $lblBadge.Text = "실행 중: $($targetCandidate.TaskId)"
    $lblBadge.BackColor = [System.Drawing.Color]::FromArgb(24, 119, 242)

    Append-Log "==================================================" "STAGE"
    Append-Log "[START] Task $($targetCandidate.TaskId) 자동 개발 파이프라인 착수" "STAGE"
    Append-Log " - 대상 브랜치: $($targetCandidate.Branch)" "STAGE"
    Append-Log " - 예상 SHA: $($targetCandidate.CommitSha)" "STAGE"
    Append-Log " - 격리 Worktree: $WorktreePath" "STAGE"
    Append-Log "==================================================" "STAGE"

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $argList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$RunnerPath`"",
        "-Action", "Execute",
        "-TaskId", "`"$($targetCandidate.TaskId)`"",
        "-ExpectedBranch", "`"$($targetCandidate.Branch)`"",
        "-ExpectedCommitSha", "`"$($targetCandidate.CommitSha)`""
    )
    if ($chkAutoApprove.Checked) {
        $argList += "-AutoApprove"
    }
    $psi.Arguments = $argList -join " "
    $psi.WorkingDirectory = $WorktreePath
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $script:currentProcess = New-Object System.Diagnostics.Process
    $script:currentProcess.StartInfo = $psi
    $script:currentProcess.EnableRaisingEvents = $true

    $outHandler = [System.Diagnostics.DataReceivedEventHandler]{
        param($s, $e)
        if ($null -ne $e.Data) {
            $line = $e.Data
            Append-Log $line "stdout"

            if ($line -match '\[STAGE:([A-Z]+)\]\s*(.*)') {
                $stKey = $matches[1].ToUpperInvariant()
                if ($stKey -eq "COMPLETE") {
                    $form.BeginInvoke([Action]{
                        Set-StageStatus "PUSH" "Passed"
                        Set-StageStatus "COMPLETE" "Passed"
                    })
                } else {
                    $form.BeginInvoke([Action]{
                        Set-StageStatus $stKey "Running"
                    })
                }
            }

            if ($line -match 'Changes successfully committed in worktree:\s*([a-fA-F0-9]{40})') {
                $script:lastCommitSha = $matches[1]
                $form.BeginInvoke([Action]{ $btnOpenCommit.Enabled = $true })
            }

            if ($line -match 'Execution Log:\s*([^\r\n]+\.log)') {
                $script:lastLogFile = $matches[1].Trim()
                $form.BeginInvoke([Action]{ $btnOpenLog.Enabled = $true })
            }
        }
    }

    $errHandler = [System.Diagnostics.DataReceivedEventHandler]{
        param($s, $e)
        if ($null -ne $e.Data) {
            Append-Log $e.Data "stderr"
        }
    }

    $script:currentProcess.add_OutputDataReceived($outHandler)
    $script:currentProcess.add_ErrorDataReceived($errHandler)

    $script:currentProcess.add_Exited({
        $exitCode = $script:currentProcess.ExitCode
        $form.BeginInvoke([Action]{
            $btnMain.Enabled = $true
            $btnRefresh.Enabled = $true
            $btnRunSelected.Enabled = $true
            $btnStop.Enabled = $false
            $cboTasks.Enabled = $true
            $chkAutoApprove.Enabled = $true

            if ($exitCode -eq 0) {
                $lblBadge.Text = "완료 (COMPLETED)"
                $lblBadge.BackColor = [System.Drawing.Color]::FromArgb(40, 167, 69)
                Append-Log "[COMPLETED] Task $($targetCandidate.TaskId) 자동 개발 완료!" "PASS"
                [System.Windows.Forms.MessageBox]::Show("Task $($targetCandidate.TaskId) 개발 및 반영이 성공적으로 완료되었습니다!`n`n커밋 SHA: $($script:lastCommitSha)", "실행 완료", "OK", "Information")
                Refresh-Tasks
            } else {
                $lblBadge.Text = "실패 (FAILED: $exitCode)"
                $lblBadge.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
                Append-Log "[FAILED] Task $($targetCandidate.TaskId) 실행 실패 (종료 코드: $exitCode)" "ERROR"
                [System.Windows.Forms.MessageBox]::Show("Task $($targetCandidate.TaskId) 실행 중 오류가 발생했습니다 (코드: $exitCode).`n콘솔 로그를 확인하세요.", "실행 실패", "OK", "Error")
            }
        })
    })

    [void]$script:currentProcess.Start()
    $script:currentProcess.BeginOutputReadLine()
    $script:currentProcess.BeginErrorReadLine()
}

$btnStop.add_Click({
    if ($null -ne $script:currentProcess -and -not $script:currentProcess.HasExited) {
        $confirm = [System.Windows.Forms.MessageBox]::Show("진행 중인 개발 작업을 중지하시겠습니까?", "작업 중지 확인", "YesNo", "Warning")
        if ($confirm -eq "Yes") {
            Append-Log "[STOP] 작업 중지 요청됨..." "WARN"
            try {
                $script:currentProcess.Kill()
            } catch {}
        }
    }
})

$btnMain.add_Click({
    if ($script:activeCandidates.Count -eq 0) {
        Refresh-Tasks
        if ($script:activeCandidates.Count -eq 0) { return }
    }

    $cand = $script:selectedTask
    if ($null -eq $cand -or $cand.IsCompleted -or (-not $cand.IsValid)) {
        for ($i = 0; $i -lt $script:activeCandidates.Count; $i++) {
            if (-not $script:activeCandidates[$i].IsCompleted -and $script:activeCandidates[$i].IsValid) {
                $cand = $script:activeCandidates[$i]; break
            }
        }
    }

    if ($null -eq $cand) {
        [System.Windows.Forms.MessageBox]::Show("실행할 수 있는 미완료 작업이 없습니다.", "알림", "OK", "Information")
        return
    }

    $eligible = @($script:activeCandidates | Where-Object { (-not $_.IsCompleted) -and $_.IsValid })
    if ($eligible.Count -gt 1 -and (-not $chkAutoApprove.Checked)) {
        $res = [System.Windows.Forms.MessageBox]::Show(
            "미완료 작업 $($eligible.Count)건이 발견되었습니다.`n`n선택된 작업:`n - ID: $($cand.TaskId)`n - 제목: $($cand.Title)`n - 브랜치: $($cand.Branch)`n`n실행하시겠습니까?",
            "작업 실행 확인",
            "YesNo",
            "Question")
        if ($res -ne "Yes") { return }
    } elseif (-not $chkAutoApprove.Checked) {
        $res = [System.Windows.Forms.MessageBox]::Show(
            "다음 작업을 격리 Worktree에서 실행하시겠습니까?`n`n - ID: $($cand.TaskId)`n - 제목: $($cand.Title)`n - 브랜치: $($cand.Branch)",
            "작업 실행 확인",
            "YesNo",
            "Question")
        if ($res -ne "Yes") { return }
    } else {
        Append-Log "[AUTO-APPROVE] 자동 승인 옵션에 따라 작업 $($cand.TaskId)을(를) 즉시 실행합니다." "SYSTEM"
    }

    Start-TaskExecution $cand
})

$btnRunSelected.add_Click({
    if ($null -ne $script:selectedTask) {
        if (-not $chkAutoApprove.Checked) {
            $res = [System.Windows.Forms.MessageBox]::Show(
                "선택된 작업 '$($script:selectedTask.TaskId)'을(를) 실행하시겠습니까?",
                "선택 작업 실행",
                "YesNo",
                "Question")
            if ($res -ne "Yes") { return }
        }
        Start-TaskExecution $script:selectedTask
    }
})

$form.add_Shown({
    Refresh-Tasks
})

[void]$form.ShowDialog()
