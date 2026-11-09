# ProjectKnight Studio V3 — Game Design Acceptance Card
## Task V3-006: Stage 4 Titan Stone Sanctuary (돌의 성소) Encounter Design

- **Task ID:** V3-006
- **Stage:** Stage 4 (돌의 성소 / Titan Stone Sanctuary)
- **Author:** PK_GameDesign (Lead Game Designer)
- **Role:** Player Experience, Combat Rhythm, Traversal & Encounter Pacing Authority
- **Date:** 2026-11-09
- **Design Review Verdict:** **DESIGN PASS**

---

## 1. Pacing & Combat Archetype Escalation Across Stages 1 to 4

| Stage | Theme & Environment | Primary Combat Rhythm | Signature Enemy Mechanics | Player Reaction Demands |
|---|---|---|---|---|
| **Stage 1** | Citadel Terrace Gate (성문 외곽) | Heavy Melee Fundamentals | Melee Swordsmen & Shielded Knight Captain (Charge Attack) | Timing guard/parry, spacing strike combos. |
| **Stage 2** | Beastwood Forest Gorge (야수숲) | Aerial Ambush & Mobility | Feral Beasts & Beast Chieftain (0.35s Pounce Leap, Triple Claw, Enraged Roar) | Vertical evasion, parrying fast multi-hit rushes. |
| **Stage 3** | Ruined Crossbow Bastion (무너진 성벽) | Tactical Ranged Zoning | Crossbow Minions & Commander (Fan Volley, 2D Backstep, In-lane Caltrops, Rapid Barrage) | Bullet reading, timing jumps over traps, guard reflection. |
| **Stage 4** | **Titan Stone Sanctuary (돌의 성소)** | **Heavy Area Denial & Deliberate Timing** | **Heavy Golems (HP 8) & Golem Guardian (HP 34, Poise 16, Ground Slam, Spinning Lariat, Magma Fissure)** | **Reading heavy windup telegraphs, clash parrying colossal rushes, jumping over expanding radial shockwaves & linear molten fissures.** |

---

## 2. Telegraph Fairness & Counterplay Matrix

1. **Heavy Golem Minions (Wave 1, 2 Golems, HP 8 each)**:
   - **Characteristics:** High mass colossus (~2.0m tall), high poise, heavy rock strikes (damage 2, cooldown 1.6s).
   - **Counterplay:** 1.25m standoff spacing prevents cheap pushing. Player can weave attacks between the golem's slow windup or parry to open counterattack windows.
2. **Ground Slam (Pattern 1, Boss Initial & Phase 2)**:
   - **Telegraph:** 0.35s glowing red danger ring expanding on floor + floating danger alert ("!") + arms raised high (Frame 8) with 0.42s total windup.
   - **Impact:** Basalt pillars erupt behind combatants ($Z \le 0.0$); radial shockwave cylinder (radius 4.5m, height 1.0m) expands outwards.
   - **Counterplay:** Jump height reaches $Y \approx 1.8 \sim 2.5\text{m}$, allowing players to leap over the 1.0m shockwave, or hold guard/parry on ground.
3. **Spinning Lariat (Pattern 2, High-Speed Rush)**:
   - **Telegraph:** Swirling dust particles activate around boss base + spinning animation starts (Frame 0 of skills sheet).
   - **Rush:** Boss charges forward along X axis at $11.5\text{m/s}$ ($13.5\text{m/s}$ in Phase 2) with $v_z = 0.0000$.
   - **Counterplay:** Timing a Just Parry halts the entire colossus on impact, cancels the lariat, inflicts 2.0s stun, and strips 4 poise points. If poise drops to 0, triggers 3.0s GROGGY breakdown with +1 bonus shatter damage.
4. **Quake Fissure (Pattern 3, Phase 2 Overload at $HP \le 17$)**:
   - **Telegraph:** Magma core aura ring glows violently + ember particles erupt + 0.35s ground danger ring + raised fist strike (Frame 8 skills sheet, 0.40s windup).
   - **Impact:** Linear molten lava cracks erupt along floor (5 segments, 8.5m length) with blazing orange runic glow.
   - **Counterplay:** Low fissure hitbox height ($0.9\text{m}$) allows clean aerial leap over the hazard. Single-hit gate ensures player is only damaged once if touched.

---

## 3. Game Design Acceptance Checklist

- [x] Encounter feels distinct from Stages 1-3 (heavy area denial vs ranged bullet zoning).
- [x] Boss initial HP 34 / Poise 16 offers a satisfying, deliberate boss fight duration ($\approx 15 \sim 20$ seconds).
- [x] All danger warnings give fair reaction windows ($\ge 0.35\text{s}$).
- [x] Both Heavy Golems have separate defeat callbacks and fair spacing.
- [x] Jump, Guard, Parry, and Dash all serve clear strategic purposes in the boss fight.
- [x] Zero unavoidable damage or cheap trap placements.
