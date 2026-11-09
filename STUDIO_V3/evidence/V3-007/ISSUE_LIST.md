# V3-007 Stage 5 Silent Citadel — Issue Tracking & Verification List

## 1. Resolved Milestone Issues

| Issue ID | Severity | Description | Resolution | Status |
|---|:---:|---|---|:---:|
| **ISSUE-V3-007-01** | P0 | Stage 5 Elite Knight minion spawns were set to off-plane $Z = \pm 1.8\,\text{m}$ | Changed spawn coordinates to Option C coplanar $Z = 0.0$ (`Vector3(4.0, 0.1, 0.0)` and `Vector3(8.5, 0.1, 0.0)`) | **RESOLVED** |
| **ISSUE-V3-007-02** | P0 | Multi-hit attacks during enemy death fade (0.3s) re-triggered `_die()`, causing duplicate `enemy_defeated` signals | Implemented `is_dead` guard in `SideQVEnemy` / `SideQVEliteKnight`, disabling collision and preventing duplicate signal emissions | **RESOLVED** |
| **ISSUE-V3-007-03** | P0 | Arbiter pursuit assigned 3D `velocity.z = diff.normalized().z * (spd * 0.75)`, causing drift off the 2D plane | Clamped `velocity.z = 0.0` and `global_position.z = 0.0` across all states; converted pursuit and anti-pushing to 1D horizontal $X$ logic | **RESOLVED** |
| **ISSUE-V3-007-04** | P1 | Shadow Blink Strike target $Z$ derived from player $Z$ clamped to $[-4.5, 4.5]$ | Locked teleport target strictly to $Z = 0.0$ behind player within arena bounds; added danger telegraph ring | **RESOLVED** |
| **ISSUE-V3-007-05** | P1 | Dark Crescent Wave lacked single-hit gating and group cleanup | Bounded to $Z = 0.0$; added `has_hit` flag; added to `"stage_hazards"` group for automated cleanup | **RESOLVED** |
| **ISSUE-V3-007-06** | P1 | Judgment Storm void pulses lacked jump evasion bounds and single-hit gating | Clamped to $Z = 0.0$; added single-damage flag; added $Y > 0.85$ jump clearance check; added to `"stage_hazards"` group | **RESOLVED** |

## 2. Open Issues
- **P0 Blockers:** 0
- **P1 Majors:** 0
- **P2 Polish:** None blocking milestone closure.
- **P3 Backlog:** Physical mobile touch optimization and ARM device profiling (deferred to post-PC vertical slice release phase).
