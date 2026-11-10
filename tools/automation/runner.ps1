# ==============================================================================
# ProjectKnight Antigravity Automated Task Runner
# Location: D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\runner.ps1
# Description: Automates task discovery, branch validation, Antigravity CLI execution,
#              pre-commit scope enforcement, and GitHub sync using isolated Git Worktree.
# Security:
#   - Worktree isolation protects main developer workspace (Projects\ProjectKnight)
#   - Principle of Least Privilege (--settings with explicit allow/deny lists)
#   - Pre-commit file scope verification blocks unauthorized changes & pushes
#   - Strictly forbids main, master, integration branches and external commands
# ==============================================================================

[CmdletBinding()]
param(
    [ValidateSet("Scan", "Execute", "Status", "ResetLock")]
    [string]$Action = "Scan",

    [string]$TaskId = "",

    [string]$ExpectedBranch = "",

    [string]$ExpectedCommitSha = "",

    [switch]$Force = $false,

    [switch]$SkipPush = $false,

    [switch]$AutoApprove = $false,

    [string]$ConfigPath = "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\config.json"
)

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------------------------
# 1. Logging Functions
# ------------------------------------------------------------------------------
function Log-Info {
    param([string]$Message)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$ts] [INFO] $Message" -ForegroundColor Cyan
}

function Log-Success {
    param([string]$Message)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$ts] [PASS] $Message" -ForegroundColor Green
}

function Log-Warn {
    param([string]$Message)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$ts] [WARN] $Message" -ForegroundColor Yellow
}

function Log-Err {
    param([string]$Message)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$ts] [FAIL] $Message" -ForegroundColor Red
}

# ------------------------------------------------------------------------------
# 2. Configuration & State Setup
# ------------------------------------------------------------------------------
if (-not (Test-Path $ConfigPath)) {
    throw "Configuration file not found: $ConfigPath"
}

$Config = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$RepoPath = $Config.local_repo_path
$WorktreePath = $Config.worktree_path
$TasksDir = Join-Path $RepoPath $Config.tasks_relative_dir
$AgyBin = $Config.agy_binary
$GodotBin = $Config.godot_binary
$SecuritySettings = $Config.agy_settings_path

$StateDir = "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\state"
$LogsDir = "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\logs"
$LockFile = Join-Path $StateDir "runner.lock"
$StateFile = Join-Path $StateDir "tasks_state.json"

if (-not (Test-Path $LogsDir)) { New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null }
if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir -Force | Out-Null }

# Ensure agy is in process PATH
$agyDir = Split-Path -Parent $AgyBin
if ($env:Path -notlike "*$agyDir*") {
    $env:Path = "$agyDir;" + $env:Path
}

# ------------------------------------------------------------------------------
# 3. Concurrency Lock Management
# ------------------------------------------------------------------------------
function Acquire-Lock {
    param([string]$CurrentTaskId)
    if (Test-Path $LockFile) {
        try {
            $lockData = Get-Content $LockFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $existingProcess = Get-Process -Id $lockData.pid -ErrorAction SilentlyContinue
            if ($null -ne $existingProcess) {
                throw "Another runner instance (PID: $($lockData.pid), Task: $($lockData.task_id)) is currently active. Concurrency blocked."
            } else {
                Log-Warn "Found stale lock file from dead process $($lockData.pid). Clearing lock."
                Remove-Item $LockFile -Force
            }
        } catch [System.Management.Automation.ItemNotFoundException] {
            # Stale file disappeared
        }
    }

    $lockPayload = @{
        pid = $PID
        task_id = $CurrentTaskId
        started_at = (Get-Date).ToString("o")
    } | ConvertTo-Json
    Set-Content -Path $LockFile -Value $lockPayload -Encoding UTF8
}

function Release-Lock {
    if (Test-Path $LockFile) {
        Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    }
}

if ($Action -eq "ResetLock") {
    Release-Lock
    Log-Success "Runner lock successfully reset."
    exit 0
}

