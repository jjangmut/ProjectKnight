# ==============================================================================
# Install Desktop Shortcut for ProjectKnight C# WinForms Developer Launcher
# ==============================================================================
[CmdletBinding()]
param()

$desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$shortcutPath = Join-Path $desktopPath "ProjectKnight 작업 실행.lnk"

$currentDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$launcherExe = Join-Path $currentDir "ProjectKnight.Launcher.exe"

if (-not (Test-Path $launcherExe)) {
    $parentDir = Split-Path -Parent $currentDir
    if (Test-Path (Join-Path $parentDir "ProjectKnight.Launcher.exe")) {
        $launcherExe = Join-Path $parentDir "ProjectKnight.Launcher.exe"
        $currentDir = $parentDir
    } elseif (Test-Path "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\ProjectKnight.Launcher.exe") {
        $launcherExe = "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\ProjectKnight.Launcher.exe"
        $currentDir = "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight"
    }
}

$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $launcherExe
$shortcut.Arguments = ""
$shortcut.WorkingDirectory = $currentDir
$shortcut.Description = "ProjectKnight 자동 개발 실행기 (C# WinForms .NET 8)"
$shortcut.Save()

# Also create SAC fallback shortcut
$sacShortcutPath = Join-Path $desktopPath "ProjectKnight 작업 실행 (SAC 대응).lnk"
$sacShortcut = $wsh.CreateShortcut($sacShortcutPath)
$sacShortcut.TargetPath = "powershell.exe"
$sacShortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$currentDir\launcher_winforms.ps1`""
$sacShortcut.WorkingDirectory = $currentDir
$sacShortcut.Description = "ProjectKnight 자동 개발 실행기 (WinForms PowerShell 호스트)"
$sacShortcut.Save()

Write-Host "=================================================="
Write-Host "Desktop Shortcut Created Successfully!" -ForegroundColor Green
Write-Host "Location: $shortcutPath" -ForegroundColor Cyan
Write-Host "Target:   $launcherExe"
Write-Host "=================================================="
