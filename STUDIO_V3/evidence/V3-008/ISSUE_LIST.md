# V3-008 Issue List & Operational Status

**Milestone:** V3-008 — Five-Stage Playability & Combat Readability Polish (Actual Game First)  
**Date:** 2026-11-09  
**Target:** Desktop PC (Windows 11 / Godot 4.7.2 stable / NVIDIA RTX 5060)  

---

## 1. Resolved Issues in V3-008

| Issue ID | Severity | Component | Summary | Resolution |
| :--- | :--- | :--- | :--- | :--- |
| **ISSUE-V3-008-01** | P0 (UX/Flow) | `side_qv_campaign.gd` | Missing Replay/Return action in `CampaignVictoryPanel` causing dead-end upon campaign completion | Added styled panel with `ReplayCampaignButton` (`load_stage(0)`) and `ReturnTitleButton` (`TitleScreen.tscn`) |
| **ISSUE-V3-008-02** | P1 (Readability) | `side_qv_abyssal_arbiter.gd` | Abyssal Arbiter shadow blink and crescent wave telegraphs too fast (0.18s) and low contrast against dark fog | Increased window to 0.32s, enlarged danger ring (radii 0.75/1.15), enhanced crimson-gold emission (4.8x), and added explicit text markers |
| **ISSUE-V3-008-03** | P1 (Game Feel) | `side_qv_player.gd` | Just Parry clash lacked freeze-frame hit-stop, feeling hollow compared to heavy attacks | Integrated `GameFeelManager.hit_stop_3d(0.08, 0.04)` into `_trigger_parry_flash()` for crisp blade clash impact |

---

## 2. Platform Status & Limitations (Honest Reporting)

### A. Android Hardware Status
- **Status:** `NOT_TESTED` (Physical Android device not connected to desktop test harness).
- Touch controls and GUI touch routing exist in GDScript codebase and pass simulated desktop touch/mouse injection, but frame rates, thermal throttling, and APK install packages on physical ARM hardware remain unverified on real Android devices.

### B. Human Playtest Status
- **Status:** `HUMAN_PLAYTEST_NOT_VERIFIED` (Automated desktop simulated input verification only).
- All 5 stages and Title-to-Victory routes have been verified via engine-level `InputEventMouseButton`, `Input.action_press()`, and natural collision triggers with zero cheats or artificial overrides. However, comprehensive human tactile playtesting with gamepad/keyboard across diverse player skill levels remains a future playability milestone.

### C. Nondeterministic Boss Attack Observation
- In natural continuous E2E runs, boss AI pattern rolls are distance- and timer-dependent. `Abyssal Arbiter`'s `JUDGMENT_STORM` and `MELEE_CLEAVE` occurred naturally in the full run (`stage5_boss_storm_seen_e2e = true`). `SHADOW_BLINK_STRIKE` and `DARK_CRESCENT_WAVE` were verified under targeted isolated fixtures (`ISOLATED_VERIFIED`). Neither attack is claimed as naturally observed in E2E when not rolled by the AI (`E2E_SEEN = false`).

---

## 3. Backlog Polish Items (P2 / P3 Non-Blocking)

| Item ID | Priority | Description | Target |
| :--- | :--- | :--- | :--- |
| **BACKLOG-POLISH-01** | P2 | Add stage transition curtain wipe animation between stages in `SideQVCampaign` | Post-V3-008 |
| **BACKLOG-POLISH-02** | P2 | Custom UI sounds on Victory Screen buttons (`btn_replay`, `btn_title`) | Post-V3-008 |
| **BACKLOG-POLISH-03** | P3 | Gamepad focus highlight shader on tactical buttons | Android Porting Phase |
