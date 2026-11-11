# ==============================================================================
# Install Desktop Shortcut for ProjectKnight C# WinForms Developer Launcher
# ==============================================================================
[CmdletBinding()]
param()

$desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
$shortcutPath = Join-Path $desktopPath "ProjectKnight 작업 실행.lnk"

# Remove legacy SAC fallback shortcut if present
$sacShortcutPath = Join-Path $desktopPath "ProjectKnight 작업 실행 (SAC 대응).lnk"
if (Test-Path $sacShortcutPath) {
    Remove-Item -Force $sacShortcutPath -ErrorAction SilentlyContinue
}

$dotnetExe = (Get-Command dotnet.exe -ErrorAction SilentlyContinue).Source
if (-not $dotnetExe) {
    $dotnetExe = "C:\Program Files\dotnet\dotnet.exe"
}

$dllPath = "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\bin\ProjectKnight.Launcher.dll"
$workDir = "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight"

if (-not (Test-Path $dllPath)) {
    $currentDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $worktreeDll = Join-Path $currentDir "ProjectKnight.Launcher\bin\Release\net8.0-windows\ProjectKnight.Launcher.dll"
    if (Test-Path $worktreeDll) {
        New-Item -ItemType Directory -Force -Path "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\bin" | Out-Null
        Copy-Item -Force (Split-Path -Parent $worktreeDll)\* "D:\JUNYPAPA_STUDIO\Automation\ProjectKnight\bin\"
    }
}

$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $dotnetExe
$shortcut.Arguments = "`"$dllPath`""
$shortcut.WorkingDirectory = $workDir
$shortcut.Description = "ProjectKnight 자동 개발 실행기 (C# WinForms .NET 8)"
$shortcut.Save()

Write-Host "=================================================="
Write-Host "Desktop Shortcut Created Successfully!" -ForegroundColor Green
Write-Host "Location: $shortcutPath" -ForegroundColor Cyan
Write-Host "Target:   $dotnetExe `"$dllPath`""
Write-Host "Mode:     CSHARP_DLL_HOST_VERIFIED (Smart App Control compliant)"
Write-Host "=================================================="
