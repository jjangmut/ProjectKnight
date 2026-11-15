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

$RawAvi = "$VideoDir\raw_stage1_native2d.avi"
$FinalMp4 = "$EvidenceDir\Stage1_Native2D_Combat_1x.mp4"

if (Test-Path $RawAvi) { Remove-Item $RawAvi -Force }
if (Test-Path $FinalMp4) { Remove-Item $FinalMp4 -Force }

Write-Host "================================================================="
Write-Host "[V3-026-R1] Recording Full Stage 1 Pure 2D Combat Playthrough..."
Write-Host "================================================================="

& $Godot --path $GameDir --write-movie $RawAvi -s tests/v3_021_r1_stage1_natural_e2e.gd
$GodotExit = $LASTEXITCODE

Write-Host "[V3-026-R1] Godot Playthrough Movie Maker finished with exit code: $GodotExit"
if ($GodotExit -ne 0 -or -not (Test-Path $RawAvi)) {
    Write-Error "Stage 1 playthrough movie capture failed or raw_stage1_native2d.avi not found!"
    exit 1
}

Write-Host "[V3-026-R1] Transcoding Stage 1 capture to H.264 MP4 (1280x720 60 FPS CRF 21)..."
& $FFmpeg -y -i $RawAvi -c:v libx264 -preset slow -crf 21 -pix_fmt yuv420p -r 60 $FinalMp4
$FFmpegExit = $LASTEXITCODE

if ($FFmpegExit -ne 0 -or -not (Test-Path $FinalMp4)) {
    Write-Error "FFmpeg transcoding failed!"
    exit 1
}

Remove-Item $RawAvi -Force

$FinalItem = Get-Item $FinalMp4
$FinalSize = $FinalItem.Length
$FinalHash = (Get-FileHash -Path $FinalMp4 -Algorithm SHA256).Hash.ToLower()
Write-Host "[V3-026-R1] Stage 1 MP4 Size: $([math]::Round($FinalSize / 1MB, 2)) MB, SHA256: $FinalHash"

Write-Host "[V3-026-R1] Extracting Stage 1 Representative Frames..."
$CaptureTimes = @(
    @{ time = "00:00:04.000"; name = "stage1_01_corridor_combo1_slash.png"; desc = "Encounter 1: Native 2D Combo 1 Horizontal Slash against Grunts" },
    @{ time = "00:00:09.000"; name = "stage1_02_corridor_combo2_rise.png"; desc = "Encounter 1: Native 2D Combo 2 Rising Slash against Grunts" },
    @{ time = "00:00:15.500"; name = "stage1_03_corridor_combo3_cleave.png"; desc = "Encounter 2: Native 2D Combo 3 Heavy Overhead Cleave Finisher" },
    @{ time = "00:00:23.000"; name = "stage1_04_shield_knight_counter.png"; desc = "Encounter 3: Heavy Shield Elite Knight Counterplay & Combo" },
    @{ time = "00:00:29.000"; name = "stage1_05_boss_lane_aligned_duel.png"; desc = "Boss Sanctuary: Same-lane Boss Duel with 100% On-Screen Tracking" },
    @{ time = "00:00:33.500"; name = "stage1_06_boss_defeat_victory.png"; desc = "Boss Defeat & Stage 1 Victory" }
)

foreach ($cap in $CaptureTimes) {
    $outPath = "$CapturesDir\$($cap.name)"
    & $FFmpeg -y -ss $cap.time -i $FinalMp4 -frames:v 1 -q:v 2 $outPath
    Write-Host "  -> Extracted: $($cap.name) ($($cap.desc))"
}

Write-Host "================================================================="
Write-Host "[V3-026-R1] Full Stage 1 Recording Complete!"
Write-Host "================================================================="
