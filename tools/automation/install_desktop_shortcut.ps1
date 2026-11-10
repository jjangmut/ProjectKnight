# ==============================================================================
# Install Desktop Shortcut for ProjectKnight One-Click Developer
# ==============================================================================
[CmdletBinding()]
param()

$desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$shortcutPath = Join-Path $desktopPath "ProjectKnight 작업 실행.lnk"

$currentDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$launcherPy = Join-Path $currentDir "launcher.py"

# Locate pythonw.exe
$pythonw = (Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source
if (-not $pythonw) {
    $pythonw = (Get-Command python.exe -ErrorAction SilentlyContinue).Source
}
if (-not $pythonw) {
    Write-Error "Python executable not found in PATH."
    exit 1
}

$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $pythonw
$shortcut.Arguments = "`"$launcherPy`""
$shortcut.WorkingDirectory = $currentDir
$shortcut.Description = "ProjectKnight One-Click Automated Developer Launcher"
$shortcut.Save()

Write-Host "=================================================="
Write-Host "Desktop Shortcut Created Successfully!" -ForegroundColor Green
Write-Host "Location: $shortcutPath" -ForegroundColor Cyan
Write-Host "Target:   $pythonw `"$launcherPy`""
Write-Host "=================================================="
