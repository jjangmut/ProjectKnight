# V3-007 Stage 5 Silent Citadel — Combat Design Acceptance

**Role:** `PK_GameDesign` (Lead Game Designer)  
**Milestone:** V3-007  
**Encounter Target:** Stage 5 (Silent Citadel / 침묵의 성채 옥좌 홀)  

---

## 1. Encounter Design Overview

Stage 5 represents the climactic finale of ProjectKnight's 5-stage side-scrolling campaign. Mechanically, it distinguishes itself from prior stages:
- **Stage 1 (Citadel Terrace):** Fundamental melee timing, single charger boss.
- **Stage 2 (Beastwood Gorge):** High mobility, parabolic aerial leap attacks.
- **Stage 3 (Crossbow Bastion):** Area denial, projectile fan volleys, ground caltrop zoning.
- **Stage 4 (Titan Stone Sanctuary):** Heavy impact AOE, delayed shockwaves, spinning rush attacks.
- **Stage 5 (Silent Citadel):** Precision reading, projectile parrying, high-threat shadow teleportation, and bullet-hell shockwave jump evasion.

---

## 2. Pacing & Waves Breakdown

### Wave 1: Elite Abyssal Knights (2 Minions)
- **Spawn Positions:** $X = 4.0, Z = 0.0$ and $X = 8.5, Z = 0.0$ (Option C strictly enforced).
- **Attributes:** HP 6 each, speed 4.0 m/s, obsidian purple armor with radiant ground void rune halo.
- **Pacing Intent:** Tests player combo execution and rapid spacing. Cleared in ~2 seconds with active player rush.

### Wave 2: Abyssal Arbiter (Final Boss)
- **Spawn Position:** $X = 12.12, Z = 0.0$.
- **Attributes:** Initial HP 38, Max HP 38, Poise 18. Imposing 2.6m silhouette wielding an abyssal greatsword.
- **Phase 1 (HP 38 $\rightarrow$ 19):**
  - *Dark Crescent Wave:* High-speed vertical crescent blade projectile fired along $X$. Can be guarded or just-parried for an immediate 2.0s poise break stun.
  - *Shadow Blink Strike:* Boss dissolves into shadow, re-emerges behind player at $Z = 0.0$, telegraphs a danger ring, and executes a downward cleave.
  - *Melee Cleave Combo:* 2-hit forward greatsword strike.
- **Phase 2 (HP $\le$ 19):**
  - *Trigger:* Automatic transition upon reaching HP 17 in E2E. Void aura ring ignites, movement speed increases to 5.2 m/s.
  - *Judgment Storm:* Boss levitates to the hall center and unleashes 2 consecutive expanding cylindrical shockwaves. Players can jump dodge ($Y > 0.85\,\text{m}$) or just-parry.
- **Defeat & Finale:**
  - Boss HP reaches 0 $\rightarrow$ boss_defeated signal emitted $\rightarrow$ all `"stage_hazards"` destroyed.
  - Stage 5 clear fanfare (+50 Soul Shards awarded) $\rightarrow$ Full Campaign Victory panel displayed.

---

## 3. Verification & Verdict

| Design Criterion | Required Behavior | E2E Playthrough Proof | Status |
|---|---|---|:---:|
| **Option C Plane Lock** | 100% 2D combat lane alignment ($Z=0.0$) | 1,207 samples, 0 deviations | **PASS** |
| **Unique Minion Kills** | 2 unique enemy node IDs killed once | IDs `[120275863195, 120561075855]` | **PASS** |
| **Phase 2 Transition** | Trigger at HP $\le$ 19 | Triggered at HP 17 (`phase_changed(2)`) | **PASS** |
| **Boss Defeat** | Real inputs deplete HP 38 $\rightarrow$ 0 | Timeline verified, defeat signal count == 1 | **PASS** |
| **Campaign Victory** | 5 consecutive stages cleared $\rightarrow$ victory UI | `campaign_completed` signal == 1, panel verified | **PASS** |

**Design Verdict:** **`DESIGN PASS`**
