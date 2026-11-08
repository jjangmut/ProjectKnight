# ProjectKnight Studio V3 — Stage 3 Game Design Acceptance Card
## Ruined Crossbow Bastion (무너진 성벽) Combat Rhythm & Zoning Analysis

**Role / Author:** `PK_GameDesign` (Lead Game Designer)  
**Task ID:** `V3-005`  
**Milestone:** Stage 3 Content & Mechanics Acceptance  
**Status:** **`DESIGN PASS`**  
**Date:** 2026-11-08

---

### 1. Stage Progression Pacing Matrix (Stages 1 – 3)

| Dimension | Stage 1: Citadel Terrace Gate | Stage 2: Beastwood Forest Gorge | Stage 3: Ruined Crossbow Bastion |
|---|---|---|---|
| **Core Combat Archetype** | Melee Brawl & Heavy Shield Rush | High-Mobility Aerial Beast Ambush | Tactical Ranged Zoning & Projectile Evasion |
| **Pacing Rhythm** | Steady cadence, heavy footwork | Burst verticality, sudden pounce leaps | Spatial spacing control, bullet evasion, trap avoidance |
| **Telegraph Modality** | 0.43s heavy windup stance + audio cue | 0.35s emerald ring & pre-jump crouch | 0.40s laser aim vector, 0.35s minion aim, 0.35s barrage danger ring |
| **Player Counterplay** | Just-Parry head-on / roll behind | Timed jump over low swipe / parry leap | Jump over caltrops / raise guard vs bolts / punish backstep landing |
| **Boss Health & Poise** | HP 15, Poise 8 | HP 28, Poise 10 | HP 30, Poise 12 (Bonus Shatter Damage in Groggy) |
| **Phase 2 Escalation** | Enraged Charge Cadence | Emerald Enraged Roar + Triple Claw | Cobalt Muzzle Energy + 5-Shot Rapid Barrage |

---

### 2. Stage 3 Encounter Design & Telegraph Fairness

#### Wave 1: Ranged Crossbow Minions (2 Minions, HP 4 each)
- **Standoff Behavior:** Minions maintain $5.2\text{m}$ standoff distance along the $Z=0.0$ line. If player closes in, they retreat horizontally; if player pulls back, they advance.
- **Telegraph (0.35s Aim):** The minion stops horizontal movement, locks sprite frame to Frame 1 (Crossbow Aim Stance) for $0.35\text{s}$.
- **Fair Counterplay:**
  1. *Melee Stun:* Closing distance during the $0.35\text{s}$ windup and landing a sword strike interrupts the shot.
  2. *Just-Parry:* Raising Guard within the $0.15\text{s}$ just-parry window deflects the bolt and applies a $2.0\text{s}$ stun to the shooter.
  3. *Jump Dodge:* The bolt travels horizontally at eye level ($Y=0.8\text{m}$); jumping over the bolt cleanly avoids all damage.

#### Wave 2: Crossbow Commander Boss (HP 30, Poise 12)
- **Pattern 1: Fan Crossbow Volley (3-Bolt Spread in X/Y)**
  - *Telegraph (0.40s):* Floor-projected glowing red aim indicator line and Frame 8 kneeling aim pose.
  - *Trajectory:* 3 explosive bolts spread at $-18^\circ, 0^\circ, +18^\circ$ strictly within the $X/Y$ vertical gameplay plane ($Z=0.0$).
  - *Counterplay:* Guard barrier blocks the direct center bolt with $50\%$ damage reduction; Just-Parry reflects the attack; jumping or staying at maximum range allows ducking under high angled bolts.
- **Pattern 2: Acrobatic Backstep Shot**
  - *Telegraph:* Boss leaps backwards along $X$ with $v_y = 8.0\text{m/s}, v_x = -8.5\text{m/s}$ in a pure 2D parabolic arc ($v_z = 0.0$).
  - *Mid-Air Shot:* At the jump apex ($t=0.26\text{s}$), the boss fires a precision bolt aimed at player center.
  - *Counterplay:* Dash forward through the space the boss just vacated; as the boss lands with $0.40\text{s}$ recovery delay, player lands free back-strike combo.
- **Pattern 3: Caltrop Trap Cluster**
  - *Deployment:* Boss drops 4 glowing iron caltrops along the player's approach line ($X$ offsets: $+2.0, +3.2, +4.4, +5.6\text{m}$ at $Z=0.0$).
  - *Hazard Effect:* Touching a caltrop deals 1 chip damage and inflicts $40\%$ speed reduction for $2.0\text{s}$.
  - *Counterplay:* Traps emit bright red warning emissive glow. Jump over individual spikes using player standard leap ($Y \ge 1.4\text{m}$).
- **Pattern 4: Phase 2 Rapid Crossbow Barrage (5-Shot Burst at HP $\le 15$)**
  - *Trigger:* At $HP \le 15$, the boss pulses a bright cobalt aura ring and activates Phase 2.
  - *Telegraph (0.35s):* Expanding danger ring on floor plus audio cue.
  - *Execution:* 5 rapid bolts fired in quick succession ($0.14\text{s}$ intervals) with vertical pitch spread in $X/Y$ ($Z=0.0$).
  - *Counterplay:* Sustained guard barrier blocks successive shots; alternatively, chained dash i-frames allow evading the full volley.

---

### 3. Game Design Conclusion & Recommendation

The transition from Stage 1 (melee fundamentals) and Stage 2 (aerial evasion) to Stage 3 (projectile and zoning management) establishes an exemplary escalation curve for ProjectKnight. The Option C $Z=0.0$ plane lock eliminates frustrating depth misalignment, ensuring that all bolts, traps, and leaps occur in the player's direct line of sight and reaction plane.

**Verdict:** **`DESIGN PASS`**
