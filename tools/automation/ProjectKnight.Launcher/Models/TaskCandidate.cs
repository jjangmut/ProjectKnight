namespace ProjectKnight.Launcher.Models;

public class TaskCandidate
{
    public string TaskId { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Branch { get; set; } = string.Empty;
    public string CommitSha { get; set; } = string.Empty;
    public string ShortSha => string.IsNullOrWhiteSpace(CommitSha) 
        ? "--------" 
        : (CommitSha.Length > 8 ? CommitSha[..8] : CommitSha);
    
    public string Status { get; set; } = "PENDING";
    public string Summary { get; set; } = string.Empty;
    public string FilePath { get; set; } = string.Empty;
    public string BaseCommit { get; set; } = string.Empty;
    
    public bool IsCompleted { get; set; }
    public bool IsValid { get; set; } = true;
    public string? ErrorMessage { get; set; }

    public string DisplayText
    {
        get
        {
            var badge = IsCompleted ? "[완료]" : (IsValid ? "[대기]" : "[오류]");
            return $"{badge} {TaskId} | {Branch} ({ShortSha}) - {Title}";
        }
    }

    public override string ToString() => DisplayText;
}
