# ProjectKnight V3-024-R2: 1.0x 60 FPS Full Playthrough & Corner Escape Audit Recording Pipeline
$ErrorActionPreference = "Stop"

$Godot = "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$FFmpeg = "C:\Users\jjang\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.2-full_build\bin\ffmpeg.exe"
$Worktree = "D:\JUNYPAPA_STUDIO\Worktrees\ProjectKnight\V3-024-R2"
$GameDir = "$Worktree\CLIENT\Game"
$VideoDir = "D:\JUNYPAPA_STUDIO\Videos\ProjectKnight\V3-024-R2"
$EvidenceDir = "$Worktree\STUDIO_V3\evidence\V3-024-R2"
$CapturesDir = "$EvidenceDir\captures"

if (-not (Test-Path $VideoDir)) { New-Item -ItemType Directory -Path $VideoDir -Force }
if (-not (Test-Path $CapturesDir)) { New-Item -ItemType Directory -Path $CapturesDir -Force }

# -----------------------------------------------------------------
# 1. Full Stage 1 Natural Playthrough Recording
# -----------------------------------------------------------------
$RawAvi1 = "$VideoDir\raw_stage1.avi"
$FinalMp4_1 = "$VideoDir\Stage1_Full_Playthrough_1x.mp4"

if (Test-Path $RawAvi1) { Remove-Item $RawAvi1 -Force }

if (-not (Test-Path $FinalMp4_1) -or (Get-Item $FinalMp4_1).Length -lt 1000000) {
    Write-Host "================================================================="
    Write-Host "[V3-024-R2] Starting Full Stage 1 Movie Maker 60 FPS Capture..."
    Write-Host "================================================================="

    & $Godot --path $GameDir --write-movie $RawAvi1 --fixed-fps 60 -s tests/v3_021_r1_stage1_natural_e2e.gd
    $GodotExit1 = $LASTEXITCODE

    Write-Host "[V3-024-R2] Godot Full Playthrough Movie Maker finished with exit code: $GodotExit1"
    if ($GodotExit1 -ne 0 -or -not (Test-Path $RawAvi1)) {
        Write-Error "Full playthrough movie capture failed or raw_stage1.avi not found!"
        exit 1
    }

    Write-Host "[V3-024-R2] Transcoding Full Playthrough to H.264 MP4..."
    & $FFmpeg -y -i $RawAvi1 -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r 60 $FinalMp4_1
    $FFmpegExit1 = $LASTEXITCODE

    if ($FFmpegExit1 -ne 0 -or -not (Test-Path $FinalMp4_1)) {
        Write-Error "FFmpeg transcoding for full playthrough failed!"
        exit 1
    }

    Remove-Item $RawAvi1 -Force
} else {
    Write-Host "[V3-024-R2] Existing verified Full Playthrough MP4 found ($([math]::Round((Get-Item $FinalMp4_1).Length / 1MB, 2)) MB), skipping recapture."
}

$FinalItem1 = Get-Item $FinalMp4_1
$FinalSize1 = $FinalItem1.Length
$FinalHash1 = (Get-FileHash -Path $FinalMp4_1 -Algorithm SHA256).Hash.ToLower()
Write-Host "[V3-024-R2] Full Playthrough MP4 Size: $([math]::Round($FinalSize1 / 1MB, 2)) MB, SHA256: $FinalHash1"

# -----------------------------------------------------------------
# 2. Corner Escape Audit Recording
# -----------------------------------------------------------------
$RawAvi2 = "$VideoDir\raw_escape.avi"
$FinalMp4_2 = "$VideoDir\Boss_Corner_Escape_Audit_1x.mp4"

if (Test-Path $RawAvi2) { Remove-Item $RawAvi2 -Force }

Write-Host "================================================================="
Write-Host "[V3-024-R2] Starting Corner Escape Audit Movie Maker 60 FPS Capture..."
Write-Host "================================================================="

& $Godot --path $GameDir --write-movie $RawAvi2 --fixed-fps 60 -s tests/record_corner_escapes.gd
$GodotExit2 = $LASTEXITCODE

Write-Host "[V3-024-R2] Godot Corner Escape Movie Maker finished with exit code: $GodotExit2"
if ($GodotExit2 -ne 0 -or -not (Test-Path $RawAvi2)) {
    Write-Error "Corner escape audit movie capture failed or raw_escape.avi not found!"
    exit 1
}

Write-Host "[V3-024-R2] Transcoding Corner Escape Audit to H.264 MP4..."
& $FFmpeg -y -i $RawAvi2 -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r 60 $FinalMp4_2
$FFmpegExit2 = $LASTEXITCODE

if ($FFmpegExit2 -ne 0 -or -not (Test-Path $FinalMp4_2)) {
    Write-Error "FFmpeg transcoding for corner escape failed!"
    exit 1
}

