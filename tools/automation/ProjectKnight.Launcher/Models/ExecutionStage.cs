namespace ProjectKnight.Launcher.Models;

public enum StageStatus
{
    Pending,
    Running,
    Passed,
    Failed,
    Skipped
}

public class ExecutionStage
{
    public string Key { get; }
    public string DisplayName { get; }
    public StageStatus Status { get; set; } = StageStatus.Pending;
    public DateTime? StartTime { get; set; }
    public DateTime? EndTime { get; set; }
    public TimeSpan Elapsed => (EndTime ?? (StartTime.HasValue ? DateTime.Now : StartTime)) - (StartTime ?? DateTime.Now) ?? TimeSpan.Zero;
    public string StatusMessage { get; set; } = string.Empty;

    public ExecutionStage(string key, string displayName)
    {
        Key = key;
        DisplayName = displayName;
    }

    public void Reset()
    {
        Status = StageStatus.Pending;
        StartTime = null;
        EndTime = null;
        StatusMessage = string.Empty;
    }

    public void Start()
    {
        Status = StageStatus.Running;
        StartTime = DateTime.Now;
        EndTime = null;
    }

    public void Complete(bool success, string message = "")
    {
        Status = success ? StageStatus.Passed : StageStatus.Failed;
        EndTime = DateTime.Now;
        StatusMessage = message;
    }
}