# ------------------------------------------------------------------------------
# 4. State Management
# ------------------------------------------------------------------------------
function Get-TasksState {
    if (-not (Test-Path $StateFile)) {
        return @{
            last_updated = (Get-Date).ToString("o")
            completed_tasks = @{}
            in_progress_task = $null
        }
    }
    return Get-Content -Path $StateFile -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Save-TasksState {
    param($StateObject)
    $StateObject.last_updated = (Get-Date).ToString("o")
    $json = $StateObject | ConvertTo-Json -Depth 10
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($StateFile, $json, $utf8NoBom)
}

# ------------------------------------------------------------------------------
# 5. Task Parsing & Security Validation
# ------------------------------------------------------------------------------
function Parse-TaskFile {
    param(
        [string]$FilePath = "",
        [string]$Content = "",
        [string]$TaskId = ""
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        if (-not (Test-Path $FilePath)) {
            throw "Task file not found: $FilePath"
        }
        $Content = Get-Content -Path $FilePath -Raw -Encoding UTF8
    }

    if ([string]::IsNullOrWhiteSpace($TaskId)) {
        $fileName = Split-Path -Leaf $FilePath
        $TaskId = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    } else {
        $fileName = "$TaskId.md"
    }

    $branch = ""
    if ($Content -match '(?im)(?:\*{0,2}Target Branch|\*{0,2}Branch):\*{0,2}\s*`?([a-zA-Z0-9_\-\/]+)`?') {
        $branch = $matches[1].Trim()
    }

    $baseCommit = ""
    if ($Content -match '(?im)(?:parent branch HEAD|Base Commit):\*{0,2}\s*`?([a-zA-Z0-9_\-\/]+)`?') {
        $baseCommit = $matches[1].Trim()
    }

    # Extract allowed and forbidden change rules from markdown if documented
    $allowedChanges = @()
    if ($Content -match '(?ims)Allowed changes:(.*?)(?:\n\s*\n|Forbidden changes|##|$)') {
        $allowedLines = $matches[1] -split "\r?\n"
        foreach ($line in $allowedLines) {
            if ($line -match '^\s*[-*]\s*`?([^`\r\n]+)`?') {
                $allowedChanges += $matches[1].Trim()
            }
        }
    }

    $forbiddenChanges = @()
    if ($Content -match '(?ims)Forbidden changes:(.*?)(?:\n\s*\n|Allowed changes|##|$)') {
        $forbiddenLines = $matches[1] -split "\r?\n"
        foreach ($line in $forbiddenLines) {
            if ($line -match '^\s*[-*]\s*`?([^`\r\n]+)`?') {
                $forbiddenChanges += $matches[1].Trim()
            }
        }
    }

    return @{
        task_id = $TaskId
        file_path = $FilePath
        file_name = $fileName
        target_branch = $branch
        base_commit = $baseCommit
        allowed_changes = $allowedChanges
        forbidden_changes = $forbiddenChanges
    }
}

function Validate-TaskSecurity {
    param($TaskInfo)

    if ([string]::IsNullOrWhiteSpace($TaskInfo.target_branch)) {
        throw "Security Reject: Task $($TaskInfo.task_id) specifies no target branch."
    }

    # Forbidden branches
    foreach ($fb in $Config.forbidden_branches) {
        if ($TaskInfo.target_branch -eq $fb) {
            throw "Security Reject: Target branch '$($TaskInfo.target_branch)' is forbidden."
        }
    }

    # Allowed branch patterns
    $patternMatch = $false
    foreach ($pattern in $Config.allowed_branch_patterns) {
        if ($TaskInfo.target_branch -match $pattern) {
            $patternMatch = $true
            break
        }
    }
    if (-not $patternMatch) {
        throw "Security Reject: Branch '$($TaskInfo.target_branch)' does not match approved patterns ($($Config.allowed_branch_patterns -join ', '))."
    }
}

# ------------------------------------------------------------------------------
# 6. Git Worktree Isolation Manager
# ------------------------------------------------------------------------------
function Ensure-Worktree {
    param(
        [string]$TargetBranch
    )

    Log-Info "Verifying Git Worktree isolation for branch: $TargetBranch"

    # 1. Verify main repository safety: ensure target branch is not active in main repo
    $mainBranch = ""
    $mbRaw = git -C $RepoPath rev-parse --abbrev-ref HEAD 2>$null
    if ($null -ne $mbRaw) { $mainBranch = "$mbRaw".Trim() }

    if ($mainBranch -eq $TargetBranch) {
        throw "Safety Violation: Target branch '$TargetBranch' is currently checked out in main workspace ($RepoPath). Main workspace cannot be shared with automated runner to prevent collision."
    }

    # 2. Check if worktree directory exists
    if (-not (Test-Path $WorktreePath)) {
        Log-Info "Creating new dedicated worktree at: $WorktreePath"
        
        $localBranchExists = ""
        $lbeRaw = git -C $RepoPath branch --list $TargetBranch 2>$null
        if ($null -ne $lbeRaw) { $localBranchExists = "$lbeRaw".Trim() }

        if (-not [string]::IsNullOrWhiteSpace($localBranchExists)) {
            git -C $RepoPath worktree add $WorktreePath $TargetBranch
        } else {
            # Try origin branch
            $prevEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            git -C $RepoPath fetch origin $TargetBranch --quiet 2>&1 | Out-Null
            $ErrorActionPreference = $prevEAP
            git -C $RepoPath worktree add -b $TargetBranch $WorktreePath "origin/$TargetBranch"
        }
    } else {
        # Worktree directory exists. Check current worktree branch
        $wtBranch = ""
        $wtbRaw = git -C $WorktreePath rev-parse --abbrev-ref HEAD 2>$null
        if ($null -ne $wtbRaw) { $wtBranch = "$wtbRaw".Trim() }

        Log-Info "Existing worktree detected. Current branch in worktree: $wtBranch"

        # Check if worktree is clean
        $wtStatus = ""
        $wtsRaw = git -C $WorktreePath status --porcelain 2>$null
        if ($null -ne $wtsRaw) { $wtStatus = "$wtsRaw".Trim() }

        if (-not [string]::IsNullOrWhiteSpace($wtStatus)) {
            Log-Warn "Worktree contains uncommitted residue. Resetting worktree cleanly."
            git -C $WorktreePath reset --hard HEAD
            git -C $WorktreePath clean -fd
        }

        if ($wtBranch -ne $TargetBranch) {
            Log-Info "Switching worktree to target branch: $TargetBranch"
            $prevEAP = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            git -C $WorktreePath fetch origin --quiet 2>&1 | Out-Null
            $ErrorActionPreference = $prevEAP

            $targetLocalExists = ""
            $tleRaw = git -C $WorktreePath branch --list $TargetBranch 2>$null
            if ($null -ne $tleRaw) { $targetLocalExists = "$tleRaw".Trim() }

            if (-not [string]::IsNullOrWhiteSpace($targetLocalExists)) {
                git -C $WorktreePath checkout $TargetBranch
            } else {
                git -C $WorktreePath checkout -b $TargetBranch "origin/$TargetBranch"
            }
        }
    }

    Log-Success "Worktree ready and isolated at: $WorktreePath (Branch: $TargetBranch)"
}

# ------------------------------------------------------------------------------
# 7. Pre-Commit Scope & Boundary Validation
# ------------------------------------------------------------------------------
function Test-PreCommitScope {
    param(
        [string]$TargetTaskId,
        $TaskInfo
    )

    Log-Info "Running pre-commit scope boundary check for Task: $TargetTaskId..."

    $rawStatus = git -C $WorktreePath status --porcelain
    if ([string]::IsNullOrWhiteSpace($rawStatus)) {
        Log-Info "No modified or added files detected."
        return $true
    }

    $violations = @()
    $statusLines = $rawStatus -split "\r?\n"

    foreach ($line in $statusLines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        # Format is XY PATH or XY "PATH" -> extract path
        $filePath = $line.Substring(3).Trim().Trim('"')
        if ($filePath -match ' -> ') {
            $filePath = ($filePath -split ' -> ')[-1].Trim().Trim('"')
        }
        # Normalize to forward slashes
        $normPath = $filePath -replace '\\', '/'

        # 1. Global forbidden patterns
        if ($normPath -match '^Automation/' -and $TargetTaskId -notmatch '(?i)infra|workflow|automation') {
            $violations += "Forbidden change: modified automation system file '$normPath'"
            continue
        }
        if ($normPath -match '^\.git/') {
            $violations += "Forbidden change: internal git file '$normPath'"
            continue
        }

        # 2. Evidence boundary: task may only write to its own evidence directory
        if ($normPath -match '^STUDIO_V3/evidence/([^/]+)/') {
            $evidenceTask = $matches[1]
            if ($evidenceTask -ne $TargetTaskId) {
                $violations += "Forbidden change: touched evidence folder of another task: '$normPath' (Expected: $TargetTaskId)"
                continue
            }
        }

        # 3. Tasks boundary: task may only update its own specification
        if ($normPath -match '^STUDIO_V3/tasks/([^/]+)\.md$') {
            $specTaskId = $matches[1]
            if ($specTaskId -ne $TargetTaskId) {
                $violations += "Forbidden change: modified task specification of another task: '$normPath'"
                continue
            }
        }

        # 4. CI/CD workflow security: workflow changes forbidden unless task specifically targets workflow
        if ($normPath -match '^\.github/workflows/' -and $TargetTaskId -notmatch '(?i)infra|workflow|automation') {
            $violations += "Forbidden change: game task cannot modify CI/CD workflows: '$normPath'"
            continue
        }

        # 5. Executable file creation ban (binary executables)
        if ($normPath -match '\.(exe|dll|msi)$' -or ($normPath -match '\.(bat|cmd|vbs)$' -and $normPath -notmatch '^tools/')) {
            $violations += "Forbidden change: executable binary files cannot be committed: '$normPath'"
            continue
        }

        # 6. Task-specific forbidden changes if specified in markdown
        if ($null -ne $TaskInfo.forbidden_changes -and $TaskInfo.forbidden_changes.Count -gt 0) {
            foreach ($fc in $TaskInfo.forbidden_changes) {
                if ($normPath -like "*$fc*") {
                    $violations += "Forbidden change (task rule): file '$normPath' matches forbidden pattern '$fc'"
                }
            }
        }
    }

    if ($violations.Count -gt 0) {
        Log-Err "=================================================="
        Log-Err "PRE-COMMIT SCOPE VIOLATIONS DETECTED ($($violations.Count)):"
        foreach ($v in $violations) {
            Log-Err " - $v"
        }
        Log-Err "=================================================="
        return $false
    }

    Log-Success "Pre-commit scope check PASSED. All $($statusLines.Count) modified file(s) are within approved bounds."
    return $true
}

# ------------------------------------------------------------------------------
# 8. Action: Scan Tasks
# ------------------------------------------------------------------------------
function Invoke-Scan {
    Log-Info "Scanning for task specifications in: $TasksDir"
    if (-not (Test-Path $TasksDir)) {
        Log-Warn "Tasks directory does not exist: $TasksDir"
        return @()
    }

    $allFiles = @{}
    if (Test-Path $TasksDir) {
        Get-ChildItem -Path $TasksDir -Filter "V3-*.md" | ForEach-Object { $allFiles[$_.Name] = $_.FullName }
    }
    if (Test-Path $WorktreePath) {
        $wtTasks = Join-Path $WorktreePath $Config.tasks_relative_dir
        if (Test-Path $wtTasks) {
            Get-ChildItem -Path $wtTasks -Filter "V3-*.md" | ForEach-Object {
                if (-not $allFiles.ContainsKey($_.Name)) {
                    $allFiles[$_.Name] = $_.FullName
                }
            }
        }
    }

    $state = Get-TasksState
    $results = @()
    foreach ($name in ($allFiles.Keys | Sort-Object)) {
        $fPath = $allFiles[$name]
        $parsed = Parse-TaskFile -FilePath $fPath
        $isCompleted = $null -ne $state.completed_tasks.($parsed.task_id)

        $status = "PENDING"
        if ($isCompleted) {
            $status = "COMPLETED"
        }

        $results += [PSCustomObject]@{
            TaskId = $parsed.task_id
            Branch = $parsed.target_branch
            Status = $status
            File = $parsed.file_name
        }
    }

    $results | Format-Table -AutoSize
    return $results
}

# ------------------------------------------------------------------------------
# 9. Action: Status Report
# ------------------------------------------------------------------------------
function Invoke-Status {
    $state = Get-TasksState
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "ProjectKnight Automation Status Report" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "Last Updated: $($state.last_updated)"
    $completedCount = ($state.completed_tasks.PSObject.Properties | Measure-Object).Count
    Write-Host "Completed Tasks Count: $completedCount"
    
    if ($null -ne $state.in_progress_task) {
        Write-Host "Active In-Progress Task: $($state.in_progress_task)" -ForegroundColor Yellow
    } else {
        Write-Host "Active In-Progress Task: None (Idle)" -ForegroundColor Green
    }

    if (Test-Path $LockFile) {
        $lockData = Get-Content $LockFile -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host "Lock Status: ACTIVE (PID: $($lockData.pid), Task: $($lockData.task_id))" -ForegroundColor Yellow
    } else {
        Write-Host "Lock Status: UNLOCKED" -ForegroundColor Green
    }

    Write-Host "`nRecent Completed Tasks:"
    foreach ($prop in $state.completed_tasks.PSObject.Properties) {
        $val = $prop.Value
        Write-Host " - $($prop.Name): Commit $($val.commit_sha) at $($val.completed_at) [Status: $($val.status)]"
    }
}

# ------------------------------------------------------------------------------
# 10. Action: Execute Task
# ------------------------------------------------------------------------------
function Invoke-Execute {
    param(
        [string]$TargetTaskId,
        [string]$ExpectedBranch = "",
        [string]$ExpectedCommitSha = ""
    )

    if ([string]::IsNullOrWhiteSpace($TargetTaskId)) {
        throw "Execute action requires -TaskId <TaskId>"
    }

    $taskInfo = $null

    # If ExpectedBranch is specified, fetch origin and bind directly to remote task specification
    if (-not [string]::IsNullOrWhiteSpace($ExpectedBranch)) {
        Log-Info "Binding execution to remote branch: origin/$ExpectedBranch"
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        git -C $RepoPath fetch origin $ExpectedBranch --quiet 2>&1 | Out-Null
        $ErrorActionPreference = $prevEAP

        $remoteHeadSha = ""
        $rhsRaw = git -C $RepoPath rev-parse "origin/$ExpectedBranch" 2>$null
        if ($null -ne $rhsRaw) { $remoteHeadSha = "$rhsRaw".Trim() }

        if ([string]::IsNullOrWhiteSpace($remoteHeadSha)) {
            throw "Security Reject: Remote branch 'origin/$ExpectedBranch' could not be resolved on origin."
        }

        # SHA integrity verification
        if (-not [string]::IsNullOrWhiteSpace($ExpectedCommitSha)) {
            if ($remoteHeadSha -ne $ExpectedCommitSha) {
                throw "Security Violation: Remote branch HEAD SHA ($remoteHeadSha) does not match approved SHA ($ExpectedCommitSha). Task rejected to prevent execution of unauthorized modifications."
            }
            Log-Success "Verified remote branch HEAD SHA matches approved SHA ($ExpectedCommitSha)."
        }

        # Read task specification from origin commit
        $remoteSpec = git -C $RepoPath show "origin/${ExpectedBranch}:STUDIO_V3/tasks/${TargetTaskId}.md" 2>$null
        if ($null -ne $remoteSpec -and "$remoteSpec".Trim().Length -gt 0) {
            $taskInfo = Parse-TaskFile -Content "$remoteSpec" -TaskId $TargetTaskId -FilePath "origin/${ExpectedBranch}:STUDIO_V3/tasks/${TargetTaskId}.md"
        }
    }

    if ($null -eq $taskInfo) {
        $taskFile = Join-Path $TasksDir "$TargetTaskId.md"
        if (-not (Test-Path $taskFile)) {
            if (Test-Path $WorktreePath) {
                $wtTaskFile = Join-Path $WorktreePath (Join-Path $Config.tasks_relative_dir "$TargetTaskId.md")
                if (Test-Path $wtTaskFile) {
                    $taskFile = $wtTaskFile
                }
            }
        }
        if (-not (Test-Path $taskFile)) {
            throw "Task specification file not found for Task: $TargetTaskId"
        }
        $taskInfo = Parse-TaskFile -FilePath $taskFile
    }

    # Verify target branch matches ExpectedBranch if provided
    if (-not [string]::IsNullOrWhiteSpace($ExpectedBranch) -and $taskInfo.target_branch -ne $ExpectedBranch) {
        throw "Security Reject: Task specification specifies target branch '$($taskInfo.target_branch)' which does not match expected branch '$ExpectedBranch'."
    }

    Validate-TaskSecurity -TaskInfo $taskInfo

    $state = Get-TasksState
    if ((-not $Force) -and ($null -ne $state.completed_tasks.$TargetTaskId)) {
        Log-Warn "Task $TargetTaskId is already recorded as COMPLETED in state file. Use -Force to re-run."
        return
    }

    # Manual Approval Gate
    if ($Config.require_manual_approval -and (-not $AutoApprove)) {
        Write-Host "`n[MANUAL APPROVAL GATE]" -ForegroundColor Yellow
        Write-Host "Task ID:       $($taskInfo.task_id)" -ForegroundColor White
        Write-Host "Target Branch: $($taskInfo.target_branch)" -ForegroundColor White
        Write-Host "Task File:     $($taskInfo.file_path)" -ForegroundColor White
        Write-Host "Worktree:      $WorktreePath" -ForegroundColor White
        $choice = Read-Host "Authorize Antigravity automated execution in isolated worktree? (y/N)"
        if ($choice -ne "y" -and $choice -ne "Y") {
            Log-Warn "Execution cancelled by user."
            return
        }
    }

    Acquire-Lock -CurrentTaskId $TargetTaskId
    try {
        $startTime = Get-Date
        $logStamp = $startTime.ToString("yyyyMMdd_HHmmss")
        $logPath = Join-Path $LogsDir "${TargetTaskId}_${logStamp}.log"
        $jsonOutPath = Join-Path $LogsDir "${TargetTaskId}_${logStamp}_result.json"

        Write-Host "[STAGE:DISCOVER] 작업 탐색 (Target Task: $TargetTaskId)"
        Log-Info "Starting isolated execution for Task: $TargetTaskId"
        Log-Info "Target Branch: $($taskInfo.target_branch)"
        Log-Info "Execution Log: $logPath"

        # Update in-progress state
        $state.in_progress_task = $TargetTaskId
        Save-TasksState -StateObject $state

        Write-Host "[STAGE:VALIDATE] GitHub 지시서 검증 완료 (Branch: $($taskInfo.target_branch))"

        # Ensure Worktree is set up and isolated
        Write-Host "[STAGE:WORKTREE] 격리 Worktree 준비 중 ($WorktreePath)"
        Ensure-Worktree -TargetBranch $taskInfo.target_branch

        # Construct Antigravity CLI Prompt
        $agyPrompt = "Read STUDIO_V3/tasks/$TargetTaskId.md and implement the requirements. Execute tests and record evidence."
        Write-Host "[STAGE:EXECUTE] Antigravity CLI 개발·테스트 실행 시작"
        Log-Info "Launching Antigravity CLI in isolated worktree with least-privilege settings..."

        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $AgyBin
        $psi.Arguments = "-p `"$agyPrompt`" --mode accept-edits --settings `"$SecuritySettings`" --output-format json"
        $psi.WorkingDirectory = $WorktreePath
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $psi.CreateNoWindow = $true

        $process = [System.Diagnostics.Process]::Start($psi)

        $stdoutSb = New-Object System.Text.StringBuilder
        $stderrSb = New-Object System.Text.StringBuilder

        $outHandler = [System.Diagnostics.DataReceivedEventHandler]{
            param($sender, $e)
            if ($null -ne $e.Data) {
                Write-Host $e.Data
                [void]$stdoutSb.AppendLine($e.Data)
            }
        }
        $errHandler = [System.Diagnostics.DataReceivedEventHandler]{
            param($sender, $e)
            if ($null -ne $e.Data) {
                Write-Host $e.Data
                [void]$stderrSb.AppendLine($e.Data)
            }
        }

        $process.add_OutputDataReceived($outHandler)
        $process.add_ErrorDataReceived($errHandler)
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()

        $timeoutMs = $Config.execution_timeout_seconds * 1000
        $finished = $process.WaitForExit($timeoutMs)
        $sw.Stop()

        if (-not $finished) {
            try { $process.Kill() } catch {}
            throw "Antigravity CLI execution timed out after $($Config.execution_timeout_seconds) seconds."
        }

        $rawStdout = $stdoutSb.ToString()
        $rawStderr = $stderrSb.ToString()
        $agyExitCode = $process.ExitCode

        [System.IO.File]::WriteAllText($jsonOutPath, $rawStdout, [System.Text.Encoding]::UTF8)
        [System.IO.File]::WriteAllText($logPath, $rawStderr, [System.Text.Encoding]::UTF8)

        Log-Info "Antigravity CLI process exited with code: $agyExitCode in $($sw.Elapsed.TotalSeconds.ToString('F1'))s"

        # Parse JSON Output
        $agyJson = $null
        if (Test-Path $jsonOutPath) {
            $rawJson = Get-Content -Path $jsonOutPath -Raw -Encoding UTF8
            try {
                $agyJson = $rawJson | ConvertFrom-Json
            } catch {
                Log-Warn "Failed to parse JSON response from agy. Raw output preserved in $jsonOutPath."
            }
        }

        if ($agyExitCode -ne 0) {
            throw "Antigravity CLI exited with non-zero code ($agyExitCode)."
        }

        if ($null -eq $agyJson) {
            throw "Fail-Closed: Antigravity CLI output was empty or invalid JSON. Cannot confirm task execution success."
        }

        if ($agyJson.status -ne "SUCCESS") {
            throw "Antigravity reported execution failure: $($agyJson.status)"
        }

        if ($null -ne $agyJson -and $null -ne $agyJson.denied_actions -and $agyJson.denied_actions.Count -gt 0) {
            Log-Warn "One or more tool actions were denied permissions by least-privilege policy: $($agyJson.denied_actions | ConvertTo-Json -Compress)"
        }

        # ----------------------------------------------------------------------
        # Pre-Commit Scope & Boundary Gate
        # ----------------------------------------------------------------------
        Write-Host "[STAGE:SCOPE] 변경 범위 검증 및 커밋 시작"
        $scopePass = Test-PreCommitScope -TargetTaskId $TargetTaskId -TaskInfo $taskInfo
        if (-not $scopePass) {
            throw "Pre-commit scope check failed: unauthorized modifications detected. Commit and push aborted to protect repository integrity."
        }

        # Commit and Push from within the isolated worktree
        $changedFiles = git -C $WorktreePath status --porcelain
        $commitSha = ""
        $finalStatus = "COMPLETED"

        if (-not [string]::IsNullOrWhiteSpace($changedFiles)) {
            git -C $WorktreePath add -A
            $commitMsg = "feat($($TargetTaskId.ToLower())): implement $TargetTaskId requirements via Antigravity automation"
            git -C $WorktreePath commit -m $commitMsg
            $commitSha = (git -C $WorktreePath rev-parse HEAD).Trim()
            Log-Success "Changes successfully committed in worktree: $commitSha"

            if ($Config.auto_push_on_success -and (-not $SkipPush)) {
                Write-Host "[STAGE:PUSH] GitHub Push 진행 중 ($($taskInfo.target_branch))"
                Log-Info "Pushing to remote origin/$($taskInfo.target_branch)..."
                $prevEap = $ErrorActionPreference
                $ErrorActionPreference = "Continue"
                $pushOutput = git -C $WorktreePath push origin $($taskInfo.target_branch) 2>&1
                $pushExit = $LASTEXITCODE
                $ErrorActionPreference = $prevEap
                if ($pushExit -ne 0) {
                    $finalStatus = "PARTIAL_PUSH_FAILED"
                    throw "Git push failed (Exit $pushExit): $pushOutput"
                }
                Log-Success "Branch pushed successfully."
            } else {
                Log-Info "Push skipped (SkipPush or auto_push_on_success disabled)."
                $finalStatus = "PUSH_SKIPPED"
            }
        } else {
            Log-Warn "No working directory changes detected after task execution."
            $commitSha = (git -C $WorktreePath rev-parse HEAD).Trim()
            $finalStatus = "NO_CHANGES"
        }

        # Update State
        $completedObj = [PSCustomObject]@{
            task_id = $TargetTaskId
            branch = $taskInfo.target_branch
            commit_sha = $commitSha
            duration_seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1)
            completed_at = (Get-Date).ToString("o")
            status = $finalStatus
            log_file = $logPath
            isolated_worktree = $WorktreePath
        }
        $state.completed_tasks | Add-Member -MemberType NoteProperty -Name $TargetTaskId -Value $completedObj -Force
        $state.in_progress_task = $null
        Save-TasksState -StateObject $state

        Write-Host "[STAGE:COMPLETE] 작업 자동 개발 및 반영 완료 (Commit: $commitSha, Status: $finalStatus)"
        Log-Success "Task $TargetTaskId automated execution completed successfully in isolated worktree!"

    } catch {
        Log-Err "Task execution failed: $_"
        $state.in_progress_task = $null
        Save-TasksState -StateObject $state
        throw
    } finally {
        Release-Lock
    }
}

# ------------------------------------------------------------------------------
# 11. Main Dispatcher
# ------------------------------------------------------------------------------
switch ($Action) {
    "Scan" {
        Invoke-Scan
    }
    "Status" {
        Invoke-Status
    }
    "Execute" {
        Invoke-Execute -TargetTaskId $TaskId -ExpectedBranch $ExpectedBranch -ExpectedCommitSha $ExpectedCommitSha
    }
}
