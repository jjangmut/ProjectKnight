using System.Diagnostics;
using System.Text.Json;
using System.Text.RegularExpressions;
using ProjectKnight.Launcher.Models;

namespace ProjectKnight.Launcher.Services;

public class TaskDiscoveryService
{
    private static readonly string[] ForbiddenBranches = 
    { 
        "main", "master", "integration", "HEAD", "task/art-stage-batch-001" 
    };

    private static readonly string[] ProtectedTaskIds = 
    { 
        "V3-017", "v3-017" 
    };

    public string RepoPath { get; }
    public string StateFilePath { get; }

    public TaskDiscoveryService(string repoPath, string stateFilePath)
    {
        RepoPath = repoPath;
        StateFilePath = stateFilePath;
    }

    public async Task<List<TaskCandidate>> DiscoverCandidatesAsync(CancellationToken cancellationToken = default)
    {
        return await Task.Run(() =>
        {
            var candidates = new List<TaskCandidate>();
            var completedTasks = LoadCompletedTasks();

            // 1. Fetch remote tracking branches
            RunGit("fetch origin --prune", RepoPath, 15000);

            // 2. Query origin branches with commit SHAs
            var rawBranches = RunGit("for-each-ref --format=\"%(refname:short)|%(objectname)\" refs/remotes/origin/", RepoPath);
            if (string.IsNullOrWhiteSpace(rawBranches))
            {
                return candidates;
            }

            var branchLines = rawBranches.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
            var seenKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (var line in branchLines)
            {
                cancellationToken.ThrowIfCancellationRequested();

                var parts = line.Split('|');
                if (parts.Length < 2) continue;

                var fullBranchName = parts[0].Trim(); // e.g. origin/studio/v3-014-stage-clear-intermission
                var commitSha = parts[1].Trim();

                if (!fullBranchName.StartsWith("origin/")) continue;
                var branchName = fullBranchName["origin/".Length..]; // e.g. studio/v3-014-stage-clear-intermission

                // Filter forbidden branches
                if (ForbiddenBranches.Any(fb => branchName.Equals(fb, StringComparison.OrdinalIgnoreCase)))
                {
                    continue;
                }

                // Match valid task branches: studio/v3-* or test/v3-*
                if (!branchName.StartsWith("studio/v3-", StringComparison.OrdinalIgnoreCase) &&
                    !branchName.StartsWith("test/v3-", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                // Deduce task ID from branch name
                var deducedTaskId = DeduceTaskIdFromBranch(branchName);
                if (string.IsNullOrWhiteSpace(deducedTaskId)) continue;

                // Protect V3-017 from automated execution
                if (ProtectedTaskIds.Any(p => deducedTaskId.Equals(p, StringComparison.OrdinalIgnoreCase)))
                {
                    continue;
                }

                // Check task markdown from origin commit
                var taskMarkdown = RunGit($"show \"origin/{branchName}:STUDIO_V3/tasks/{deducedTaskId}.md\"", RepoPath);
                if (string.IsNullOrWhiteSpace(taskMarkdown))
                {
                    // Fallback attempt: check case-insensitive or exact file search
                    continue;
                }

                var candidate = ParseTaskMarkdown(deducedTaskId, branchName, commitSha, taskMarkdown);

                // Check completion state
                if (completedTasks.TryGetValue(candidate.TaskId, out var completedInfo))
                {
                    candidate.IsCompleted = true;
                    candidate.Status = "COMPLETED";
                }

                var uniqueKey = $"{candidate.TaskId}@{candidate.Branch}@{candidate.CommitSha}";
                if (seenKeys.Add(uniqueKey))
                {
                    candidates.Add(candidate);
                }
            }

            // Sort: Incomplete valid tasks first, then by TaskId descending
            return candidates
                .OrderBy(c => c.IsCompleted)
                .ThenByDescending(c => c.IsValid)
                .ThenByDescending(c => c.TaskId, StringComparer.OrdinalIgnoreCase)
                .ToList();
        }, cancellationToken);
    }

    public static string DeduceTaskIdFromBranch(string branchName)
    {
        // Examples:
        // studio/v3-014-stage-clear-intermission -> V3-014
        // studio/v3-automation-winforms-rebuild -> AUTOMATION-005
        // studio/v3-automation-oneclick-launcher -> AUTOMATION-004
        // test/v3-test-automation -> V3-TEST-AUTOMATION
        var leaf = branchName.Contains('/') ? branchName[(branchName.LastIndexOf('/') + 1)..] : branchName;

        var mStandard = Regex.Match(leaf, @"^(v3-\d{3})", RegexOptions.IgnoreCase);
        if (mStandard.Success)
        {
            return mStandard.Groups[1].Value.ToUpperInvariant();
        }

        if (leaf.Equals("v3-test-automation", StringComparison.OrdinalIgnoreCase))
        {
            return "V3-TEST-AUTOMATION";
        }

        if (leaf.Contains("winforms-rebuild", StringComparison.OrdinalIgnoreCase))
        {
            return "AUTOMATION-005";
        }

        if (leaf.Contains("oneclick-launcher", StringComparison.OrdinalIgnoreCase))
        {
            return "AUTOMATION-004";
        }

        var mAutomation = Regex.Match(leaf, @"^(automation-\d{3})", RegexOptions.IgnoreCase);
        if (mAutomation.Success)
        {
            return mAutomation.Groups[1].Value.ToUpperInvariant();
        }

        return string.Empty;
    }

    public static TaskCandidate ParseTaskMarkdown(string taskId, string branchName, string commitSha, string markdown)
    {
        var candidate = new TaskCandidate
        {
            TaskId = taskId,
            Branch = branchName,
            CommitSha = commitSha,
            Status = "PENDING"
        };

        // Parse Title: # TaskId — Title or # Title
        var titleMatch = Regex.Match(markdown, @"^#\s+(?<header>[^\r\n]+)", RegexOptions.Multiline);
        if (titleMatch.Success)
        {
            var rawHeader = titleMatch.Groups["header"].Value.Trim();
            var cleanTitle = Regex.Replace(rawHeader, @"^[-A-Za-z0-9_]+\s*[-—:]\s*", string.Empty);
            candidate.Title = string.IsNullOrWhiteSpace(cleanTitle) ? rawHeader : cleanTitle;
        }
        else
        {
            candidate.Title = taskId;
        }

        // Parse declared Branch
        var branchMatch = Regex.Match(markdown, @"(?im)\*{0,2}(?:Target Branch|Branch):\*{0,2}\s*`?([a-zA-Z0-9_\-\/]+)`?");
        if (branchMatch.Success)
        {
            var declaredBranch = branchMatch.Groups[1].Value.Trim();
            if (!declaredBranch.Equals(branchName, StringComparison.OrdinalIgnoreCase))
            {
                candidate.IsValid = false;
                candidate.ErrorMessage = $"선언 브랜치 불일치: 지시서('{declaredBranch}') vs 원격('{branchName}')";
            }
        }
        else
        {
            candidate.IsValid = false;
            candidate.ErrorMessage = "지시서 내 Target Branch 메타데이터 부재";
        }

        // Parse Base Commit
        var baseMatch = Regex.Match(markdown, @"(?im)(?:parent branch HEAD|Base Commit):\*{0,2}\s*`?([a-zA-Z0-9_\-\/]+)`?");
        if (baseMatch.Success)
        {
            candidate.BaseCommit = baseMatch.Groups[1].Value.Trim();
        }

        // Parse Summary
        var summaryMatch = Regex.Match(markdown, @"(?ims)(?:##\s*(?:목적|Task Objective|Objective|Purpose|개요|1\.\s*결정사항)[^\r\n]*)(.*?)(?:\n##|\Z)");
        if (summaryMatch.Success)
        {
            var cleanSummary = Regex.Replace(summaryMatch.Groups[1].Value.Trim(), @"\r?\n+", " ");
            candidate.Summary = cleanSummary.Length > 200 ? cleanSummary[..200] + "..." : cleanSummary;
        }
        else
        {
            candidate.Summary = candidate.Title;
        }

        return candidate;
    }

    public Dictionary<string, JsonElement> LoadCompletedTasks()
    {
        var result = new Dictionary<string, JsonElement>(StringComparer.OrdinalIgnoreCase);
        try
        {
            if (File.Exists(StateFilePath))
            {
                var json = File.ReadAllText(StateFilePath);
                using var doc = JsonDocument.Parse(json);
                if (doc.RootElement.TryGetProperty("completed_tasks", out var completedEl))
                {
                    foreach (var prop in completedEl.EnumerateObject())
                    {
                        result[prop.Name] = prop.Value.Clone();
                    }
                }
            }
        }
        catch
        {
            // Non-fatal
        }
        return result;
    }

    private static string RunGit(string args, string workingDirectory, int timeoutMs = 10000)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "git",
                Arguments = args,
                WorkingDirectory = workingDirectory,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using var process = new Process { StartInfo = psi };
            if (!process.Start()) return string.Empty;

            var stdoutTask = process.StandardOutput.ReadToEndAsync();
            var stderrTask = process.StandardError.ReadToEndAsync();

            if (!process.WaitForExit(timeoutMs))
            {
                try { process.Kill(true); } catch { }
                return string.Empty;
            }

            Task.WaitAll(new Task[] { stdoutTask, stderrTask }, 2000);

            if (process.ExitCode != 0)
            {
                return string.Empty;
            }

            return stdoutTask.Result.Trim();
        }
        catch
        {
            return string.Empty;
        }
    }
}
