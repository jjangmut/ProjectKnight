<#
.SYNOPSIS
    Safe Godot Headless Test Execution Wrapper with Guaranteed Timeout & Cleanup.
    Ensures no zombie or orphan Godot processes linger in the system.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$TestScript,

    [int]$TimeoutSec = 15,

    [string]$AdditionalArgs = ""
)

$godotExe = "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$projectPath = "CLIENT/Game"

if (-not (Test-Path $godotExe)) {
    Write-Error "Godot binary not found at $godotExe"
    exit 1
}

$argList = @("--headless", "--path", $projectPath, "-s", $TestScript)
if ($AdditionalArgs -ne "") {
    $argList += $AdditionalArgs.Split(" ")
}

Write-Host ">>> [SAFE RUNNER] Launching test: $TestScript (Timeout: ${TimeoutSec}s)..."

$p = Start-Process -FilePath $godotExe -ArgumentList $argList -NoNewWindow -PassThru

$targetPid = $p.Id

# Wait for exit with timeout in milliseconds
$exited = $p.WaitForExit($TimeoutSec * 1000)

if (-not $exited) {
    Write-Warning ">>> [SAFE RUNNER TIMEOUT] Test exceeded ${TimeoutSec}s! Force-killing process tree (PID: $targetPid)..."
    & taskkill /F /T /PID $targetPid 2>$null | Out-Null
    exit 124
}

$exitCode = $p.ExitCode
Write-Host ">>> [SAFE RUNNER DONE] Process exited with code: $exitCode"

# Guarantee no orphan sub-processes remain
Get-CimInstance Win32_Process -Filter "Name like '%Godot%'" | Where-Object { $_.ParentProcessId -eq $targetPid } | ForEach-Object {
    Write-Host ">>> [CLEANUP] Terminating lingering child PID: $($_.ProcessId)"
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}

exit $exitCode
