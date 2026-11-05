# V3-001 — Independent Game Director Review Report

**Task ID:** `V3-001`  
**Task Title:** Playable Baseline Audit & Gameplay Plane Decision  
**Reviewer:** `PK_GameDirector` (Product & Milestone Authority)  
**Date:** 2026-11-06  
**Audited Source SHA:** `a71223615d0b77e36dd85edb24e138fc67ecc140`  
**Working Branch:** `studio/v3-001-playable-baseline`  
**Director Verdict:** **PASS (Audit Completeness & Gameplay Plane Ratification)**  
**Milestone Status:** **V3-001 Two-Key Approval Satisfied; V3-003 Strictly BLOCKED**

---

## 1. Executive Authority Verdict

As Game Director and Product Authority of ProjectKnight Studio V3, I have executed an independent, creative, and technical inspection of the playable baseline evidence delivered under TASK `V3-001`.

The objective of `V3-001` was not to deliver a shippable final build, but to establish an unvarnished, authentic playable baseline of Stage 1 (`SideQVStage1.tscn` via `SideQVCampaign.tscn`), honestly measure performance, inspect visual and gameplay integration, catalog all existing defects, and decisively establish the gameplay motion plane architecture.

Based on my direct evaluation of the rendered pixels (`captures/originals/*.png`), 14,404 frames of PC performance telemetry (`performance/performance.json`), and the comparative motion analysis (`DESIGN_DECISION.md`), **I formally declare TASK V3-001 as PASS.**

Combined with the `PK_QALead` PASS verdict issued in `QA_REVIEW.md`, **TASK V3-001 has achieved full Two-Key Approval.**

---

## 2. Creative & Visual Quality Evaluation

The visual audit suite (11 unedited $1280 \times 720$ captures) was inspected against our commercial quality standards:

### 2.1 Category Breakdown & Director Scoring (10-Point Scale)

| Evaluation Category | Score | Director Observations & Quality Assessment |
| :--- | :---: | :--- |
| **Visual Identity & Theme** | **8.6 / 10** | High-fantasy chivalric anime aesthetic is cohesive. Citadel Terrace Gate presents an inviting, heroic daytime setting with good architectural language (stone balustrades, battlements, glowing arcane pillars). |
| **2D Character Readability** | **8.8 / 10** | Paladin sprite rendered with `pixel_size: 0.00282` (~1.77m scale) from 780x780 source art is crisp and sharp on a 1280x720 canvas. Outlines, visor slit, and blue/gold tunic are immediately identifiable. |
| **3D Environment & Vista** | **8.7 / 10** | Flagstone paving with triplanar surface mapping, glowing golden runic seal (`CentralRunicSeal`), and distant mountain vista quad provide strong depth and atmospheric scale. |
| **2D / 3D Grounding & Shadows** | **8.5 / 10** | Directional sunlight (energy 1.45, angle -46°, -32°) casts sharp real-time shadows from the 2D sprite onto the 3D ground. However, fixed-Y billboarding introduces minor ground penetration near extreme front curbs (`ISSUE-V3-001-04`). |
| **Lighting & VFX Readability** | **8.5 / 10** | The glowing cyan-blue torus barrier (`GuardBarrier3D`) and radiant spear thrust (`SlashVisual3D`) provide instantaneous combat feedback. Emissive bloom ($2.4\times$) on ground runes is tasteful without washing out the foreground. |
| **Camera Presentation & Composition** | **7.5 / 10** | **CRITICAL DEFECT DETECTED**: In `08_boss_telegraph.png`, `09_boss_combat.png`, and `10_stage_result.png`, a massive foreground stone wall/pillar occludes nearly 40% of the screen, completely blocking combat action and hiding the player. (Filed as `ISSUE-V3-001-07`). |
| **Gameplay Readability & Motion** | **8.0 / 10** | Horizontal traversal and jump curves are crisp. However, free Z-depth movement (Option B) causes frequent melee attack whiffing and awkward screen elevation shifts under the -32° camera pitch. (Resolved via Option C ratification). |
| **Mobile Readiness & Ergonomics** | **7.0 / 10** | Tactical unit plate, progress bar, and combo HUD are well-proportioned for 1280x720 mobile landscape. However, **zero virtual touch controls or action buttons exist** (`ISSUE-V3-001-01`), rendering the game unplayable on mobile touchscreens without hardware peripherals. |
| **Commercial-Grade Impression** | **8.2 / 10** | The baseline demonstrates legitimate commercial promise and a solid technical engine foundation. It feels like an authentic vertical slice in mid-production rather than a loose prototype. |

