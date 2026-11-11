# V3-021 — 2.5D Belt-Scroll Core Gameplay Architecture & Design Specification

## 1. System Overview

Milestone **V3-021** replaces the prototype $Z=0$ single-screen restriction with a commercial-grade **2.5D Belt-Scroll Action System**, matching classic arcade action games (e.g., *Streets of Rage*, *Dungeons & Dragons: Shadow over Mystara*, *Guardian Heroes*) blended with modern 3D lighting, physics, and responsive combat feel.

```text
       ▲ Depth (-Z / move_up)
       │
◄──────┼──────► Traversal (+X: Advance forward / -X: Retreat)
       │
       ▼ Foreground (+Z / move_down)

       Jump / Gravity: Y-Axis (Independent from ground X/Z footprint)
```

---

## 2. Core Gameplay Pillars & Implementation

### 2.1 2.5D Movement & Footprint Grounding
- **Input Mapping:**
  - `move_left` / `move_right`: Horizontal traversal ($X$-axis, $[-12.0, 88.0]$).
  - `move_up` / `move_down`: Depth lane maneuver ($Z$-axis, $[-3.2, 3.2]$).
  - `jump`: Vertical leap ($Y$-axis, jump impulse $8.2$ m/s, gravity $22.0$ m/s$^2$).
- **Ground Shadow Decoupling:**
  - When the hero jumps, the character body ascends in $Y$.
  - The 3D circular ground shadow (`ground_shadow`) stays clamped to floor level ($Y = 0.015$), continuously tracking the character's $(X, Z)$ coordinate.
  - Shadow scale scales inversely with height ($scale = 1.0 - h \times 0.16$), providing perfect spatial depth perception during jumps and aerial dive slams.

### 2.2 Directional Combat & Visual Alignment
- **Facing & Attack Vectors:**
  - The hero maintains a normalized horizontal vector `facing_attack_dir: Vector3` computed dynamically from current input or facing:
    $$atk\_dir = (input\_dir.x \ne 0 \lor input\_dir.z \ne 0) ? Vector3(input\_dir.x, 0, input\_dir.z).normalized() : Vector3(facing\_dir\_x, 0, 0)$$
- **Melee Cone Hitbox:**
  - Forward reach: $forward\_dist = diff\_h \cdot atk\_dir \in [-0.25, 2.40 + extra\_r]$.
  - Lateral depth tolerance: $lateral\_dist = \|diff\_h - atk\_dir \times forward\_dist\| \le 1.35 + extra\_r \times 0.5$.
  - Targets behind the attack cone or in distant $Z$ depth lanes are never hit.
- **Visual FX Yaw Alignment:**
  - Slashes, sword arcs (`slash_visual_3d`), and lance projectile beams (`side_qv_sword_beam.gd`) rotate along the $Y$-axis:
    $$rotation.y = \text{atan2}(-atk\_dir.z, atk\_dir.x)$$
  - Visual slash angle, impact sparks, and knockback trajectories match 100% with the player's intended attack direction.

### 2.3 3 Distinct Enemy Archetypes (Total 12 Minions Across 3 Encounters)
1. **Citadel Guard Grunt (`side_qv_enemy.gd`):**
   - Role: Rapid melee pursuer.
   - AI: Dynamically paths in $(X, Z)$ to flank player in depth before launching a telegraphed 2-hit cleave with weapon gleam.
2. **Bastion Crossbowman (`side_qv_ranged_minion.gd`):**
   - Role: Standoff ranged sniper.
   - AI: Aligns depth lane with player, maintains $6.0$–$8.0$m standoff distance in $X$, aims with a visible 3D laser telegraph, and fires piercing bolts. Evades in $Z$ depth if the player rushes within $2.8$m.
3. **Heavy Bastion Shield Knight (`side_qv_elite_knight.gd`):**
   - Role: Defensive frontliner & anti-spam enforcer.
   - AI: Marches forward with greatshield raised. Blocks 100% of frontal attack spam with heavy metallic clang sparks and retaliates with an immediate forward shield bash.
   - Counterplay: Player must sidestep in $Z$ depth, flank behind the knight, execute a jump-attack over the shield, or strike during post-attack recovery.

### 2.4 Anti-Spam Architecture
- Frontal button spamming against shielded foes results in:
  - 0 damage dealt.
  - Player attack bounces with heavy block sound (`guard_block`) and metallic spark VFX.
  - Shield Knight triggers retaliatory shield bash, staggering reckless players.
- Flanking, depth alignment, jumping over obstacles, and timing parries are required to progress.

### 2.5 Boss Commander: 3 Distinct Telegraphed Attack Patterns
1. **Pattern 1: Ground Shockwave Fissure:**
   - Telegraph: Boss raises heavy broadaxe with crackling amber ground runes for $0.55$s.
   - Execution: Slams the floor, unleashing a rolling energy fissure traveling across the ground lane.
   - Counterplay: Player must jump over the shockwave.
2. **Pattern 2: Bastion Line Charge:**
   - Telegraph: Boss crouches behind greatshield with blue kinetic rushing aura for $0.60$s.
   - Execution: Sprints across the arena at $14.0$ m/s, trampling anything in the lane.
   - Counterplay: Player must sidestep up or down into another depth lane.
3. **Pattern 3: 360 Whirlwind Cleave / Quake Ring:**
   - Telegraph: Boss coils axe overhead with purple void sparks for $0.45$s.
   - Execution: Spins in a full 360-degree circle with an expanding orange shockwave ring, punishing close-range button mashers.
   - Counterplay: Player must backdash out of range, or execute a Just Parry with precise timing for critical counter damage.

### 2.6 Dynamic Scrolling Camera
- Camera smoothly follows player in $X$ traversal:
  $$dest.x = clampf(target\_pos.x + camera\_offset.x, min\_camera\_x, max\_camera\_x)$$
- Camera tracks depth in $Z$ with dampened perspective:
  $$dest.z = target\_pos.z \times 0.35 + camera\_offset.z$$
- Camera pitch is fixed at $-32^\circ$ (Quarter-View elevation) with $0^\circ$ yaw, ensuring crystal-clear readability of the 2D character sprites against the 3D environment.
