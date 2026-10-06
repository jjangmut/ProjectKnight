# [TASK-AR-015] Stage 2 (야수숲) Baseline 품질 감사 보고서

- **작업**: TASK-AR-015 Stage 2 Graphics Pass 002
- **기준 브랜치**: `antigravity/graphics-quality-pass-001-r3-perf`
- **검토일**: 2026-10-05
- **모바일 상태**: **`ANDROID PERFORMANCE NOT VERIFIED`**

---

## 1. 6개 대표 장면 캡처 현황

Stage 2 초기 기준 캡처 완료 (`ART_REVIEW/graphics-pass-002-stage2/before/`):
1. `01_stage2_entry.png`: 숲의 진입로 및 오프닝 전경
2. `02_stage2_first_beast.png`: 첫 Charging Beast 돌진 전투
3. `03_stage2_mid_forest.png`: 중반부 숲/지형 및 플랫폼 전경
4. `04_stage2_route_choice.png`: 상층 거목 덩굴길 vs 하층 안전로 분기
5. `05_stage2_boss_combat.png`: Beast Chieftain(심연의 맹수 우두머리) 결전
6. `06_stage2_boss_reward.png`: 보스 격파 및 유물 카드 보상 화면

---

## 2. Baseline 시각 품질 결함 분석

### 1) 환경 정체성 및 실루엣 (Environment Identity)
- **문제점**:
  - 배경(`background_v1.png`)이 단일 평면 텍스처로 표시되며, 원경-중경-근경의 유기적 숲 깊이감이 부족함.
  - 하늘 층(`LayerSky`)이 밋밋한 녹색조 사각형에 불과하여 깊은 고대 수관(Canopy)의 울창함이 느껴지지 않음.
  - Stage 1 성벽 외곽과 구별되는 독자적인 고대 숲 랜드마크가 전무하여 횡스크롤 진행 시 장소 기억성이 낮음.

### 2) 지형 유기성 및 부유 플랫폼 문제 (Terrain & Floating Platforms)
- **문제점**:
  - 발판 지지대(`StageStaticArt`)가 Stage 1의 석조 기둥 모델(`width 24px`)을 그대로 답습하여 고대 숲 지형과 이질적인 직사각형 인공 기둥으로 보임.
  - 공중에 떠 있는 플랫포머 게임 블록 느낌이 남아 있으며, 고목 뿌리 덩굴, 이끼, 바위 파편에 의한 지지 개연성이 결여됨.

### 3) Charging Beast 및 전투 시인성 (Combat Readability)
- **문제점**:
  - Charging Beast의 어두운 갈색/검은색 털 실루엣이 짙은 숲 바닥과 모듈레이트 그림자 속에서 배경에 묻힘.
  - 돌진 공격 전조선이 얇은 실선(`draw_line 5px`)으로만 표현되어, 모바일 화면 및 빠른 돌진 액션 상황에서 0.3~0.5초 내에 위험 방향과 범위를 인지하기 어려움.

### 4) Beast Chieftain 보스 아레나 무대감 (Boss Arena Presentation)
- **문제점**:
  - 최종 관문 보스전 구역(E6, x=9400~10740)이 일반 숲 필드와 시각적으로 동일한 평지에 불과함.
  - 맹수들의 우두머리가 지배하는 고대 제단이나 거목 뿌리가 휘감은 결전 사냥터로서의 공간적 위압감과 무대 연출이 부재함.

---

## 3. Cycle A 개선 목표

1. **Parallax 4계층 고도화**:
   - Layer 1: 깊은 숲 수관(Dense Canopy) 및 차단된 빛줄기(God Rays)
   - Layer 2: 거대한 고목 실루엣(Ancient Great Trees & Distant Trunks)
   - Layer 3: 이끼 낀 고대 폐허 석벽 및 덩굴 아치(Overgrown Ruins)
   - Layer 4: 전경 덩굴 및 이끼 안개 프레이밍(Foreground Vines & Mist)
2. **지형 유기적 지지 구조화 (`StageStaticArt`)**:
   - Stage 2 전용 거대 뿌리(Twisted Roots) 및 덩굴 감긴 고대 석주 지지대 구현.
   - 발판 하단 유기적 이끼 덩굴 처마(Overgrowth Fringe) 추가로 부유감 완전 제거.
3. **Stage 2 랜드마크 3종 구축**:
   - Landmark 1: 고대 뿌리가 감싼 폐허 문 (Overgrown Ruin Portal, x=400)
   - Landmark 2: 쓰러진 고대 수호신 동물상 (Fallen Beast Colossus, x=5400)
   - Landmark 3: 맹수 우두머리 영역 관문 (Alpha Beast Domain Gate, x=9350)
4. **Charging Beast 돌진 전조(Telegraph) 시인성 강화**:
   - 호박색/주황색(`Warm Amber / Blazing Orange`)의 지면 돌진 궤적 셰브론(`>> >> >>`) 및 맹수 안광 스파크.
5. **Beast Chieftain 보스 아레나 무대 연출**:
   - 보스 결전 구역 전용 거대 뿌리 아치 프레이밍, 중앙 클리어링 및 고대 맹수 제단 실루엣 구축.
