# V3-007 Stage 5 Silent Citadel — Architectural Delta & Before / After

## 1. Summary of Changes

| Component | Before V3-007 | After V3-007 Implementation |
|---|---|---|
| **Minion Spawns** | Wave 1 Elite Knights spawned at $Z = -1.8$ and $Z = +1.8$ | Locked strictly to Option C coplanar coordinates: `Vector3(4.0, 0.1, 0.0)` and `Vector3(8.5, 0.1, 0.0)` |
| **Minion Death / Defeat Signals** | Multi-hit attacks during 0.3s death fade re-triggered `_die()`, resulting in duplicate `enemy_defeated` signals | Implemented `is_dead` guard in `SideQVEnemy` / `SideQVEliteKnight`, immediately disabling collision masks and preventing duplicate death callbacks |
| **Arbiter Chase & Velocity** | `velocity.z = diff.normalized().z * (spd * 0.75)` caused 3D velocity drift off the gameplay lane | Clamped strictly to 1D horizontal movement: `velocity.z = 0.0`, `global_position.z = 0.0` across all patterns |
| **Shadow Blink Strike** | Target $Z$ was derived from player $Z$ clamped to $[-4.5, 4.5]$; no danger telegraph | Teleport destination locked to $Z = 0.0$ behind player within arena bounds; added danger telegraph ring before slash |
| **Dark Crescent Wave** | Projectile moved without continuous $Z$-axis lock; no single-hit flag | Bounded to $Z = 0.0$; added `has_hit` flag for single-damage gating; added to `"stage_hazards"` group for automated cleanup |
| **Judgment Storm (Phase 2)** | Shockwave pulse spawned without $Z = 0.0$ clamp; multi-tick hit damage | Clamped to $Z = 0.0$; added single-hit gate; added jump evasion clearance ($Y > 0.85$); added to `"stage_hazards"` group |
| **Boss Defeat & Hazard Cleanup** | Hazarded areas could linger after boss death | `_die()` and `_exit_tree()` sweep and free all nodes in `"stage_hazards"` group |
| **Campaign Completion** | Untested continuous 5-stage E2E run | Full continuous Title $\rightarrow$ Stage 5 playthrough verified; `campaign_completed` signal and `CampaignVictoryPanel` display confirmed |

## 2. Telemetry Comparison

- **V3-006 Observation Anomaly Resolved:** `stage4_minion_2_defeated_callback=2` was traced to missing `is_dead` state in `SideQVEnemy`. In V3-007, both Elite Knights recorded exactly 1 callback each with distinct instance IDs: `[120275863195, 120561075855]`.
- **Actor Z Coplanarity:** 1,207 data samples across Player, Minions, and Arbiter yielded **0 non-zero $Z$ coordinates** ($100\%$ coplanar at $Z = 0.0000$).
