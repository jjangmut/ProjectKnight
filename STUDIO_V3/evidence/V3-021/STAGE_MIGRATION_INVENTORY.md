# V3-021 — Stage Migration Inventory & Follow-Up Roadmap

## 1. Directive & Boundary Definition

Per the user directive for milestone **V3-021**:
> "이번 작업에서는 Stage 1의 완성도에 집중한다. 기존 Stage 2~5는 이후 단계에서 개선한다. 서류와 QA 점수보다 실제 플레이 품질을 최우선으로 진행해."

To protect code integrity and prevent shallow partial rewrites, **Stage 1 (성문 외곽 / Citadel Terrace Gate)** has been rebuilt as the authoritative **2.5D Belt-Scroll Benchmark Standard**. Stages 2 through 5 are formally cataloged below as `LEGACY_STAGE_REQUIRES_MIGRATION` to be systematically upgraded in subsequent milestones according to this verified Stage 1 standard.

---

## 2. Stage Status Inventory

| Stage Index | Stage Name | Current Status | Architecture | Planned Migration Scope |
|:---:|:---|:---:|:---|:---|
| **Stage 1** | **성문 외곽 (Citadel Terrace Gate)** | **`V3-021_BENCHMARK_COMPLETE`** | 100m Corridor, 2.5D Belt-Scroll, 3 Encounter Gates, 3 Enemy Archetypes (12 minions), 3 Boss Patterns | Master reference implementation for all stages. |
| **Stage 2** | **야수숲 (Beastwood Forest Gorge)** | **`LEGACY_STAGE_REQUIRES_MIGRATION`** | Single 38m arena, Option C baseline, 2 beast minions, single-pattern Chieftain boss | Rebuild into 100m winding forest gorge, pack-hunting wolf AI, tree-jumping ambushers, multi-phase Beast Chieftain. |
| **Stage 3** | **무너진 성벽 (Ruined Crossbow Bastion)** | **`LEGACY_STAGE_REQUIRES_MIGRATION`** | Single 38m arena, Option C baseline, 2 minions, single-pattern Crossbow Commander | Rebuild into 100m ruined ramparts with multi-tier caltrops, catapult mortar barrages, and snipers on elevated parapets. |
| **Stage 4** | **돌의 성소 (Titan Stone Sanctuary)** | **`LEGACY_STAGE_REQUIRES_MIGRATION`** | Single 38m arena, Option C baseline, 2 heavy golems, Golem Guardian | Rebuild into 100m subterranean temple with rolling boulder hazards, crushing pillar traps, and 3-pattern Golem Titan. |
| **Stage 5** | **침묵의 성채 (Silent Abyssal Citadel)** | **`LEGACY_STAGE_REQUIRES_MIGRATION`** | Single 38m arena, Option C baseline, 2 elite knights, Abyssal Arbiter | Rebuild into 100m grand throne corridor with void rifts, teleporting phantom knights, and multi-phase Arbiter boss duel. |

---

## 3. Migration Standard Rulebook (Derived from Stage 1)

Any future stage migration must satisfy the following checklist established in V3-021:
1. **Map Length:** Continuous corridor traversal length $\ge 80$–$100$ meters.
2. **Depth Lane:** $Z$-axis depth span $\ge 6.0$ meters ($[-3.0, 3.0]$) with grounded shadow projection.
3. **Pacing:** $\ge 3$ distinct encounter gates with dissolving spectral barriers and encounter banners.
4. **Enemy Density:** $\ge 8$–$12$ common enemies with $\ge 3$ distinct combat roles (Chaser, Standoff Ranged, Anti-Spam Shield Frontliner).
5. **Anti-Spam:** At least one enemy type capable of frontal guarding or parrying attack button spam.
6. **Boss Patterns:** $\ge 3$ distinct telegraphed patterns requiring spatial evasion (jump, sidestep, parry).
7. **Camera Follow:** Smooth horizontal follow with depth dampening ($Z \times 0.35$) and encounter bounding.
