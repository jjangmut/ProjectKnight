# V3-017 — First Playable Android Build Milestone Report

## 1. Milestone Overview

- **Milestone:** V3-017 — First Playable Android Build & Real Mobile Readiness
- **Repository:** `jjangmut/ProjectKnight`
- **Working Branch:** `studio/v3-017-android-playable-build`
- **Engine:** Godot 4.7.2.stable.official.ed1daf0bf (GL Compatibility / OpenGL ES 3.0)
- **Target OS:** Android (Mobile Landscape 1280x720, Min SDK 24, Target SDK 36)
- **Status:** **PARTIAL_SUCCESS / PENDING_PHYSICAL_DEVICE_VERIFICATION**
  - **APK Deliverable:** **COMPLETED & VERIFIED** (`ProjectKnight.apk` signed, 517.61 MB)
  - **Targeted Regressions:** **100% PASS** (Full 5-stage loop + Touch controls)
  - **Physical Device:** **UNVERIFIED** (No physical device connected via ADB)

---

## 2. Key Deliverables & Validation Summary

### 2.1 Android Export Configuration & Build Environment
- **Export Mode:** Godot Native Android Template Export (`gradle_build/use_gradle_build=false`)
- **Android SDK:** `C:\Program Files (x86)\Android\android-sdk` (Build Tools `35.0.0`, Platform `android-36`)
- **Debug Keystore:** `C:\Users\jjang\.android\debug.keystore` (Key alias: `androiddebugkey`)
- **Export Output:** `CLIENT/Game/builds/android/ProjectKnight.apk`
- **File Size:** 542,751,493 bytes (517.61 MB)
- **SHA-256:** `0EF28AD2E356B22EB3EA8C64F5AB810CB734F36B2CE130D40087FC60D41685A3`

### 2.2 Package & Manifest Verification (`aapt` & `apksigner`)
- **Package ID:** `com.junypapa.projectknight`
- **Version Code:** `8`
- **Version Name:** `2.0.0`
- **Architectures:** `arm64-v8a`, `armeabi-v7a`
- **Signatures:** v2 Scheme (True), v3 Scheme (True)
- **Permissions:** Zero unnecessary/sensitive permissions requested
- **Launchable Activity:** `com.godot.game.GodotApp` (via `com.godot.game.GodotAppLauncher`)

### 2.3 Gameplay & System Preservation
- **5 Stages Intact:** Citadel Terrace Gate, Beastwood Forest Gorge, Ruined Crossbow Bastion, Titan Stone Sanctuary, Silent Abyssal Citadel all cleared consecutively with natural input routing.
- **Option C Z-Plane Lock:** Strictly preserved across all stages ($Z = 0.000$, $v_z = 0.000$).
- **Touch Controls:** 4-Way D-Pad, Strike, Leap, Parry/Block validated with multi-touch independent pointer tracking and focus loss safety.

### 2.4 Device Readiness Statement
- Physical hardware testing: **NOT CLAIMED** (`ANDROID_DEVICE_NOT_TESTED`).
- Detailed sideloading instructions provided for manual on-device installation and physical playtesting.

---

## 3. Evidence Index

- `STUDIO_V3/evidence/V3-017/APK_METADATA.json` — Exhaustive package, ABI, and cryptographic signature metadata
- `STUDIO_V3/evidence/V3-017/DEVICE_TEST_REPORT.md` — Honest ADB hardware scan status and mobile testing guide
- `STUDIO_V3/evidence/V3-017/REGRESSION_REPORT.md` — Test logs and results for 5-stage campaign and touch UI suites
- `STUDIO_V3/evidence/V3-017/EXPORT_LOG.txt` — Build log from Godot 4.7.2 Android export
