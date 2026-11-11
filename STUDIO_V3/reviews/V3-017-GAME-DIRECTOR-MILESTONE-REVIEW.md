# ProjectKnight Studio V3 — Game Director Milestone Approval Review
## Milestone V3-017: First Playable Android Build & Real Mobile Readiness (Game First)

- **Role / Evaluator:** PK_GameDirector (Product and Milestone Authority)
- **Task ID:** V3-017
- **Milestone:** First Playable Android Build & Real Mobile Readiness (Game First)
- **Frozen Target Commit SHA:** `e969512e95b67a90832c94c1e83e511dac7ee3fa` (short: `e969512`)
- **Working Branch:** `studio/v3-017-android-playable-build`
- **Parent Commit:** `9225407c5010ae1672ebff3834f85a092b3e0836` (docs(v3-016): record independent QA PASS and Game Director APPROVED reviews and update STATE.md)
- **Repository:** `jjangmut/ProjectKnight`
- **Evaluation Date:** 2026-11-11
- **Determination:** **`CONDITIONAL PASS / APPROVED FOR REPO FREEZE AND SIDELOAD VERIFICATION`**

---

## 1. Executive Summary & Product Vision Evaluation

As the Product and Milestone Authority of ProjectKnight Studio V3, I have conducted an exhaustive, evidence-based milestone quality gate audit for **Milestone V3-017 (First Playable Android Build & Real Mobile Readiness - Game First)** on branch `studio/v3-017-android-playable-build`, evaluated strictly against the target commit SHA `e969512e95b67a90832c94c1e83e511dac7ee3fa`.

### 1.1 From Desktop Vertical Slice to Real Mobile Artifact
Across Milestones V3-010 through V3-016, ProjectKnight established a formidable desktop vertical slice: a continuous 5-stage campaign, high-impact combat audio, multi-touch virtual control foundations, defeat/retry state machines, stage intermission flows, and empirical render performance proof. However, an essential commercial threshold remained uncrossed: **ProjectKnight had never generated a verified, installable Android APK or validated real mobile platform packaging.**

Milestone V3-017 was commissioned to eliminate this fundamental gap. Its primary objective was not theoretical documentation or simulated touch testing, but the concrete delivery of an installable, cryptographically signed Android Application Package (`ProjectKnight.apk`), compiled for multi-architecture mobile hardware (`arm64-v8a` and `armeabi-v7a`), configured with modern Android SDK targets, and validated against the full 5-stage campaign regression suite.

### 1.2 Truth-in-Reporting as an Inviolable Governance Pillar
In strict accordance with ProjectKnight Studio V3 Core Rule 5 ("No PASS without evidence") and the specific acceptance criteria of V3-017:
- **Zero Fabricated Mobile Metrics:** At the time of build verification, direct execution of `adb devices -l` confirmed that zero physical devices were attached. Rather than concealing this limitation behind desktop touch emulation or synthetic 60 FPS claims, the team recorded `ANDROID_DEVICE_NOT_TESTED` across all evidence artifacts (`APK_METADATA.json`, `DEVICE_TEST_REPORT.md`, `REPORT.md`).
- **Separation of Desktop and Mobile Headroom:** The team explicitly separated the 60 Hz desktop VSync benchmarks of V3-016 from real mobile GPU/CPU thermal behavior. Desktop OpenGL3 throughput on an RTX 5060 does not certify mobile SoC performance or battery thermals.
- **Actionable Sideload Protocol:** A comprehensive sideloading protocol and physical device test checklist were established, providing human playtesters and developers with an unambiguous verification path.

---

## 2. Deliverable & Cryptographic Package Audit

### 2.1 Artifact Verification
The generated APK deliverable was independently inspected and validated directly from the repository tree:
- **Relative Path:** `CLIENT/Game/builds/android/ProjectKnight.apk`
- **File Size:** 542,751,493 bytes (517.61 MB)
- **SHA-256 Checksum:** `0EF28AD2E356B22EB3EA8C64F5AB810CB734F36B2CE130D40087FC60D41685A3`
- **Package ID:** `com.junypapa.projectknight`
- **Version Code / Name:** `8` / `2.0.0`
- **SDK Targets:** Min SDK `24` (Android 7.0 Nougat), Target SDK `36` (Android 16)
- **Renderer Target:** OpenGL ES 3.0 (`0x30000`, Godot Compatibility renderer)
- **Supported ABIs:** `arm64-v8a` (64-bit ARM) and `armeabi-v7a` (32-bit ARM)

### 2.2 Signature Scheme & Android Security Compliance
Direct verification via Android SDK Build Tools 35.0.0 (`apksigner.bat verify --verbose`) confirmed:
- **APK Signature Scheme v2:** `true` (Whole-file digest verification)
- **APK Signature Scheme v3:** `true` (Key rotation support)
- **Number of Signers:** 1 (`androiddebugkey`)
- **Key Hygiene:** Signed using local development keystore (`~/.android/debug.keystore`). Zero credentials, secret keys, or release keystores were committed to the Git repository.

