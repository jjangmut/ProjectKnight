# V3-021 — Before / After Architectural & Quality Comparison

## 1. Executive Summary

Milestone **V3-021** executed an extensive overhaul of the core gameplay of ProjectKnight, transitioning from an artificial single-screen $Z=0$ locked prototype into a true **2.5D Belt-Scroll Action Platformer** with an extended 100m corridor, 3 distinct enemy archetypes, anti-spam systems, telegraphed boss patterns, and fluid camera tracking.

---

## 2. Detailed Category Comparison

| Quality Category | Legacy Prototype (Option C / V3-016~V3-020) | V3-021 Core Gameplay Rebuild |
|:---|:---|:---|
| **Traversal Plane** | Fixed $Z=0.0$ plane lock (`velocity.z = 0.0`, `global_position.z = 0.0`). Strictly 1D linear horizontal corridor. | Full 2.5D belt-scrolling plane ($X \in [-12, 88]$, $Z \in [-3.2, 3.2]$). Free traversal in depth and width. |
| **Stage 1 Map Size** | Single arena box ($\approx 38$m width), static camera locked to arena center. | Extended 100m continuous corridor with 3 distinct thematic sections, balustrades, gothic ruins, torches, and panoramic backdrops. |
| **Encounter Structure** | 1 Wave of 2 identical minions $\to$ Boss spawn. Total 2 enemies. | 3 Distinct Encounter Gates + Boss Sanctuary. Total 12 minions across 3 encounters with dissolving spectral barriers. |
| **Enemy Diversity** | 1 Archetype (Citadel Minion with simple rush AI). | 3 Distinct Archetypes:<br>1. Citadel Guard Grunt (flanking melee)<br>2. Bastion Crossbowman (standoff sniper with 3D aim)<br>3. Heavy Shield Knight (frontline shield guard). |
| **Combat Anti-Spam** | No frontal block; attack button spamming consistently defeated all enemies without consequence. | Frontal Shield Guard: blocks 100% of frontal spam with clang sparks, zero damage, and retaliates with shield bash. Requires depth flanking or jump dive attacks. |
| **Hitbox & VFX Alignment** | Slashes and beams hardcoded horizontally along $X$; missed depth targets visually but hit due to 2D math. | Directional reach cone + 3D rotated visual arcs & beams along horizontal attack vector. Full alignment of animation, hitbox, and VFX. |
| **Boss Design** | Single cleave swing with predictable timing; susceptible to infinite attack spam. | 3 Distinct Telegraphed Patterns:<br>1. Ground Fissure Shockwave (jump evasion)<br>2. Bastion Line Charge (depth sidestep)<br>3. 360 Whirlwind Cleave / Quake Ring (parry/backdash). |
| **Jump & Ground Shadow** | Shadow stayed attached to character sprite, causing visual disconnect during jumps. | Shadow decoupled to floor plane ($Y = 0.015$), tracking player's $(X, Z)$ ground footprint during jumps and scaling with height. |
| **Camera Presentation** | Static framing; no depth tracking. | Smooth dynamic tracking in $X$ and dampened depth follow in $Z$, bounded by active encounter gates. |
| **Commercial Impression** | Tech-demo / prototype feel. | Commercial-grade indie action vertical slice (*Streets of Rage* / *Guardian Heroes* feel). |

---

## 3. Quantitative Metrics

```text
================================================================================
                      V3-021 QUANTITATIVE BENCHMARKS
================================================================================
Metric                           Before (V3-020)       After (V3-021)
--------------------------------------------------------------------------------
Stage 1 Traversal Length         38.0 meters           100.0 meters (+163%)
Gameplay Depth Span              0.0 meters (Z=0 lock) 6.4 meters (Z in [-3.2, 3.2])
Encounter Gates                  1 Wave                3 Gates + Boss Sanctuary
Normal Enemy Count               2 minions             12 minions (6x increase)
Enemy Archetypes                 1 type                3 types
Boss Attack Patterns             1 pattern             3 distinct telegraphed patterns
Anti-Spam Shield Block           No                    Yes (100% frontal block)
Directional Slash/Beam Rotation  0 deg (fixed X)       Full 360 deg horizontal Yaw
================================================================================
```
