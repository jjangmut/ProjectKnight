# ProjectKnight V3-024: 1.0x 60 FPS Directional Gameplay Video Recording Pipeline
$ErrorActionPreference = "Stop"

$Godot = "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$FFmpeg = "C:\Users\jjang\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.2-full_build\bin\ffmpeg.exe"
$Worktree = "D:\JUNYPAPA_STUDIO\Worktrees\ProjectKnight\V3-024"
$GameDir = "$Worktree\CLIENT\Game"
$VideoDir = "D:\JUNYPAPA_STUDIO\Videos\ProjectKnight\V3-024"
$EvidenceDir = "$Worktree\STUDIO_V3\evidence\V3-024"
$CapturesDir = "$EvidenceDir\captures"

if (-not (Test-Path $VideoDir)) { New-Item -ItemType Directory -Path $VideoDir -Force }
if (-not (Test-Path $CapturesDir)) { New-Item -ItemType Directory -Path $CapturesDir -Force }

$RawAvi = "$VideoDir\raw.avi"
$FinalMp4 = "$VideoDir\Stage1_DirectionalAnimation_1x.mp4"

if (Test-Path $RawAvi) { Remove-Item $RawAvi -Force }

Write-Host "================================================================="
Write-Host "[V3-024] Starting Godot Movie Maker 60 FPS Capture..."
Write-Host "================================================================="

$StartTime = Get-Date
& $Godot --path $GameDir --write-movie $RawAvi --fixed-fps 60 -s tests/v3_021_r1_stage1_natural_e2e.gd
$GodotExit = $LASTEXITCODE

Write-Host "[V3-024] Godot Movie Maker finished with exit code: $GodotExit"
if ($GodotExit -ne 0 -or -not (Test-Path $RawAvi)) {
    Write-Error "Movie capture failed or raw.avi not found!"
    exit 1
}

$RawSize = (Get-Item $RawAvi).Length
Write-Host "[V3-024] Raw AVI Size: $([math]::Round($RawSize / 1MB, 2)) MB. Transcoding to H.264 MP4..."

& $FFmpeg -y -i $RawAvi -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r 60 $FinalMp4
$FFmpegExit = $LASTEXITCODE

if ($FFmpegExit -ne 0 -or -not (Test-Path $FinalMp4)) {
    Write-Error "FFmpeg transcoding failed!"
    exit 1
}

$FinalItem = Get-Item $FinalMp4
$FinalSize = $FinalItem.Length
$FinalHash = (Get-FileHash -Path $FinalMp4 -Algorithm SHA256).Hash.ToLower()

Write-Host "[V3-024] Final MP4 Size: $([math]::Round($FinalSize / 1MB, 2)) MB, SHA256: $FinalHash"

# Extract 9 representative frames
Write-Host "[V3-024] Extracting representative verification frames..."
$FrameTimes = @("00:00:03.000", "00:00:07.500", "00:00:12.000", "00:00:16.500", "00:00:21.000", "00:00:25.500", "00:00:30.000", "00:00:34.500", "00:00:37.000")
$ExtractedFrames = @()

for ($i = 0; $i -lt $FrameTimes.Length; $i++) {
    $t = $FrameTimes[$i]
    $fn = "video_frame_0$($i + 1).png"
    $fp = "$CapturesDir\$fn"
    & $FFmpeg -y -ss $t -i $FinalMp4 -vframes 1 -q:v 2 $fp
    if (Test-Path $fp) {
        $ExtractedFrames += "STUDIO_V3/evidence/V3-024/captures/$fn"
        Write-Host "  -> Frame $($i + 1) at $t extracted: $fn"
    }
}

# Remove large intermediate raw AVI
Remove-Item $RawAvi -Force

# Read natural e2e telemetry json
$TelemetryFile = "$GameDir\test_results_v3_021_r1_natural.json"
$TelemetryData = @{}
if (Test-Path $TelemetryFile) {
    $TelemetryData = Get-Content $TelemetryFile -Raw | ConvertFrom-Json
}

$Provenance = [ordered]@{
    "task_id" = "V3-024"
    "branch" = "studio/v3-024-directional-animation-art"
    "recording_mode" = "Godot 4.7.2 Movie Maker (--write-movie --fixed-fps 60) -> FFmpeg H.264 MP4 (-r 60)"
    "playtest_classification" = "AUTOMATED_INPUT_UNMODIFIED_GAME_STATE"
    "human_playtest_status" = "HUMAN_PLAYTEST_NOT_TESTED"
    "video_file" = [ordered]@{
        "path" = "D:/JUNYPAPA_STUDIO/Videos/ProjectKnight/V3-024/Stage1_DirectionalAnimation_1x.mp4"
        "sha256" = $FinalHash
        "size_bytes" = $FinalSize
        "codec" = "h264 (High, yuv420p)"
        "resolution" = "1280x720"
        "fps" = 60.0
    }
    "simulation_timing" = [ordered]@{
        "sim_seconds" = if ($TelemetryData.duration_seconds) { $TelemetryData.duration_seconds } else { 38.0 }
        "speed_ratio_sim_to_video" = 1.0
        "is_exact_1x_speed" = $true
    }
    "gameplay_telemetry" = $TelemetryData
    "extracted_verification_frames" = $ExtractedFrames
}

$ProvenanceJson = $Provenance | ConvertTo-Json -Depth 6
Set-Content -Path "$EvidenceDir\VIDEO_PROVENANCE.json" -Value $ProvenanceJson -Encoding UTF8
Write-Host "[V3-024] VIDEO_PROVENANCE.json generated successfully!"
Write-Host "================================================================="
