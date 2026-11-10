namespace ProjectKnight.Launcher.Services;

public static class DesktopShortcutService
{
    public static string ShortcutPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
        "ProjectKnight 작업 실행.lnk");

    public static bool CreateOrUpdateShortcut(string targetExePath)
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
            shortcut.TargetPath = targetExePath;
            shortcut.WorkingDirectory = Path.GetDirectoryName(targetExePath);
            shortcut.Description = "ProjectKnight 자동 개발 실행기 (C# WinForms)";
            shortcut.IconLocation = $"{targetExePath},0";
            shortcut.Save();

            return File.Exists(shortcutFile);
        }
        catch
        {
            return false;
        }
    }
}