### 2.3 Permissions Hygiene & Offline Privacy Policy
Verification via Android Asset Packaging Tool (`aapt.exe dump badging`) confirmed that **zero dangerous or sensitive permissions** are requested by the package manifest:
- No Internet permission requested (`android.permission.INTERNET` omitted, safeguarding offline single-player privacy).
- No external storage, location, microphone, or camera permissions requested.
- Hardware features: `android.hardware.faketouch` (touch screen compatibility).

---

## 3. Gameplay Systems & Option C Invariant Preservation

### 3.1 5-Stage Continuous Campaign E2E Regression
The full campaign smoke test (`tests/v3_015_campaign_smoke.gd`) was executed live under Godot 4.7.2. All five stages and the campaign victory/replay loop passed with **Exit Code: 0** across 43.32 seconds of continuous execution:
1. **Title Screen:** Clean instantiation; real mouse press dispatched to Deploy button (`btn_new_game`) at `(971.5, 216.0)`.
2. **Stage 1 (Citadel Terrace Gate):** Wave 1 minions cleared; Commander boss defeated naturally; 20 soul shards awarded; stage intermission passed via Continue button.
3. **Stage 2 (Beastwood Forest Gorge):** Natural entry verified; Beast minions defeated; Beast Chieftain defeated; 25 soul shards awarded; stage intermission passed.
4. **Stage 3 (Ruined Crossbow Bastion):** Crossbow minions cleared; Crossbow Commander defeated; 30 soul shards awarded; stage intermission passed.
5. **Stage 4 (Titan Stone Sanctuary):** Heavy Golems cleared; Golem Guardian defeated; 35 soul shards awarded; stage intermission passed.
6. **Stage 5 (Silent Abyssal Citadel):** Both Elite Abyssal Knights defeated; Abyssal Arbiter boss spawned (HP 38, Poise 18); Phase 2 transition triggered at HP 20; Judgment Storm survived; Abyssal Arbiter naturally defeated at HP 0.
7. **Campaign Victory & Loop:** `CampaignVictoryPanel` displayed; Return to Title button clicked; `TitleScreen` reloaded cleanly; second campaign Deploy initiated without memory or node duplication.

### 3.2 Strict Adherence to Option C Plane Lock ($Z=0.000$)
Across all 5 stages, player movement, enemy patrols, boss charges, and projectile trajectories strictly obeyed the Option C gameplay plane lock:
$$\max(|pos_z|) = 0.0000, \quad \max(|vel_z|) = 0.0000$$
Zero Z-axis drift or out-of-plane clipping occurred.

### 3.3 Zero Balance Mutation
Inspection of repository changes against base commit `9225407` confirmed that zero game balance values (player HP, slash damage, enemy stats, soul shard payouts) were altered. The deliverable focused strictly on packaging, touch controls, and platform compatibility.

---

## 4. Mobile Controls & Lifecycle Architecture

### 4.1 Multi-Touch Robustness & Pointer Separation
Verification via `tests/v3_010_test_touch_repro.gd` (11/11 PASSED) and `tests/v3_003_real_touch_ui.gd` (ALL PASSED) validated:
- **Independent Pointer Tracking:** Simultaneous touch inputs (e.g., holding virtual joystick move_right with Finger 0 while tapping Strike/Jump with Finger 1) maintain complete independence without cross-talk or dropped releases.
- **Mouse Emulation Isolation:** Synthetic mouse events synthesized by the operating system do not corrupt active touch pointers or reset joystick vectors.
- **Slide Transitions:** Sliding a touch pointer from one virtual action button into another (e.g., sliding off Guard into Dash) cleanly releases the first action and activates the second.

### 4.2 Lifecycle & Focus Loss Safety
In mobile environments, incoming phone calls, OS notifications, and home-bar gestures frequently trigger application focus loss. In `SideQVVirtualTouchControls`:
- Notification `NOTIFICATION_APPLICATION_FOCUS_OUT` is trapped.
- All active virtual action inputs are immediately released and the virtual joystick is recentered.
- This prevents "stuck running" or unintended combat actions when switching back to the app.

---

## 5. Game Director 10-Category Quality Scorecard

In accordance with ProjectKnight Production Rules (RULE 3: Average >= 8.5, No critical category < 8.0), the milestone deliverables, packaging integrity, and gameplay systems have been evaluated:

