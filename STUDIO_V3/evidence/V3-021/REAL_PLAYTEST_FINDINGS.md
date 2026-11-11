# V3-021 — Real Playtest Findings & Qualitative Gameplay Review

## 1. Overview

This document presents the qualitative gameplay observations from direct playthroughs and video analysis of **Stage 1 (성문 외곽 / Citadel Terrace Gate)** in Godot 4.7.2.

- **Playthrough Method:** Godot 4.7.2 desktop engine, 60 FPS, full audio and visual rendering.
- **Video Reference:** [`D:\JUNYPAPA_STUDIO\Videos\ProjectKnight\V3-021\Stage1_Rebuild_Playtest.mp4`](file:///D:/JUNYPAPA_STUDIO/Videos/ProjectKnight/V3-021/Stage1_Rebuild_Playtest.mp4) (45.05s, 1280×720, 60 FPS).
- **Automated Verification:** `tests/v3_021_stage1_playtest.gd` (Exit Code 0, 100% checks passed).

---

## 2. Key Findings Across Gameplay Dimensions

### 2.1 2.5D Movement & Depth Pacing
- **Observation:** Moving up and down in the $Z$ depth lane feels smooth and natural. The player can weave around enemy attacks, bypass hazardous caltrop clusters, and position behind shielding foes.
- **Shadow Footprint:** During jumps, the player's 2D sprite ascends into the air while the 3D circular ground shadow remains grounded on the flagstone floor, scaling naturally with height. This provides unambiguous depth and landing precision.
- **Pacing:** Traversal across the 100m corridor is broken up by 3 distinct encounter gates. The transition from walking $\to$ combat $\to$ gate dissolving $\to$ progression feels rewarding and eliminates dead time.

### 2.2 Combat Directionality & Hit Alignment
- **Directional Reach:** Attacks no longer strike enemies in different depth lanes or behind the hero. Only enemies within the frontal reach cone ($[-0.25, 2.40]$m forward, $\pm 1.35$m lateral) register hits.
- **Visual-Hitbox Coherence:** Slashes, lance thrust beams, and hit sparks cleanly rotate along the player's facing/aim vector ($atk\_dir$). When attacking diagonally forward-up, the sword arc tilts accordingly, creating tight visual feedback.

### 2.3 Enemy Archetypes & Anti-Spam
- **Melee Grunt:** Closes in and attempts to flank in $Z$, forcing the player to prioritize spatial awareness.
- **Crossbowman:** Standoff distance ($6$–$8$m) and visible laser aiming telegraph give clear cues for dodging in depth or raising the guard shield.
- **Heavy Shield Knight (Anti-Spam):**
  - Frontal attacks are completely neutralized with loud metallic clangs and spark particles. Button spamming is instantly punished by the knight's heavy retaliatory shield bash.
  - Flanking into the depth lane ($Z = -1.8$ or $+1.6$) and striking from behind deals full critical damage, rewarding tactical positioning.

### 2.4 Boss Commander 3 Patterns
- **Ground Shockwave Fissure:** Rolling energy wave down the floor lane telegraphs clearly with glowing ground fissures. Easily readable and satisfying to leap over.
- **Bastion Line Charge:** High-speed sprint across the arena forces the player to sidestep up or down in $Z$, reinforcing 2.5D lane mobility.
- **360 Whirlwind Cleave:** Punishes players who linger too long in melee range. Precise timing rewards a Just Parry with glowing cyan VFX, hit stop, and massive counter damage.

---

## 3. Playtest Conclusion
The rebuilt Stage 1 represents a major leap in quality from a single-screen tech demo to a cohesive, commercial-quality 2.5D action platformer slice. The core gameplay loop is tactile, responsive, and resistant to button mashing.
