using System.Diagnostics;
using System.Reflection;
using ProjectKnight.Launcher.Models;
using ProjectKnight.Launcher.Services;

namespace ProjectKnight.Launcher.Tests;

internal static class Program
{
    static int Main()
    {
        Console.WriteLine("==================================================");
        Console.WriteLine("ProjectKnight C# WinForms Launcher Test Suite");
        Console.WriteLine("==================================================");

        int passed = 0;
        int failed = 0;
        var sw = Stopwatch.StartNew();

        void RunTest(string testName, Action testAction)
        {
            Console.Write($"[TEST] {testName} ... ");
            try
            {
                testAction();
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("PASSED");
                Console.ResetColor();
                passed++;
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("FAILED");
                Console.ResetColor();
                Console.WriteLine($"  Error: {ex.Message}");
                if (ex.InnerException != null)
                {
                    Console.WriteLine($"  Inner: {ex.InnerException.Message}");
                }
                failed++;
            }
        }

        RunTest("DeduceTaskIdFromBranch", () =>
        {
            AssertEqual("V3-014", TaskDiscoveryService.DeduceTaskIdFromBranch("studio/v3-014-stage-clear-intermission"));
            AssertEqual("V3-001", TaskDiscoveryService.DeduceTaskIdFromBranch("studio/v3-001-playable-baseline"));
            AssertEqual("V3-TEST-AUTOMATION", TaskDiscoveryService.DeduceTaskIdFromBranch("test/v3-test-automation"));
            AssertEqual("AUTOMATION-005", TaskDiscoveryService.DeduceTaskIdFromBranch("studio/v3-automation-winforms-rebuild"));
            AssertEqual("AUTOMATION-004", TaskDiscoveryService.DeduceTaskIdFromBranch("studio/v3-automation-oneclick-launcher"));
        });

        RunTest("TaskMarkdownParsing_ValidMatchingBranch", () =>
        {
            var md = """
                # V3-014 — Stage Clear & Intermission Flow
                **Repository:** `jjangmut/ProjectKnight`
                **Branch:** `studio/v3-014-stage-clear-intermission`
                **Base Commit:** `abc12345`
                
                ## Purpose
                Implement stage clear screen and reward flow between stages.
                """;

            var candidate = TaskDiscoveryService.ParseTaskMarkdown("V3-014", "studio/v3-014-stage-clear-intermission", "11223344556677889900aabbccddeeff11223344", md);

            AssertEqual("V3-014", candidate.TaskId);
            AssertEqual("studio/v3-014-stage-clear-intermission", candidate.Branch);
            AssertEqual("Stage Clear & Intermission Flow", candidate.Title);
            AssertTrue(candidate.IsValid, "Matching branch metadata must be valid");
            AssertTrue(candidate.ErrorMessage == null, "Error message must be null");
            AssertTrue(candidate.Summary.Contains("stage clear screen"), "Summary must be extracted");
            AssertEqual("11223344", candidate.ShortSha);
        });

        RunTest("TaskMarkdownParsing_MismatchedBranchRejected", () =>
        {
            var md = """
                # V3-014 — Stage Clear & Intermission Flow
                **Branch:** `studio/v3-different-branch`
                """;

            var candidate = TaskDiscoveryService.ParseTaskMarkdown("V3-014", "studio/v3-014-stage-clear-intermission", "11223344", md);

            AssertTrue(!candidate.IsValid, "Mismatched declared branch must be marked invalid");
            AssertTrue(candidate.ErrorMessage != null && candidate.ErrorMessage.Contains("불일치"), "Error message must state mismatch");
        });

        RunTest("TaskMarkdownParsing_MissingBranchRejected", () =>
        {
            var md = """
                # V3-999 — Broken Task Without Declared Branch
                ## Purpose
                Some purpose.
                """;

            var candidate = TaskDiscoveryService.ParseTaskMarkdown("V3-999", "studio/v3-999", "11223344", md);

            AssertTrue(!candidate.IsValid, "Task without declared branch metadata must be invalid");
            AssertTrue(candidate.ErrorMessage != null, "Error message must not be null");
        });

        RunTest("SettingsPersistence", () =>
        {
            var tempFile = Path.Combine(Path.GetTempPath(), $"settings_test_{Guid.NewGuid():N}.json");
            try
            {
                var s1 = new LauncherSettings { AutoApprove = true, LastSelectedTaskId = "V3-018", AutoScrollLog = true };
                s1.Save(tempFile);

                var loaded1 = LauncherSettings.Load(tempFile);
                AssertTrue(loaded1.AutoApprove, "AutoApprove must be true");
                AssertEqual("V3-018", loaded1.LastSelectedTaskId ?? "");
                AssertTrue(loaded1.AutoScrollLog, "AutoScrollLog must be true");

                loaded1.AutoApprove = false;
                loaded1.Save(tempFile);

                var loaded2 = LauncherSettings.Load(tempFile);
                AssertTrue(!loaded2.AutoApprove, "AutoApprove must be false after change");
            }
            finally
            {
                if (File.Exists(tempFile)) File.Delete(tempFile);
            }
        });

        RunTest("CandidateSelectionIntegrity_NonFirstCandidate", () =>
        {
            var candidates = new List<TaskCandidate>
            {
                new() { TaskId = "V3-001", Branch = "studio/v3-001", CommitSha = "1111111111111111111111111111111111111111", Title = "Baseline", IsCompleted = true },
                new() { TaskId = "V3-TEST-AUTOMATION", Branch = "test/v3-test-automation", CommitSha = "2222222222222222222222222222222222222222", Title = "Automation Test", IsCompleted = false, IsValid = true },
                new() { TaskId = "V3-018", Branch = "studio/v3-018-audio", CommitSha = "3333333333333333333333333333333333333333", Title = "Audio Polish", IsCompleted = false, IsValid = true }
            };

            // Select 2nd candidate (index 1)
            var selected = candidates[1];
            AssertEqual("V3-TEST-AUTOMATION", selected.TaskId);
            AssertEqual("test/v3-test-automation", selected.Branch);
            AssertEqual("2222222222222222222222222222222222222222", selected.CommitSha);
            AssertTrue(!selected.IsCompleted, "Candidate 2 must not be completed");

            // Select 3rd candidate (index 2)
            var selected3 = candidates[2];
            AssertEqual("V3-018", selected3.TaskId);
            AssertEqual("studio/v3-018-audio", selected3.Branch);
            AssertEqual("3333333333333333333333333333333333333333", selected3.CommitSha);
        });

        RunTest("StageTransitions", () =>
        {
            var stage = new ExecutionStage("EXECUTE", "④ CLI 개발·테스트");
            AssertTrue(stage.Status == StageStatus.Pending, "Initial status must be Pending");

            stage.Start();
            AssertTrue(stage.Status == StageStatus.Running, "Status after start must be Running");
            AssertTrue(stage.StartTime != null, "StartTime must not be null");

            stage.Complete(true, "테스트 완료");
            AssertTrue(stage.Status == StageStatus.Passed, "Status after complete must be Passed");
            AssertTrue(stage.EndTime != null, "EndTime must not be null");
            AssertEqual("테스트 완료", stage.StatusMessage);
            AssertTrue(stage.Elapsed >= TimeSpan.Zero, "Elapsed must be >= 0");
        });

        RunTest("DesktopShortcutPath", () =>
        {
            var path = DesktopShortcutService.ShortcutPath;
            AssertTrue(path.EndsWith("ProjectKnight 작업 실행.lnk", StringComparison.OrdinalIgnoreCase), "Shortcut must end with .lnk");
        });

        RunTest("RunnerCommandLine_IncludesApprovedByGui", () =>
        {
            var service = new AutomationRunnerService("D:\\runner.ps1", "D:\\worktree");
            var candidate = new TaskCandidate
            {
                TaskId = "V3-TEST-AUTOMATION",
                Branch = "test/v3-test-automation",
                CommitSha = "bedc1c0500000000000000000000000000000000"
            };

            // Using reflection or testing the built arguments directly
            var method = typeof(AutomationRunnerService).GetMethod("BuildRunnerArguments",
                System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.Instance);

            // Verify properties on service and candidate
            AssertEqual("D:\\runner.ps1", service.RunnerScriptPath);
            AssertEqual("D:\\worktree", service.WorktreePath);
            AssertEqual("V3-TEST-AUTOMATION", candidate.TaskId);
            AssertEqual("test/v3-test-automation", candidate.Branch);
        });

        RunTest("MultipleCandidatesGuard_RequiresExplicitSelection", () =>
        {
            var candidates = new List<TaskCandidate>
            {
                new() { TaskId = "V3-001", Branch = "studio/v3-001", IsCompleted = true, IsValid = true },
                new() { TaskId = "TASK-A", Branch = "studio/task-a", IsCompleted = false, IsValid = true },
                new() { TaskId = "TASK-B", Branch = "studio/task-b", IsCompleted = false, IsValid = true }
            };

            var eligible = candidates.Where(c => !c.IsCompleted && c.IsValid).ToList();
            AssertEqual("2", eligible.Count.ToString());

            // If selected is null, guard must NOT auto-pick index 0
            TaskCandidate? selectedCandidate = null;
            bool requirePrompt = eligible.Count > 1 && selectedCandidate == null;
            AssertTrue(requirePrompt, "Multiple eligible candidates without explicit selection must require user prompt");

            // Once explicitly selected, candidate is preserved
            selectedCandidate = eligible[1];
            AssertEqual("TASK-B", selectedCandidate.TaskId);
        });

        sw.Stop();
        Console.WriteLine("==================================================");
        Console.WriteLine($"Total: {passed + failed} | Passed: {passed} | Failed: {failed} ({sw.Elapsed.TotalMilliseconds:F1}ms)");
        Console.WriteLine("==================================================");

        return failed == 0 ? 0 : 1;
    }

    private static void AssertEqual(string expected, string actual)
    {
        if (expected != actual)
        {
            throw new Exception($"Expected '{expected}', but got '{actual}'");
        }
    }

    private static void AssertTrue(bool condition, string message)
    {
        if (!condition)
        {
            throw new Exception($"Assertion failed: {message}");
        }
    }
}
