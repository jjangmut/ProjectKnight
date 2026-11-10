using System.Text.Json;

namespace ProjectKnight.Launcher.Models;

public class LauncherSettings
{
    public bool AutoApprove { get; set; } = false;
    public string? LastSelectedTaskId { get; set; }
    public bool AutoScrollLog { get; set; } = true;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    public static LauncherSettings Load(string filePath)
    {
        try
        {
            if (File.Exists(filePath))
            {
                var json = File.ReadAllText(filePath);
                var settings = JsonSerializer.Deserialize<LauncherSettings>(json);
                if (settings != null) return settings;
            }
        }
        catch
        {
            // Fall back to default
        }
        return new LauncherSettings();
    }

    public void Save(string filePath)
    {
        try
        {
            var dir = Path.GetDirectoryName(filePath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }
            var json = JsonSerializer.Serialize(this, JsonOptions);
            File.WriteAllText(filePath, json);
        }
        catch
        {
            // Non-fatal
        }
    }
}