| No. | Evaluation Category | Score (/10) | Game Director Assessment & Quality Notes |
|:---:|---|:---:|---|
| 1 | **Commercial Game Vision & Mobile Identity** | **9.2** | The transition to a genuine Android package (`com.junypapa.projectknight`) brings ProjectKnight within reach of mobile commercial launch. Orientation locked to landscape (expand mode) fits standard smartphone gaming ergonomics. |
| 2 | **APK Packaging, ABI & Platform Integrity** | **9.5** | Clean Godot 4.7.2 Compatibility export. Includes both `arm64-v8a` (modern 64-bit standard) and `armeabi-v7a` (legacy 32-bit compatibility). Target SDK 36 ensures forward compatibility with Android 15/16. |
| 3 | **Cryptographic Security & Permissions Hygiene** | **9.6** | Dual v2/v3 signature schemes validated. Zero sensitive permissions requested; offline single-player privacy strictly respected. Debug keystore kept local without leaking secrets. |
| 4 | **Virtual Touch Controls & Multi-Touch Architecture** | **9.4** | Multi-touch pointer ownership cleanly isolates movement and combat actions. Zero action stickiness on simultaneous touches. Slide-button transition and mouse emulation immunity verified. |
| 5 | **Viewport Responsiveness & Safe Area Layout** | **9.1** | Viewport anchored dynamically to 1280x720 base with canvas expand mode. Compatible with wide aspect ratios (18:9, 19.5:9, 20:9). Dynamic camera frustum keeps combatants centered. |
| 6 | **Option C Plane Lock ($Z=0.000$) & 5-Stage Loop** | **9.8** | 100% compliant across continuous 5-stage playthrough. Actors and projectiles remain strictly constrained to $Z=0.000, v_z=0.000$. Campaign victory and return-to-title replay cycle operate cleanly. |
| 7 | **Combat Systems, Audio & VFX Preservation** | **9.5** | All audio import resources (.wav.import) properly bundled. Golden curved blade arcs, ground contact shadows, boss tell stingers, and parry clashes operate without regression. |
| 8 | **Truth-in-Reporting & Metric Governance** | **9.8** | Exemplary adherence to Rule 5. Rather than claiming simulated or desktop FPS as mobile performance, the team honestly declared `ANDROID_DEVICE_NOT_TESTED`. Clear distinction between desktop VSync and mobile thermal reality. |
| 9 | **Sideload Protocol & Playability Readiness** | **9.3** | Clear step-by-step sideloading runbook (ADB and USB MTP) and on-device playtesting checklist provided. Real 517.61 MB APK immediately available for physical verification. |
| 10 | **Overall Production & Commercial Impression** | **9.2** | An authentic, installable mobile milestone. The foundation is solidly laid for physical hardware playtesting and subsequent mobile optimization passes. |
| -- | **OVERALL DIRECTOR AVERAGE** | **9.44 / 10.0** | **QUALITY GATE FULLY SATISFIED (Average >= 8.5, All Categories >= 8.0)** |

---

## 6. Sideload Verification Protocol & Next Steps

To transition this milestone from repo freeze to unconditioned production sign-off, the following physical playtesting protocol is established for human playtesters and developers:

### 6.1 Installation Steps
1. Transfer `CLIENT/Game/builds/android/ProjectKnight.apk` to an Android phone running Android 7.0 (API 24) or higher.
2. Install via ADB (`adb install -r ProjectKnight.apk`) or via phone file manager.
3. Grant permission to install from unknown sources if prompted.

### 6.2 Mandatory Physical Device Verification Checklist
- [ ] **Cold Launch:** App launches directly into `TitleScreen.tscn` without crash or ANR.
- [ ] **Touch Calibration:** Tap **Deploy (출격)**; verify button hit-box and transition responsiveness.
- [ ] **Dual-Touch Combat:** Hold D-Pad Left/Right with left thumb while tapping Attack and Jump with right thumb. Verify zero dropped or locked inputs.
- [ ] **Stage 1 Playthrough:** Complete Stage 1 and defeat the Commander boss using virtual controls.
- [ ] **Intermission & Victory UI:** Verify that the stage clear intermission overlay and Continue button respond cleanly to touch.
- [ ] **Audio & Haptics:** Verify audio playback through phone speakers and headphones.
- [ ] **Thermal / Frame Stability:** Observe thermal behavior and frame stability over 5+ minutes of continuous play.

---

## 7. Final Game Director Milestone Determination

- **Milestone:** V3-017 — First Playable Android Build & Real Mobile Readiness (Game First)
- **Target Deliverable:** `CLIENT/Game/builds/android/ProjectKnight.apk` (517.61 MB, Signed, Verified)
- **Director Quality Score:** **9.44 / 10.0** (All categories >= 9.1)
- **Option C Compliance:** **100% Verified** ($Z=0.000$, zero drift across 5 stages)
- **Regression Status:** **100% PASS** (Full campaign loop + Touch test suites)
- **Open Blockers:** **0 P0 / 0 P1**

### Formal Determination:
# **`CONDITIONAL PASS / APPROVED FOR REPO FREEZE AND SIDELOAD VERIFICATION`**

The Android debug build artifact and supporting packaging infrastructure fulfill all engineering, architectural, and quality governance requirements for Milestone V3-017. The milestone is approved for repository freeze and deployment to physical test devices.

Signed,  
**PK_GameDirector**  
*Product and Milestone Authority, ProjectKnight Studio V3*  
*Commit Audited: `e969512e95b67a90832c94c1e83e511dac7ee3fa`*