**Baseline Visual Average:** **8.31 / 10**  
*(Satisfactory for Baseline Audit Phase; Target $\ge 8.5$ will be enforced for Milestone VS-001 closure after Option C and touch controls are implemented).*

---

## 3. Formal Ratification of Gameplay Plane Decision

In accordance with Section 0 and Section 13 of `AGENTS.md` ("Fixed Side-Scrolling Gameplay Plane"), I have reviewed the three architectures detailed in `DESIGN_DECISION.md`:

- **Option A (Strict 2D Side-Scroller):** Discards high-value 3D flagstone arenas, depth vistas, and real-time lighting assets developed across Stages 1–5. **REJECTED.**
- **Option B (Existing 2.5D Belt-Scroller):** Moving across $Z \in [-4.4, 4.4]$ introduces severe attack whiffing, causes character vertical jitter in the -32° camera view, and requires an 8-way virtual joystick that is notoriously imprecise on mobile touchscreens. **REJECTED.**
- **Option C (Visually 2.5D with Fixed 2D Horizontal Gameplay Plane):**
  - **Combat Precision:** Player and enemy physics are constrained to $Z = 0.0$. Melee hitboxes, dash evasions, and parry windows resolve purely along $X/Y$, eliminating all Z-axis whiffing.
  - **Asset Preservation:** Retains 100% of the 3D meshes, triplanar flagstones, dynamic sunlight shadows, glowing floor runes, and panoramic backgrounds.
  - **Mobile Ergonomics:** Perfectly aligns with a clean 4-button horizontal touch scheme (Left, Right, Jump, Attack/Guard/Dash).
  - **Production Efficiency:** Minimal code modification: clamp $Z=0$ in `_physics_process()`, tune camera FOV/framing, and simplify enemy AI to linear spatial pressure.

### Formal Director Directive:
> **OPTION C IS FORMALLY ADOPTED AS THE DEFINITIVE ARCHITECTURAL STANDARD FOR PROJECTKNIGHT.**  
> In task `V3-003`, `PK_ClientLead` and `PK_ArtDirector` shall constrain player and enemy motion to the single horizontal combat plane ($Z = 0.0$), optimize camera framing, and align all combat collision shapes accordingly.

---

## 4. Defect Registry & Required Gating Actions

The audit accurately identified 6 open defects. As Game Director, I am adding **`ISSUE-V3-001-07`** to ensure camera occlusion is prioritized alongside mobile controls:

| Issue ID | Severity | Description | Milestone Gating Impact |
| :--- | :---: | :--- | :--- |
| **ISSUE-V3-001-01** | **P1 (MAJOR)** | Mobile UI Overlay lacks virtual touch joystick and action buttons | **BLOCKER for Mobile Alpha** (Assigned to `PK_ClientLead`) |
| **ISSUE-V3-001-02** | **P1 (MAJOR)** | 2.5D Belt-scroll motion model discrepancy | **RESOLVED via Option C Decision** (To be implemented in `V3-003`) |
| **ISSUE-V3-001-03** | **P2 (MINOR)** | Script error on boot: `add_child()` on busy parent | Fix in next client maintenance pass |
| **ISSUE-V3-001-04** | **P2 (MINOR)** | Sprite3D fixed-Y billboard tilt causes curb penetration | Fix in sprite grounding polish pass |
| **ISSUE-V3-001-05** | **P3 (POLISH)** | Boss Commander shield charge windup lacks telegraph cue | Add 0.35s anticipation flash/pose |
| **ISSUE-V3-001-06** | **P3 (POLISH)** | Stage clear automatically loads next stage without victory screen | Implement victory reward modal |
| **ISSUE-V3-001-07** | **P1 (MAJOR)** | **Foreground Wall/Pillar completely occludes combat during Boss phase** | **BLOCKER for VS-001 Visual Gate** (Assigned to `PK_ArtDirector` / `PK_ClientLead`) |

---

## 5. Milestone & Pipeline Governance

1. **TASK V3-001 Status:** **APPROVED (Two-Key Pass: PK_QALead + PK_GameDirector).**
2. **Commit SHA Signed Off:** `a71223615d0b77e36dd85edb24e138fc67ecc140`.
3. **TASK V3-003 Status:** **STRICTLY BLOCKED.**
   - In accordance with production governance rules, `V3-003` cannot begin execution until parent orchestration task `V3-002` completes its independent review and closure cycle.
4. **Android Build Status:** Android performance is documented as `NOT_TESTED`. No claims of mobile deployment readiness may be made until a physical device benchmark package is submitted.

---

*Signed and sealed on 2026-11-06,*  
**PK_GameDirector**  
*Product & Milestone Authority, ProjectKnight Studio V3*