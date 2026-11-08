# ProjectKnight Studio V3 — Stage 3 Before / After Architectural Delta
## Ruined Crossbow Bastion (무너진 성벽) Gameplay & Plane Fix Analysis

**Task ID:** `V3-005`  
**Milestone:** Stage 3 Content & Mechanics Fix  
**Evaluator:** `PK_Producer`  
**Date:** 2026-11-08

---

### 1. Comparative Summary Matrix

| Subsystem / Mechanic | Baseline State (Before V3-005) | Refactored State (After V3-005) | Impact & Verification |
|---|---|---|---|
| **Minion Spawns** | Minion 1 at $Z=-1.8$, Minion 2 at $Z=+1.8$ | Both minions spawn strictly at $Z=0.0000$ | Eliminates depth misalignment; minion 1 & 2 immediately in player combat plane |
| **Minion Movement AI** | Used 3D distance and 3D velocity ($v_z \ne 0$) | 1D horizontal pursuit/standoff ($v_z = 0.0, z = 0.0$) | Minions maintain $5.2\text{m}$ standoff along $X$; zero depth drift |
| **Minion Bolt Trajectory** | Vector from minion to player included $Z$ offset | Aim vector projected onto $X/Y$ ($aim\_dir.z = 0.0$) | Bolts travel strictly along gameplay plane ($Z=0.0$) |
| **Boss Backstep Shot** | `velocity.z = randf_range(-1.5, 1.5)` | `velocity.z = 0.0`, pure 2D parabolic leap | Zero $Z$ drift during acrobatic leap; max observed $|v_z| = 0.0000$ |
| **Boss Fan Volley** | Rotated base aim vector around `Vector3.UP` by $\pm 22^\circ$ | Rotated base aim vector around `Vector3(0,0,1)` in $X/Y$ plane by $\pm 18^\circ$ | Fixed critical bug where bolts deflected into background/foreground depth |
| **Boss Rapid Barrage** | Added random jitter to `aim_dir.z` (`randf_range(-0.06, 0.06)`) | Vertical pitch jitter in $Y$ only; `aim_dir.z = 0.0` | 5 rapid bolts stay 100% on $Z=0.0$ plane |
| **Caltrop Traps** | Scattered at $Z = -1.4, 0.0, +1.4, -0.6$ (off-lane) | Positioned sequentially along player path at $Z=0.0$ | Traps now genuinely threaten the player; $40\%$ slow and $2\text{s}$ recovery verified |
| **Trap Speed Restoration** | Naive timer overwrite risked permanent slow corruption | Re-entrant meta tracking (`active_caltrop_slow_count`) | Prevents stacked slow corruption; base speed restored cleanly |
| **Bolt Anti-Tunneling** | Discrete frame movement with `Area3D.body_entered` | Swept physics raycast between frame steps | 100% collision capture against player/terrain; zero tunneling |
| **Foreground Pillar** | 3.2m tall column at $X=11.0, Z=+3.2$ | 1.1m ruined shattered stub at $X=11.0, Y=0.55, Z=+3.2$ | Completely clears sightline to boss spawn and melee engagement line |

---

### 2. Telemetry Proof Delta

- **Sampled Actor Presence Rows:** **729 data rows** in `ACTOR_PROJECTILE_Z_PRESENCE.csv`.
- **Non-Zero Z Occurrences:** **0** across all sampled ticks for player, minion 1, minion 2, and boss.
- **Boss Defeat Progression:** Monitored in `BOSS_SHOT_AND_PHASE_TIMELINE.csv`:
  $HP = 30 \rightarrow 28 \rightarrow 26 \rightarrow 22 \rightarrow 20 \rightarrow 18 \rightarrow 15 \text{ (Phase 2)} \rightarrow 12 \rightarrow 9 \rightarrow 6 \rightarrow 0 \text{ (Defeated)}$.
- **Callback Observation Counts:**
  - `btn_new_game.pressed` count: 1
  - `RangedMinion_1.enemy_defeated` count: 1
  - `RangedMinion_2.enemy_defeated` count: 1
  - `boss.phase_changed` count: 1
  - `boss.boss_defeated` count: 1
  - `SideQVStage3.stage_cleared` count: 1
  - `SideQVStage4` loaded: Campaign index 3.