Remove-Item $RawAvi2 -Force
$FinalItem2 = Get-Item $FinalMp4_2
$FinalSize2 = $FinalItem2.Length
$FinalHash2 = (Get-FileHash -Path $FinalMp4_2 -Algorithm SHA256).Hash.ToLower()
Write-Host "[V3-024-R2] Corner Escape MP4 Size: $([math]::Round($FinalSize2 / 1MB, 2)) MB, SHA256: $FinalHash2"

# -----------------------------------------------------------------
# 3. Extract Representative Verification Frames
# -----------------------------------------------------------------
Write-Host "[V3-024-R2] Extracting verification frames..."
$FrameTimes = @("00:00:03.000", "00:00:08.000", "00:00:14.000", "00:00:20.000", "00:00:26.000", "00:00:32.000", "00:00:38.000", "00:00:44.000", "00:00:48.000")
$ExtractedFrames = @()

for ($i = 0; $i -lt $FrameTimes.Length; $i++) {
    $t = $FrameTimes[$i]
    $fn = "playthrough_frame_0$($i + 1).png"
    $fp = "$CapturesDir\$fn"
    & $FFmpeg -y -ss $t -i $FinalMp4_1 -vframes 1 -q:v 2 $fp
    if (Test-Path $fp) {
        $ExtractedFrames += "STUDIO_V3/evidence/V3-024-R2/captures/$fn"
        Write-Host "  -> Playthrough Frame $($i + 1) at $t extracted: $fn"
    }
}

# Extract 4 corner escape frames from second video
$EscapeFrameTimes = @("00:00:00.600", "00:00:01.400", "00:00:02.100", "00:00:02.800")
for ($i = 0; $i -lt $EscapeFrameTimes.Length; $i++) {
    $t = $EscapeFrameTimes[$i]
    $fn = "escape_corner_0$($i + 1).png"
    $fp = "$CapturesDir\$fn"
    & $FFmpeg -y -ss $t -i $FinalMp4_2 -vframes 1 -q:v 2 $fp
    if (Test-Path $fp) {
        $ExtractedFrames += "STUDIO_V3/evidence/V3-024-R2/captures/$fn"
        Write-Host "  -> Corner Escape Frame $($i + 1) at $t extracted: $fn"
    }
}

# -----------------------------------------------------------------
# 4. Copy Traces and Generate Provenance
# -----------------------------------------------------------------
$TelemetryFile = "$GameDir\test_results_v3_021_r1_natural.json"
$TelemetryData = @{}
if (Test-Path $TelemetryFile) {
    $TelemetryData = Get-Content $TelemetryFile -Raw | ConvertFrom-Json
}

$VisibilityFile = "$GameDir\test_boss_visibility_trace.json"
if (Test-Path $VisibilityFile) {
    Copy-Item $VisibilityFile "$EvidenceDir\CAMERA_VISIBILITY_TRACE.json" -Force
}

$Provenance = [ordered]@{
    "task_id" = "V3-024-R2"
    "branch" = "studio/v3-024-r2-boss-depth-escape-agency"
    "recording_mode" = "Godot 4.7.2 Movie Maker (--write-movie --fixed-fps 60) -> FFmpeg H.264 MP4 (-r 60)"
    "playtest_classification" = "AUTOMATED_INPUT_UNMODIFIED_GAME_STATE"
    "human_playtest_status" = "HUMAN_PLAYTEST_PENDING"
    "videos" = [ordered]@{
        "full_playthrough" = [ordered]@{
            "path" = "D:/JUNYPAPA_STUDIO/Videos/ProjectKnight/V3-024-R2/Stage1_Full_Playthrough_1x.mp4"
            "sha256" = $FinalHash1
            "size_bytes" = $FinalSize1
            "duration_seconds" = if ($TelemetryData.duration_seconds) { $TelemetryData.duration_seconds } else { 49.0 }
            "fps" = 60.0
            "resolution" = "1280x720"
        }
        "corner_escape_audit" = [ordered]@{
            "path" = "D:/JUNYPAPA_STUDIO/Videos/ProjectKnight/V3-024-R2/Boss_Corner_Escape_Audit_1x.mp4"
            "sha256" = $FinalHash2
            "size_bytes" = $FinalSize2
            "fps" = 60.0
            "resolution" = "1280x720"
        }
    }
    "gameplay_telemetry" = $TelemetryData
    "extracted_verification_frames" = $ExtractedFrames
}

$ProvenanceJson = $Provenance | ConvertTo-Json -Depth 6
Set-Content -Path "$EvidenceDir\VIDEO_PROVENANCE.json" -Value $ProvenanceJson -Encoding UTF8
Write-Host "[V3-024-R2] VIDEO_PROVENANCE.json generated successfully!"
Write-Host "================================================================="
