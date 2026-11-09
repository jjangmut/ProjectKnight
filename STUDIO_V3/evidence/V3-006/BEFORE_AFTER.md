# ProjectKnight Studio V3 — Architectural Delta Comparison
## Task V3-006: Stage 4 Titan Stone Sanctuary (돌의 성소)

- **Task ID:** V3-006
- **Stage:** Stage 4 (돌의 성소 / Titan Stone Sanctuary)
- **Author:** PK_ClientLead
- **Date:** 2026-11-09

---

## 1. Architectural & Coordinate System Changes

| Subsystem / Actor | Before V3-006 Defect State | After V3-006 Option C Resolution | Impact on Player Experience |
|---|---|---|---|
| **Heavy Golem Minion Spawns** | Spawning off-plane at $Z = -1.2\text{m}$ and $Z = +1.2\text{m}$. | Strictly clamped to $Z = 0.0000, v_z = 0.0000$ at spawn (`Vector3(4.0, 0.1, 0.0)` and `Vector3(8.5, 0.1, 0.0)`). | Both HP 8 golems meet player head-on along the central combat lane without diagonal skew or depth confusion. |
| **Heavy Golem Pushing** | Diagonal 3D vector pushing logic pushing player across Z. | Pure 1D horizontal collision and pushing prevention along X. $v_z$ clamped to 0.0. | Player cannot be pushed off the combat plane into background or foreground. |
| **Golem Guardian Movement** | `velocity.z = diff.normalized().z * (spd * 0.65)` in CHASE state; no $Z$ clamping in groggy, stun, slam, lariat. | `velocity.z = 0.0000` and `global_position.z = 0.0000` strictly enforced across all states, physics steps, and animations. | Boss remains strictly coplanar with player ($Z = 0.0$). Zero depth drift. |
| **Ground Slam Mechanics** | Ground slam spawned rock pillars scattered in $Z = \pm 1.8\text{m}$, occluding foreground view. Shockwave lacked explicit jump-dodge bounds. | Rock shard pillars confined strictly to $Z \le 0.0$ (background depth $Z \in [-0.55, 0.0]$); radial shockwave cylinder height set to $1.0\text{m}$ ($Y \in [0.0, 1.0]$). | 0% foreground occlusion. Player jumping cleanly leaps over ground shockwave ($Y \ge 1.0\text{m}$). Guard/Parry fully supported. |
| **Spinning Lariat Mechanics** | High-speed forward rush lacked single-hit gate; multi-hit hazard on contact. Parry stun lacked rock-solid stopping logic. | Added `has_hit_player_in_current_lariat` boolean gate. Parry stun (`apply_parry_stun(2.0)`) immediately zeroes velocity ($v_x = 0, v_z = 0$), cancels lariat, and drops poise by 4. | Fair telegraphing and high-impact clash feel. No cheap multi-tick damage. |
| **Quake Fissure (Phase 2)** | Molten fissure slabs had random Z offsets ($Z \in [-0.15, 0.15]$) and tall collision box ($1.4\text{m}$) hard to jump over. Lacked single-hit gate. | Fissure line strictly at $Z = 0.0000$. Hitbox height set to $0.9\text{m}$ ($Y \in [0.0, 0.9]$). Single-hit gate enforced via overlapping body loop. Group `"stage_hazards"` cleanup. | Fluid platforming dodge over magma cracks. Zero lingering hazard after stage completion. |
| **Foreground Monoliths** | Concern over monolith pillars obstructing player and boss sightlines. | Monolith pillars at $X = \pm 17.5\text{m}$ (gate boundary) and $Z = -5.1\text{m}$ (deep background). Combat lane $X \in [-12, 12], Z = 0$ is 100% unobstructed. | Clean silhouette reading against volcanic sunset lighting and ember particles. |
