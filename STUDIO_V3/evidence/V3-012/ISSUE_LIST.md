# V3-012 Issue List & Quality Audit Tracking

## 1. Resolved Issues in V3-012

| Issue ID | Severity | Description | Resolution Status | Verified By |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-V3-012-001** | P1 (MAJOR) | **Unresponsive Enemy Hit Feedback**: Enemies struck by sword attacks only tinted red with zero recoil or counter differentiation, causing combat to feel weightless. | **FIXED**: Added distinct damage confirmation flash (white-hot for standard, radiant cyan-gold for counter) and physical micro-recoil ($2.2\text{ m/s}$ to $3.6\text{ m/s}$) clamped to X axis on $Z=0$. | `v3_012_encounter_readability_verification.gd` (Checks 1-5) |
| **ISSUE-V3-012-002** | P1 (MAJOR) | **Vulnerable Death Fade & Duplicate Signal Risk**: Defeated minions lingered for 0.3s with active collision layers/monitoring and visible HP bars, allowing phantom hits and duplicate `enemy_defeated` reward dispatches. | **FIXED**: Overhauled `_die()` across all minion classes with atomic `_death_signaled` boolean guard, immediate collision zeroing, immediate attack monitoring disablement, immediate HP bar hiding, and toroidal defeat burst ring. | `v3_012_encounter_readability_verification.gd` (Checks 4-6) |
| **ISSUE-V3-012-003** | P1 (MAJOR) | **Stage 3 Crossbow Commander Single-Line Telegraph**: The 3-way fan volley only rendered 1 horizontal line on the floor, failing to telegraph the angled trajectory of bolts. | **FIXED**: Implemented `_create_fan_aim_lines()` projecting 3 distinct laser trajectories in the X/Y plane for angles $[-18^\circ, 0^\circ, +18^\circ]$ on $Z=0$. | `v3_012_encounter_readability_verification.gd` (Check 7) |
| **ISSUE-V3-012-004** | P1 (MAJOR) | **Stage 4 Golem Slam Telegraph Offset**: The danger warning ring was centered at feet (radius 2.75m) instead of the actual slam origin (offset $+1.5\text{m}$, radius 4.5m), causing unfair player damage outside warning area. | **FIXED**: Re-anchored telegraph danger torus ring directly at `slam_origin` with exact 4.5m radius, eliminating spatial offset to $0.0000\text{ m}$. | `v3_012_encounter_readability_verification.gd` (Check 8) |

---

## 2. Open Backlog Items (P2 / P3 Non-Blocking Polish)

| Backlog ID | Severity | Component | Description | Disposition |
| :--- | :--- | :--- | :--- | :--- |
| **POLISH-V3-013-001** | P2 (MINOR) | Boss VFX | Boss defeat currently triggers an alpha fade. Could benefit from a dramatic particle shatter or slow-motion freeze stinger. | Scheduled for Post-V3 Polish Milestone |
| **POLISH-V3-013-002** | P3 (POLISH) | Mobile Haptics | Add tactile vibration support on Android for heavy hit-stop and parry clashing. | Deferred to Mobile Hardware Milestone |

---

## 3. Disclosures & Boundaries
- **`ANDROID_NOT_TESTED`**: All tests were executed on PC (Windows x86_64, Godot 4.7.2 stable, OpenGL3 Compatibility driver on NVIDIA GeForce RTX 5060 Laptop GPU). Real Android device performance and touch screen feel are not claimed.
- **`HUMAN_PLAYTEST_NOT_VERIFIED`**: Automated real-input bot and programmatic headless suites verified gameplay stability and event ordering. Subjective human game feel requires dedicated playtesting sessions.
- **`COMMERCIAL_RELEASE_READINESS_NOT_CLAIMED`**: V3-012 fulfills vertical slice milestone criteria; commercial market release readiness requires full art pass, localization, monetization integration, and certified hardware testing.
