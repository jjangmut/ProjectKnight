using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using ProjectKnight.Launcher.Models;

namespace ProjectKnight.Launcher.Services;

public record LogEntry(string Stream, string Text, DateTime Timestamp);
public record StageTransition(string StageKey, StageStatus Status, string Message);

public class ExecutionResult
{
    public bool Success { get; set; }
    public string FinalStatus { get; set; } = "UNKNOWN";
    public string? CommitSha { get; set; }
    public TimeSpan Duration { get; set; }
    public string? LogFilePath { get; set; }
    public string? ErrorMessage { get; set; }
    public List<string> DetectedStages { get; } = new();
}

public class AutomationRunnerService
{
    public string RunnerScriptPath { get; }
    public string WorktreePath { get; }

    public AutomationRunnerService(string runnerScriptPath, string worktreePath)
    {
        RunnerScriptPath = runnerScriptPath;
        WorktreePath = worktreePath;
    }

    public async Task<ExecutionResult> ExecuteTaskAsync(
        TaskCandidate candidate,
        bool autoApprove,
        IProgress<LogEntry>? logProgress,
        IProgress<StageTransition>? stageProgress,
        CancellationToken cancellationToken = default)
    {
        var result = new ExecutionResult();
        var sw = Stopwatch.StartNew();

        var argsBuilder = new StringBuilder();
        argsBuilder.Append("-NoProfile -ExecutionPolicy Bypass ");
        argsBuilder.Append($"-File \"{RunnerScriptPath}\" ");
        argsBuilder.Append("-Action Execute ");
        argsBuilder.Append($"-TaskId \"{candidate.TaskId}\" ");
        argsBuilder.Append($"-ExpectedBranch \"{candidate.Branch}\" ");
        argsBuilder.Append($"-ExpectedCommitSha \"{candidate.CommitSha}\" ");
        argsBuilder.Append("-ApprovedByGui ");

        if (autoApprove)
        {
            argsBuilder.Append("-AutoApprove ");
        }

        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = argsBuilder.ToString(),
            WorkingDirectory = WorktreePath,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8
        };

        using var process = new Process { StartInfo = psi, EnableRaisingEvents = true };

        void ProcessLine(string line, string stream)
        {
            if (string.IsNullOrWhiteSpace(line)) return;

            logProgress?.Report(new LogEntry(stream, line, DateTime.Now));

            // Stage marker parsing: [STAGE:XYZ] Message
            var stageMatch = Regex.Match(line, @"\[STAGE:([A-Z]+)\]\s*(.*)");
            if (stageMatch.Success)
            {
                var stageKey = stageMatch.Groups[1].Value.ToUpperInvariant();
                var stageMsg = stageMatch.Groups[2].Value.Trim();
                result.DetectedStages.Add(stageKey);

                if (stageKey == "COMPLETE")
                {
                    stageProgress?.Report(new StageTransition("PUSH", StageStatus.Passed, "Push 완료"));
                    stageProgress?.Report(new StageTransition("COMPLETE", StageStatus.Passed, stageMsg));
                }
                else
                {
                    stageProgress?.Report(new StageTransition(stageKey, StageStatus.Running, stageMsg));
                }
            }

            // Commit SHA parsing
            var commitMatch = Regex.Match(line, @"Changes successfully committed in worktree:\s*([a-fA-F0-9]{40})");
            if (commitMatch.Success)
            {
                result.CommitSha = commitMatch.Groups[1].Value;
            }

            // Completion status parsing
            var statusMatch = Regex.Match(line, @"Status:\s*([A-Za-z_]+)");
            if (statusMatch.Success && line.Contains("[STAGE:COMPLETE]"))
            {
                result.FinalStatus = statusMatch.Groups[1].Value;
            }

            // Explicit machine-readable result parsing: [RESULT:JSON] { ... }
            var jsonMatch = Regex.Match(line, @"\[RESULT:JSON\]\s*(\{.*\})");
            if (jsonMatch.Success)
            {
                try
                {
                    using var doc = JsonDocument.Parse(jsonMatch.Groups[1].Value);
                    if (doc.RootElement.TryGetProperty("status", out var st))
                    {
                        var statusStr = st.GetString();
                        if (!string.IsNullOrWhiteSpace(statusStr)) result.FinalStatus = statusStr;
                    }
                    if (doc.RootElement.TryGetProperty("commit_sha", out var cs))
                    {
                        var sha = cs.GetString();
                        if (!string.IsNullOrWhiteSpace(sha)) result.CommitSha = sha;
                    }
                    if (doc.RootElement.TryGetProperty("log_file", out var lf))
                    {
                        var lfp = lf.GetString();
                        if (!string.IsNullOrWhiteSpace(lfp)) result.LogFilePath = lfp;
                    }
                }
                catch
                {
                    // Non-fatal JSON parse error
                }
            }

            // Log file location parsing
            var logMatch = Regex.Match(line, @"Execution Log:\s*([^\r\n]+\.log)");
            if (logMatch.Success)
            {
                result.LogFilePath = logMatch.Groups[1].Value.Trim();
            }
        }

        process.OutputDataReceived += (s, e) =>
        {
            if (e.Data != null) ProcessLine(e.Data, "stdout");
        };

        process.ErrorDataReceived += (s, e) =>
        {
            if (e.Data != null) ProcessLine(e.Data, "stderr");
        };

        try
        {
            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            using var registration = cancellationToken.Register(() =>
            {
                try
                {
                    if (!process.HasExited)
                    {
                        process.Kill(true);
                    }
                }
                catch
                {
                    // Ignore
                }
            });

            await process.WaitForExitAsync(cancellationToken);
            sw.Stop();

            result.Duration = sw.Elapsed;
            if (process.ExitCode == 0 && result.FinalStatus == "COMPLETED")
            {
                result.Success = true;
            }
            else if (process.ExitCode == 0)
            {
                // Partial outcomes like NO_CHANGES or PUSH_SKIPPED are not treated as full completion
                result.Success = false;
                if (result.FinalStatus == "UNKNOWN")
                {
                    result.FinalStatus = "NO_CHANGES";
                }
            }
            else
            {
                result.Success = false;
                result.FinalStatus = "FAILED";
                result.ErrorMessage = $"Runner exited with code {process.ExitCode}";
            }
        }
        catch (OperationCanceledException)
        {
            sw.Stop();
            result.Duration = sw.Elapsed;
            result.Success = false;
            result.FinalStatus = "CANCELLED";
            result.ErrorMessage = "작업이 사용자에 의해 중지되었습니다.";
        }
        catch (Exception ex)
        {
            sw.Stop();
            result.Duration = sw.Elapsed;
            result.Success = false;
            result.FinalStatus = "FAILED";
            result.ErrorMessage = ex.Message;
        }

        return result;
    }
}
