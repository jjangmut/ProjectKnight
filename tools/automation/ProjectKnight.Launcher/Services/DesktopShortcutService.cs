namespace ProjectKnight.Launcher.Services;

public static class DesktopShortcutService
{
    public static string ShortcutPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
        "ProjectKnight 작업 실행.lnk");

    public static bool CreateOrUpdateShortcut(string targetPath)
    {
        try
        {
            var desktopDir = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            var shortcutFile = Path.Combine(desktopDir, "ProjectKnight 작업 실행.lnk");

            var shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType == null) return false;

            dynamic? shell = Activator.CreateInstance(shellType);
            if (shell == null) return false;

            dynamic shortcut = shell.CreateShortcut(shortcutFile);

            if (targetPath.EndsWith(".dll", StringComparison.OrdinalIgnoreCase))
            {
                var dotnetExe = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                    "dotnet", "dotnet.exe");
                if (!File.Exists(dotnetExe))
                {
                    dotnetExe = "dotnet.exe";
                }

                shortcut.TargetPath = dotnetExe;
                shortcut.Arguments = $"\"{targetPath}\"";
                shortcut.WorkingDirectory = Path.GetDirectoryName(targetPath);
                shortcut.Description = "ProjectKnight 자동 개발 실행기 (C# WinForms .NET 8)";
            }
            else
            {
                shortcut.TargetPath = targetPath;
                shortcut.Arguments = string.Empty;
                shortcut.WorkingDirectory = Path.GetDirectoryName(targetPath);
                shortcut.Description = "ProjectKnight 자동 개발 실행기 (C# WinForms .NET 8)";
                shortcut.IconLocation = $"{targetPath},0";
            }

            shortcut.Save();

            return File.Exists(shortcutFile);
        }
        catch
        {
            return false;
        }
    }
}
