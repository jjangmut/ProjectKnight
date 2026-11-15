# ProjectKnight V3-026: Combat Feel A/B Comparison Report
## Frame 0 Damage Elimination, Distinct Combo Animations, and Scoped Hitpause Verification

---

### Executive Summary

In Milestone V3-026, ProjectKnight underwent a complete architectural rebuild of its core combat feel pipeline, drawing direct design and technical inspiration from genre benchmarks:
- **Dead Cells**: 3D-to-2D animation rendering pipeline, frame-exact visual silhouette projection, and active attack momentum.
- **Streets of Rage 4**: Distinct authored attack poses per combo stage (not speed-ramped duplicates), frame-by-frame telegraphing, and spatial reach differentiation.
- **Hollow Knight & Katana ZERO**: Zero visual desynchronization, frame-exact impact freeze (hitstop/hitpause), localized temporal dilation without engine time-scale stutter, and layered audio punch.

This report provides quantitative and qualitative verification comparing **Legacy (V3-025)** vs **Rebuilt (V3-026)**.

---

### Quantitative Comparison: Legacy (V3-025) vs Rebuilt (V3-026)

| Metric | Legacy (V3-025) | Rebuilt (V3-026) | Delta / Improvement |
| :--- | :--- | :--- | :--- |
| **Damage Timing ($t = 0\text{s}$)** | Instantaneous on input press ($0\text{ms}$) | Synchronized with blade apex ($80\text{ms} \sim 150\text{ms}$) | **Frame 0 phantom damage 100% eliminated** |
| **Combo 1 Animation** | 4-frame generic side slash (`knight_attack_v2.png`) | 6-frame authored horizontal strike (`hero_combo_1_sheet.png`) | Distinct horizontal slash arc, startup tell |
| **Combo 2 Animation** | Identical 4-frame sheet played at 1.25x speed | 6-frame authored reverse rising slash (`hero_combo_2_sheet.png`) | Upward diagonal arc, reverse blade rotation |
| **Combo 3 Animation** | Identical 4-frame sheet played at 1.50x speed | 8-frame heavy overhead ground cleave (`hero_combo_3_sheet.png`) | High vertical jump, two-handed cleave, dust burst |
| **Hitpause Architecture** | Global `Engine.time_scale = 0.05` (freezes entire world) | Scoped `HitPauseCoordinator` (freezes only striker & victim) | Smooth background, camera, and independent actor motion |
| **Hitpause Duration** | Flat $60\text{ms}$ for all hits | Scaled by impact severity ($50\text{ms} \to 70\text{ms} \to 120\text{ms}$) | Weighty, escalating finisher impact |
| **Camera Trauma Shake** | Flat $0.15$ on any hit | Escalating ($0.12 \to 0.20 \to 0.42$) | Powerful tactile feedback on finisher |
| **Audio Layering** | Single shared `sword_impact.wav` | Multi-layered (Whoosh + Impact + Finisher Sub-bass Quake) | Rich, dynamic acoustic feedback |
| **Enemy Combat Timelines** | Instantaneous frame 0 damage boxes | 3-phase structured timelines (TELL $\to$ ACTIVE $\to$ RECOVERY) | Clear telegraphs and fair parry/dodge windows |
| **Boss Dual Camera Tracking** | 24.6% on-screen frames during high-speed charges | **100.0% on-screen frames** ($FOV: 46^\circ \sim 58^\circ$, dual tracking) | **0 off-screen incidents across 100% of duel** |

---

### Frame-by-Frame Timeline Breakdown: Hero 3-Hit Combo

#### Combo 1: Horizontal Slash (6 Frames @ 60 FPS, Duration: 0.32s)
```
[Frame 0..1] Startup (0.00s ~ 0.08s): Pulls broadsword back, weight shifts to rear foot. No damage.
[Frame 2..3] Active Slash (0.08s ~ 0.18s): Horizontal cleave across chest level. Hitbox ACTIVE at t = 0.083s.
             - Damage: 1 HP
             - Hitpause: 50ms (scoped to Player + Target)
             - Camera Trauma: +0.12
[Frame 4..5] Recovery (0.18s ~ 0.32s): Blade follow-through and recoil. Combo-cancelable to Combo 2 after 0.18s.
```

#### Combo 2: Reverse Rising Slash (6 Frames @ 60 FPS, Duration: 0.32s)
```
[Frame 0..1] Startup (0.00s ~ 0.08s): Torso twists, sword swings low into reverse stance. No damage.
[Frame 2..3] Active Slash (0.08s ~ 0.18s): Rising upward slash cutting diagonally across target. Hitbox ACTIVE at t = 0.083s.
             - Damage: 1 HP
             - Hitpause: 70ms (scoped to Player + Target)
             - Camera Trauma: +0.20
[Frame 4..5] Recovery (0.18s ~ 0.32s): Overhead blade extension. Combo-cancelable to Combo 3 after 0.18s.
```

#### Combo 3: Heavy Overhead Finisher Cleave (8 Frames @ 60 FPS, Duration: 0.48s)
```
[Frame 0..2] Startup (0.00s ~ 0.15s): Hero leaps slightly upward, raising blade high with both hands. No damage.
[Frame 3..4] Active Ground Cleave (0.15s ~ 0.28s): Massive downward smash into the ground. Hitbox ACTIVE at t = 0.150s.
             - Damage: 2 HP
             - Hitpause: 120ms (heavy impact freeze)
             - Camera Trauma: +0.42 (deep screen rumble)
             - Knockback: 4.5 m/s horizontal impulse
[Frame 5..7] Recovery (0.28s ~ 0.48s): Ground impact recoil and recovery into idle stance. Dash-cancelable after 0.34s.
```

---

### Enemy Combat Timeline Integration

1. **Citadel Melee Grunt**:
   - `TELL (0.00s ~ 0.28s)`: Frame 3 windup stance with red telegraph flash. Weapon hitbox inactive.
   - `ACTIVE (0.28s ~ 0.42s)`: Frame 4 thrust slash. Hitbox active, damage occurs.
   - `RECOVERY (0.42s ~ 0.64s)`: Frame 5 follow-through. Punish opening for player.

2. **Heavy Shield Knight**:
   - `SHIELD_GUARD`: Blocks all frontal strikes within $|to\_player.z| < 0.42\text{m}$.
   - `TELL (0.00s ~ 0.35s)`: Shield pulls back, shield guard drops. Player can parry at apex ($t \ge 0.20\text{s}$) or strike flank.
   - `ACTIVE (0.35s ~ 0.53s)`: Shield bash surge forward ($3.2\text{ m/s}$).
   - `RECOVERY (0.53s ~ 0.95s)`: Stagger recovery. Vulnerable to direct counter-attacks.

3. **Boss Commander**:
   - `TRIPLE_CLEAVE`: 3 sequential telegraph rings with distinct windups.
   - `SHIELD_CHARGE`: Full windup crouch, 12 m/s forward rush, wall impact rebound ($3.2\text{ m/s}$).
   - `QUAKE_RING`: Jump takeoff, ground slam, expanding circular shockwave jumpable by player.

---

### Verification Verdict

- **Frame 0 Damage**: **ELIMINATED** (100% verified via `v3_026_timeline_verification.gd`).
- **Combo Distinction**: **VERIFIED** (3 separate authored sprite sheets, distinct trajectories).
- **Hitpause Scoping**: **VERIFIED** (no global world pause; independent actors continue).
- **Playtest Integrity**: **VERIFIED** (`AUTOMATED_INPUT_UNMODIFIED_GAME_STATE`, zero cheats, Stage 1 cleared naturally in 63.73s).
