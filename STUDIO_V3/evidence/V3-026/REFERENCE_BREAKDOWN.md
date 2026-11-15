# V3-026 Reference Breakdown: Combat Feel & Animation Foundations

**Milestone:** V3-026 Combat Animation Foundation Rebuild  
**Repository:** `jjangmut/ProjectKnight`  
**Purpose:** Extract foundational design principles from industry benchmark action titles (*Dead Cells*, *Streets of Rage 4*, *Hollow Knight*, *Katana ZERO*) and apply them to ProjectKnight's 2.5D belt-scroll architecture without copying proprietary assets or IP.

---

## 1. Dead Cells (Motion Twin) — 3D-to-2D Animation Pipeline

### Annotated Design Observations:
1. **Pose-to-Pose over In-Betweening:** Motion Twin models characters in 3D (Blender), animates key poses with high exaggeration, and renders out low-frame-count 2D sprites (typically 6–10 frames per attack) rather than fluid high-FPS loops. Every single frame is an iconic silhouette.
2. **Contact-Centric Timing:** Attacks are divided into distinct segments: decisive windup (anticipation), instant active sweep (1–2 frames max), and committed follow-through. Weapon contact timing is tuned as a primary gameplay variable.
3. **Silhouette Readability:** Character limbs, weapons, and head silhouettes remain legible even when viewed from afar or against noisy environments.

### Implementation Implications for ProjectKnight:
1. **Blender-to-PNG Atlas Pipeline:** Utilize the installed Blender 4.5 and the existing Paladin 3D rig (`character_3d_model`) to pose, light, and render crisp, side-facing orthographic 2D sprite atlases at 1280×720 native game resolution.
2. **Minimal Decisive Frames:** Each attack step will use 6–8 authored frames: 2 windup frames, 2 active strike frames with weapon blur/trail, and 2–4 recovery/settle frames.
3. **Unified Sprite Pivots:** All rendered frames will share an exact ground contact pivot ($Y=0$) and character root center ($X=0$), eliminating cutout jitter.

### What Must NOT Be Copied:
- Motion Twin's dark fantasy cellular art style, weapon names, sound effects, or character geometry. ProjectKnight retains its distinct armored chivalric identity.

---

## 2. Streets of Rage 4 (Dotemu / Guard Crush) — Combo Differentiation

### Annotated Design Observations:
1. **Functional Attack Separation:** Combo sequences are not mere speed variations; each input solves a different tactical problem. Attack 1 is a rapid checking jab, Attack 2 shifts body weight into a gut/cleave strike, and Attack 3 is an explosive knockdown/finisher.
2. **Exaggerated Weight & Follow-Through:** Finishers feature pronounced backswings, wide kinetic arcs, and noticeable recovery where the attacker must recover posture.
3. **Clear Whiff Punishment:** Attacking empty air commits the player to the recovery frames, rewarding deliberate spacing over button mashing.

### Implementation Implications for ProjectKnight:
1. **Unique Attack Animations:**
   - **Attack 1 (Quick Horizontal Slash):** Swift checking strike with minimal windup (~0.08s) and quick recovery (~0.12s).
   - **Attack 2 (Upward Reverse Slash):** Lowered stance transitioning into an upward rising diagonal cut (~0.10s windup, ~0.14s recovery).
   - **Attack 3 (Overhead Heavy Cleave):** Deep weight coil, raised blade, followed by a thunderous ground-cleaving vertical strike with committed recovery (~0.22s).
2. **Cancellable Recovery Windows:** Allow chaining into the next combo step or dashing/guarding only during the designated recovery cancel window, not mid-swing.
3. **Whiff Penalty:** Whiffing on air has a slightly longer un-cancelable recovery than hitting an enemy (which grants hit-cancel fluidity).

### What Must NOT Be Copied:
- Streets of Rage characters, pixel art, sound assets, or health scaling formulas.

---

## 3. Hollow Knight & Katana ZERO — Game Feel & Sensory Layering

### Annotated Design Observations:
1. **Localized Hitstop (Frame Hold):** When a weapon strikes an enemy, both the attacker and the victim freeze for a brief micro-duration (30–60ms for light hits, 80–110ms for heavy/parries). This emphasizes impact without breaking game flow.
2. **Directional Camera Impulses:** Rather than omnidirectional screen shaking (which causes visual nausea and obscures combat), hits generate a tight, unidirectional camera displacement along the angle of the slash.
3. **Decoupled Audio Dynamics:**
   - On attack initiation: Play a dry weapon *swish* / *whoosh*.
   - On verified contact ONLY: Play a meaty *thud* or sharp *slash impact*.
   - On shield block: Play a resonant *metallic clang*.
   - Never play hit sounds on a whiff!

### Implementation Implications for ProjectKnight:
1. **Scoped HitPause Coordinator:** Implement `HitPauseCoordinator` to pause individual actor sprite playback and movement tweens during hitstop, avoiding global `Engine.time_scale` freezes for routine melee strikes.
2. **Directional Camera Impulse:** Hook `Camera3D` to receive directional impulse vectors from the attack plane ($X/Z$).
3. **Synchronized Hit Event Dispatch:** Consolidate damage, hitstop, directional blood/spark VFX, screen impulse, and audio playback into a single atomic `HitResult` event dispatched on the exact frame of blade contact.

### What Must NOT Be Copied:
- Hollow Knight insect aesthetic, Katana ZERO synthwave visuals, bullet-time slow-motion rewind mechanics, or proprietary SFX.
