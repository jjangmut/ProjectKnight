# V3-004 Stage 2 Beastwood Forest Gorge — Game Design Acceptance Card

**Author:** PK_GameDesign (Lead Game Designer)  
**Date:** 2026-11-08  
**Scope:** Stage 2: Beastwood Forest Gorge (야수숲 협곡)  
**Milestone:** V3-004  

---

## 1. Stage 2 Gameplay Identity & Distinction from Stage 1

Stage 1 (성문 외곽 Citadel Terrace Gate) focuses on structured knight-on-knight melee combat: disciplined shield charges, predictable telegraphs, and linear horizontal pacing.

Stage 2 (야수숲 협곡 Beastwood Forest Gorge) introduces wild, predatory, vertical combat dynamics:
1. **Feral Multi-Target Pressure:** Two feral beast minions engage simultaneously with low telegraph lead times (0.32s windup flash) and fast forward charge speed (8.8 m/s).
2. **Aerial & Parabolic Pressure:** The Beast Chieftain boss jumps high into the air (Y impulse 7.2 m/s, leap speed 9.0 m/s), landing with an expanding emerald ground shockwave, requiring vertical space awareness and parry/dash timing.
3. **Multi-Hit Melee Rhythms:** Rather than single heavy strikes, the boss utilizes a 3-hit forward claw slash combo (Triple Claw Strike) that tests multi-parry rhythm and guard recovery.
4. **Berserk Phase 2 Enrage:** At 50% HP ($\le 14/28$), the boss transitions via an invulnerable Enraged Roar, gaining increased movement (+33%) and leap velocity (+28%), accompanied by a visible glowing emerald rune aura.

---

## 2. Combat Encounter Specification & Acceptance Criteria

### Encounter 1: Feral Beast Minions (Wave 1)
- **Enemy Type:** `SideQVBeastMinion` (2 instances: `SideQVBeastMinion_1`, `SideQVBeastMinion_2`)
- **Initial Spawns:** Minion 1 at $X = 4.5, Y = 0.1, Z = 0.0$; Minion 2 at $X = 8.0, Y = 0.1, Z = 0.0$
- **Base Attributes:** Max HP = 5, Move Speed = 3.8 m/s, Charge Speed = 8.8 m/s, Attack Damage = 1 HP
- **Attack Pattern — Feral Charge Pounce:**
  - Windup: 0.32s crouch with high-energy warning flash (`modulate = Color(2.5, 0.6, 0.3)`). Hazard hitbox is strictly inactive during windup.
  - Active: 0.42s forward leap along horizontal $X$ axis. Hitbox active.
  - Counterplay: Just-Guard during active charge triggers Parry Stun (2.0s duration), allowing a full 3-hit player counter-combo.
  - Damage Rule: Hitbox is single-hit per charge (`has_hit_in_current_charge = true`), preventing proximity/Area3D double-damage glitches.
- **Wave Clear Transition:** Upon defeat of both minions, player receives Holy Restoration (+2 HP) and the advance banner appears directing rightward advance to $X \ge 6.5$.

### Encounter 2: Beast Chieftain Boss (Wave 2)
- **Enemy Type:** `SideQVBeastChieftain`
- **Initial Spawn:** $X = 12.0, Y = 0.1, Z = 0.0$ (Boss Sanctuary Zone)
- **Base Attributes:** Max HP = 28, Max Poise = 14, Move Speed = 4.2 m/s (Phase 1) / 5.6 m/s (Phase 2)
- **Pattern 1 — Pounce Leap (맹수 도약 덮치기):**
  - Telegraph: 0.35s ground danger torus ring + warning popup `!`. Non-damaging during windup.
  - Airborne Leap: $v_y = 7.2\text{ m/s}$, $v_x = \text{facing\_dir} \times 9.0\text{ m/s}$ ($11.5\text{ m/s}$ in Phase 2), $v_z = 0.0\text{ m/s}$.
  - Ground Slam Shockwave: Upon landing, expanding emerald ring ($r = 3.6\text{ m}$) deals 2 HP damage and knockback. Single-hit protected.
- **Pattern 2 — Triple Claw Strike (3단 야수 발톱 참격):**
  - 3 sequential forward swipes with 0.06s windup, 0.20s hitbox active, 0.08s recovery per slash.
  - Damage: 2 HP per strike. Parryable on each swing; successful parry deals 4 poise damage.
- **Pattern 3 — Enraged Roar & Phase 2 Transition (분노 포효):**
  - Trigger: $HP \le 14$ ($50\%$ of 28 HP).
  - Effect: Boss roars, emitting `phase_changed(2)` and `boss_phase_changed(2)`. Visible emerald aura ring activates on boss model. Speed increased to 5.6 m/s, leap speed to 11.5 m/s.
  - Roar Shockwave: Expanding 5.2m area deals 2 HP damage and horizontal knockback.
- **Defeat & Stage Clear:**
  - When HP reaches 0, boss emits `boss_defeated`. Stage camera triggers trauma shake.
  - After fanfare delay (2.0s), `stage_cleared` signal fires exactly once.
  - Campaign marks `cleared_stages[1] = true` and transitions to Stage 3 (`SideQVStage3`).

---

## 3. Design Verification Matrix

| Acceptance Item | Specification | Measured Result | Verdict |
|---|---|---|---|
| Minion 1 Spawn Plane | $Z = 0.00\text{ m}$ | $Z = 0.0000\text{ m}, v_z = 0.0000$ | **PASS** |
| Minion 2 Spawn Spawn | $Z = 0.00\text{ m}$ | $Z = 0.0000\text{ m}, v_z = 0.0000$ | **PASS** |
| Minion Pounce Warning | Telegraph precedes hitbox | 0.32s flash with monitoring=false verified | **PASS** |
| Minion Combat Defeat | $HP = 5 \rightarrow 0$ natural input | Defeated at $t=12.917\text{s}$ | **PASS** |
| Boss Initial HP | Exactly 28/28 | 28/28 verified at spawn | **PASS** |
| Boss Spawn Plane | $Z = 0.00\text{ m}$ | $Z = 0.0000\text{ m}, v_z = 0.0000$ | **PASS** |
| Boss Leap Trajectory | Strict 2D parabolic ($v_z=0$) | Airborne max $|v_z| = 0.0000$ | **PASS** |
| Phase 2 Transition | Trigger at $HP \le 14$ | Fired at $HP=12$, signal received | **PASS** |
| Boss Natural Defeat | $HP \rightarrow 0$ via combat | $HP=0$, `boss_defeated` count=1 | **PASS** |
| Stage Clear Signal | `stage_cleared` count == 1 | Count == 1 at $t=20.936\text{s}$ | **PASS** |
| Stage 3 Progression | Transition to `SideQVStage3` | Stage 3 loaded at $t=22.752\text{s}$ | **PASS** |

**Design Verdict:** **DESIGN PASS**
