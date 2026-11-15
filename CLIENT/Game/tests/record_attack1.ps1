$ErrorActionPreference = "Stop"

$Godot = "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$FFmpeg = "C:\Users\jjang\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.2-full_build\bin\ffmpeg.exe"
$Worktree = "D:\JUNYPAPA_STUDIO\Worktrees\ProjectKnight\V3-026-R1"
$GameDir = "$Worktree\CLIENT\Game"
$VideoDir = "D:\JUNYPAPA_STUDIO\Videos\ProjectKnight\V3-026-R1"
$EvidenceDir = "$Worktree\STUDIO_V3\evidence\V3-026-R1"
$CapturesDir = "$EvidenceDir\captures"

if (-not (Test-Path $VideoDir)) { New-Item -ItemType Directory -Path $VideoDir -Force }
if (-not (Test-Path $EvidenceDir)) { New-Item -ItemType Directory -Path $EvidenceDir -Force }
if (-not (Test-Path $CapturesDir)) { New-Item -ItemType Directory -Path $CapturesDir -Force }

$RawAvi = "$VideoDir\raw_attack1.avi"
$FinalMp4 = "$EvidenceDir\Attack1_Native2D_1x.mp4"

if (Test-Path $RawAvi) { Remove-Item $RawAvi -Force }
if (Test-Path $FinalMp4) { Remove-Item $FinalMp4 -Force }

Write-Host "================================================================="
Write-Host "[V3-026-R1] Recording Pure 2D Attack 1 Gameplay..."
Write-Host "================================================================="

& $Godot --path $GameDir --write-movie $RawAvi --fixed-fps 60 -s tests/record_attack1_native2d.gd
$GodotExit = $LASTEXITCODE

Write-Host "[V3-026-R1] Godot Movie Maker finished with exit code: $GodotExit"
if ($GodotExit -ne 0 -or -not (Test-Path $RawAvi)) {
    Write-Error "Attack 1 gameplay capture failed or raw_attack1.avi not found!"
    exit 1
}

Write-Host "[V3-026-R1] Transcoding Attack 1 capture to H.264 MP4 (1280x720 60 FPS CRF 18)..."
& $FFmpeg -y -i $RawAvi -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r 60 $FinalMp4
$FFmpegExit = $LASTEXITCODE

if ($FFmpegExit -ne 0 -or -not (Test-Path $FinalMp4)) {
    Write-Error "FFmpeg transcoding failed!"
    exit 1
}

Remove-Item $RawAvi -Force

$FinalItem = Get-Item $FinalMp4
$FinalSize = $FinalItem.Length
$FinalHash = (Get-FileHash -Path $FinalMp4 -Algorithm SHA256).Hash.ToLower()
Write-Host "[V3-026-R1] Attack 1 MP4 Size: $([math]::Round($FinalSize / 1MB, 2)) MB, SHA256: $FinalHash"

Write-Host "[V3-026-R1] Extracting verification frames..."
$CaptureTimes = @(
    @{ time = "00:00:00.400"; name = "attack1_01_idle_grounding.png"; desc = "Baseline: Chibi Knight Idle Stance on 3D Stone Corridor" },
    @{ time = "00:00:01.200"; name = "attack1_02_tell_windup.png"; desc = "Attack 1 Phase 1: Anticipation / Windup Tell" },
    @{ time = "00:00:01.350"; name = "attack1_03_active_slash_apex.png"; desc = "Attack 1 Phase 2: Active Horizontal Slash Apex" },
    @{ time = "00:00:01.550"; name = "attack1_04_recovery_decel.png"; desc = "Attack 1 Phase 3: Deceleration & Recovery" },
    @{ time = "00:00:03.250"; name = "attack1_05_combat_hit_impact.png"; desc = "Attack 1 Impact: Frame-exact Contact & Hitpause" }
)

foreach ($cap in $CaptureTimes) {
    $outPath = "$CapturesDir\$($cap.name)"
    & $FFmpeg -y -ss $cap.time -i $FinalMp4 -frames:v 1 -q:v 2 $outPath
    Write-Host "  -> Extracted: $($cap.name) ($($cap.desc))"
}

Write-Host "================================================================="
Write-Host "[V3-026-R1] Pure 2D Attack 1 Recording Complete!"
Write-Host "================================================================="
