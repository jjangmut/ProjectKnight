# V3-017 — Android Device & Mobile Readiness Report

## 1. Hardware Status Declaration

> [!WARNING]
> **Status: `ANDROID_DEVICE_NOT_TESTED`**
>
> At the time of this build, zero physical Android devices were attached via ADB (`adb devices -l` returned 0 entries), and no local Android Virtual Device (AVD) emulator was installed.
> In strict accordance with ProjectKnight Core Rule 5 ("No PASS without evidence") and V3-017 explicit rules, physical hardware verification is **NOT** claimed. Desktop 60 Hz pacing and touch emulation do **NOT** certify mobile hardware performance.

---

## 2. ADB Environment Audit

```text
Host OS: Windows 11
Android SDK Path: C:\Program Files (x86)\Android\android-sdk
Build Tools Version: 35.0.0
Platform: android-34 / android-35 / android-36
Platform-Tools: adb.exe 1.0.41 (Version 35.0.2-12147458)
Java JDK: JDK 17 (D:\AI\Tools\jdk-17) / JDK 8 (C:\Program Files\Android\jdk\jdk-8.0.302.8-hotspot)
```

### ADB Device Scan Log
```text
$ adb devices -l
* daemon not running; starting now at tcp:5037
* daemon started successfully
List of devices attached
(No devices found)
```

---

## 3. Verified APK Specifications

- **File Name:** `ProjectKnight.apk`
- **Output Path:** `CLIENT/Game/builds/android/ProjectKnight.apk`
- **File Size:** 542,751,493 bytes (517.61 MB)
- **SHA-256:** `0EF28AD2E356B22EB3EA8C64F5AB810CB734F36B2CE130D40087FC60D41685A3`
- **Package ID:** `com.junypapa.projectknight`
- **Version Code:** `8`
- **Version Name:** `2.0.0`
- **Min SDK:** 24 (Android 7.0 Nougat)
- **Target SDK:** 36 (Android 16)
- **Supported ABIs:** `arm64-v8a`, `armeabi-v7a`
- **Signature Schemes:** APK Signature Scheme v2 (VERIFIED), APK Signature Scheme v3 (VERIFIED)
- **Permissions:** None requested (Offline single-player architecture, zero sensitive permissions)
- **Screen Orientation:** Handheld Orientation Sensor Landscape (1280x720 canvas_items, expand mode)

---

## 4. Mobile Controls & Viewport Architecture

1. **Fixed 4-Way D-Pad & Action Cluster:**
   - Left Cluster: Move Left, Move Right, Move Up, Move Down (drop-through one-way platforms).
   - Right Cluster: Attack (Strike), Jump (Leap), Guard (Parry/Block).
   - Multi-Touch: Independent pointer ID tracking via `InputEventScreenTouch`, verified zero action stickiness on simultaneous touches.
2. **Focus & Lifecycle Handling:**
   - `NOTIFICATION_APPLICATION_FOCUS_OUT` automatically releases all active virtual button presses and resets virtual joystick state to prevent stuck movement upon notifications or app switching.
3. **Viewport & Safe Area:**
   - Viewport base resolution: 1280x720.
   - Stretch Mode: `canvas_items`, Aspect: `expand`.
   - UI elements anchored dynamically to viewport bounds, ensuring full layout coverage on modern wide/tall aspect ratios (18:9, 19.5:9, 20:9).

---

## 5. Physical Device Sideloading Instructions

To install and verify this APK on a physical Android smartphone:

### Option A: Via USB Debugging (ADB)
1. Enable **Developer Options** and **USB Debugging** on your Android smartphone.
2. Connect the smartphone to the PC with a USB cable.
3. Run the following command in PowerShell:
   ```powershell
   & "C:\Program Files (x86)\Android\android-sdk\platform-tools\adb.exe" install -r "D:\JUNYPAPA_STUDIO\Worktrees\ProjectKnight\V3-017\CLIENT\Game\builds\android\ProjectKnight.apk"
   ```
4. Launch the app from the app drawer (`Project Knight`).

### Option B: Direct File Transfer (Sideloading)
1. Connect the smartphone to your PC via MTP (File Transfer mode).
2. Copy `ProjectKnight.apk` to the smartphone's `Download` folder.
3. On the phone, open the **Files / My Files** app and tap `ProjectKnight.apk`.
4. Allow installation from unknown sources if prompted.
5. Tap **Install** and open the application.

### On-Device Verification Checklist for Playtesters:
- [ ] App launches into `TitleScreen.tscn` without crash or ANR.
- [ ] Tap **Deploy (출격)** button; campaign transition initiates smoothly.
- [ ] Stage 1: Verify on-screen virtual touch controls (D-Pad Left/Right, Attack, Jump, Guard).
- [ ] Simultaneous multi-touch: Holding D-Pad move while tapping Attack/Jump operates without dropped inputs.
- [ ] Boss encounter (Commander): Verify telegraph readability, parry clang audio, and defeat sequence.
- [ ] Stage 1 to 5 stage transition overlays function properly with touch input.
- [ ] Check thermal load and sustained frame rate across 5+ minutes of continuous play.
