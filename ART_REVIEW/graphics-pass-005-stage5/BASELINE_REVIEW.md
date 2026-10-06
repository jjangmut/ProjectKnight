# [STAGE 5] 침묵의 성채 (Silent Citadel) Graphics Pass 005 — Baseline Review

- **작업명**: TASK-AR-019 Stage 5 Graphics Pass 005
- **분석 일자**: 2026-10-06
- **대상 스테이지**: Stage 5 (침묵의 성채 / Silent Citadel / Abyssal Citadel)
- **모바일 상태**: `ANDROID PERFORMANCE NOT VERIFIED`

---

## 1. 개요 및 아트 디렉션 목표

Project Knight의 마지막 5번째 스테이지인 **침묵의 성채(Silent Citadel)**는 앞선 4개 지역(인간 성벽 외곽, 야수숲, 무너진 성벽, 돌의 성소)을 총결산하는 최종장입니다. 단순한 '보라색 성채 재색칠(Purple Recolor)'을 지양하고, 세계가 심연에 잠식되어 물리 법칙이 뒤틀린 **불가능한 건축(Impossible Architecture)**과 최종 보스 **심연의 심판관(Abyssal Arbiter)**의 압도적인 위압감을 완성하는 것을 목표로 합니다.

---

## 2. Baseline 현황 분석 (Before)

### 1) 배경 및 패럴랙스 (Backdrop & Parallax)
- **현재 상태**:
  - `ParallaxStageBackdrop`에 Stage 5 전용 4계층 그래픽이 구축되지 않아, 기본 어두운 배경 사각형과 단순 원형 붉은 달만 표시됨.
  - `assets/campaign/stage_five_v1.png`가 평면적으로 배치되어 원경-중경의 깊이감과 심연의 공간감이 극도로 부족함.
  - 최종장의 상징적 천체인 **검은 일식(Black Eclipse)**, 심연의 차원 균열, 솟구친 왜곡된 첨탑군의 실루엣 부재.

### 2) 지형 및 플랫폼 접지 구조 (Platform Grounding)
- **현재 상태**:
  - `StageStaticArt`에서 `cached_stage_num == 5` 분기가 없어 Stage 1의 기본 석조 까치발/기둥 코드가 그대로 호출되거나 공중에 떠 있는 플랫 블록처럼 보임.
  - Section 12 지침에 명시된 Stage 5 고유 지형 언어인 **Void-anchored black stone pillar**, **Broken royal arch**, **Massive chain suspension**, **Corrupted structural shards**가 전무함.

### 3) 3대 핵심 랜드마크 부재
- **현재 상태**:
  - **Landmark 1 (침묵의 왕문, x ≈ 400)**: 진입부를 알리는 거대한 흑석 성문, 부서진 왕가 문장, 늘어진 쇠사슬 부재.
  - **Landmark 2 (심연에 잠긴 왕좌 회랑, x ≈ 5600)**: 왕국의 몰락을 보여주는 파괴된 왕좌, 쓰러진 조각상, 찢겨진 왕실 깃발, 무중력 부유 석조 조각 부재.
  - **Landmark 3 (Abyssal Arbiter 최종 심판실, x ≈ 11000..12200)**: 거대한 왕좌 실루엣, 흑석 오벨리스크, 보이드 포털, 크림슨 바닥 균열이 없어 보스전 무대감이 결여됨.

### 4) 갈림길 안내 및 환경 서사
- **현재 상태**:
  - 경로 안내 현판에 일반 문구("선택 전투 / 필수 전투")가 출력되어 최종장의 절박하고 불길한 분위기를 살리지 못함.
  - `AtmosphericMotes`가 고정된 보라색 파티클로만 남아 있어, 보스 결전 시의 크림슨 스파크 전환 등 연출 연동이 부족함.

### 5) 전투 및 보스 시인성 (Readability)
- **현재 상태**:
  - 배경이 어두운 가운데 플레이어와 적의 실루엣 분리가 명확해야 함.
  - 혼합 적(Beast, Golem, Melee) 등장 시 각 적의 공격 전조(Telegraph)가 환경의 보라색 에너지와 간섭되지 않도록 고휘도 크림슨/핫오렌지-레드/화이트 코어 대비가 엄격히 보장되어야 함.

---

## 3. 대표 장면 7종 Baseline 이미지 기록 (`before/`)

1. `01_stage5_entry.png`: 성채 입구 진입 지점 (랜드마크 1 부재, 단순 배경)
2. `02_stage5_first_combat.png`: 첫 혼합 전투 지점 (일반 블록 지형, 심연 분위기 미약)
3. `03_stage5_royal_ruins.png`: 성채 중반부 회랑 (공중 부유 플랫폼, 구조적 개연성 결여)
4. `04_stage5_route_choice.png`: 상층/하층 갈림길 (일반 현판 문구, 단순 발판)
5. `05_stage5_preboss.png`: 보스전 직전 진입로 (최종 결전 직전의 긴장감 부족)
6. `06_stage5_boss_combat.png`: 심연의 심판관 전투 (보스 아레나 무대 장치 부재)
7. `07_stage5_boss_reward.png`: 보스 격파 및 최종 승리 모달 (심연의 관 유물 획득)

---

## 4. Cycle A 개선 계획 (구현 범위)

1. **4계층 패럴랙스 백드롭 고도화 (`parallax_stage_backdrop.gd`)**:
   - **Layer 1 (0.05x)**: 심연의 하늘 + 검은 일식(Black Eclipse with radiant crimson corona) + 차원 균열(Void Fissures).
   - **Layer 2 (0.18x)**: 높이를 가늠할 수 없는 왜곡된 흑석 성채 첨탑군과 부유 첨탑 실루엣.
   - **Layer 3 (0.42x)**: 일러스트 텍스처 틴트 보정 + 붕괴된 왕실 성벽 및 불가능한 아치 구조물.
   - **Layer 4 (1.00x)**: 전경 상단 흑석 코니스 천장보 + 늘어진 거대 쇠사슬 + 심연의 안개.
2. **StageStaticArt 지형 캐시 및 랜드마크 구축 (`stage_static_art.gd`)**:
   - Stage 5 전용 플랫폼 접지: 흑석 지주, 부서진 고딕 왕실 아치 브래킷, 거대 사슬 현수, 심연 룬 크랙.
   - 3대 랜드마크 1회 사전 캐시:
     - Landmark 1 (침묵의 왕문)
     - Landmark 2 (심연에 잠긴 왕좌 회랑)
     - Landmark 3 (Abyssal Arbiter 최종 심판실 & 보스 아레나)
   - 전용 갈림길 현판: "↑ 상층: 심연의 공중 회랑 · 회복 +1", "→ 아래 길: 침묵의 성채 통로로 전진".
3. **환경 앰비언스 및 조명 튜닝 (`stage_art.gd`)**:
   - `AtmosphericMotes`: 보이드 분진(Void Ash)에서 보스전 진입 시 붉은 불꽃 스파크로 다이내믹 전환.
   - 캔버스 모듈레이트 및 2D Glow 균형 조율.
