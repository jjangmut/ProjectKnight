# [TASK-AR-015] Stage 2 (야수숲) Cycle A 자체 품질 감사 보고서

- **작업**: TASK-AR-015 Stage 2 Graphics Pass 002 — Cycle A
- **기준 브랜치**: `antigravity/graphics-quality-pass-001-r3-perf`
- **작업 브랜치**: `antigravity/graphics-quality-pass-002-stage2`
- **검토일**: 2026-10-06
- **모바일 상태**: **`ANDROID PERFORMANCE NOT VERIFIED`**

---

## 1. Cycle A 캡처 분석 결과

6개 대표 장면 캡처 완료 (`ART_REVIEW/graphics-pass-002-stage2/cycle_a/`):
1. `01_stage2_entry.png`: 숲 진입로 및 오프닝 전경 (Parallax 4계층, 전경 덩굴 수관 프레이밍 확인)
2. `02_stage2_first_beast.png`: 첫 Charging Beast 전투 및 랜드마크 1 전경
3. `03_stage2_mid_forest.png`: 중반부 숲 지형 및 체크포인트 1
4. `04_stage2_route_choice.png`: 상층 거목 덩굴길 vs 하층 야수 숲길 분기 표지판 및 플랫폼
5. `05_stage2_boss_combat.png`: Beast Chieftain(심연의 맹수 우두머리) 보스 결전 구역 및 랜드마크 3
6. `06_stage2_boss_reward.png`: 보스 격파 및 유물 카드("심연 맹수의 그림자 망토") 보상 UI

---

## 2. 발견된 시각적 결함 및 개선 과제

### 1) 발판 하단 이끼 처마 형태 결함 (Critical Visual Defect)
- **현상**:
  - `stage_static_art.gd`에서 추가한 발판 하단 이끼 처마(`hanging_moss`)가 일정한 간격의 단순 역삼각형 폴리곤으로 반복되어, 자연스러운 이끼/덩굴이 아니라 파티용 **깃발 가랜드(Bunting Banner)** 처럼 보이는 인공적 결함 발생 (`04_stage2_route_choice.png`, `05_stage2_boss_combat.png`).
- **원인**:
  - `moss_steps` 간격마다 동일한 폭(16px)의 단일 삼각형을 일률적으로 배치함.
- **Cycle B 해결책**:
  - 단순 삼각형을 폐기하고, 다층 유기적 이끼 덩굴 클러스터로 재설계:
    - 1차 언더톤: 어두운 이끼 바탕(`Color(0.14, 0.22, 0.12, 0.95)`)의 불규칙 물결 곡면.
    - 2차 하이라이트: 상단 밝은 연두 이끼 림(`Color(0.38, 0.55, 0.26, 0.90)`).
    - 3차 늘어진 덩굴 실선: 불규칙한 길이의 수직 덩굴 라인(`draw_line`)을 무작위 분포하여 야생 숲의 개연성 확보.

### 2) 소형 부유 발판의 지지 구조 누락 (Platform Grounding)
- **현상**:
  - 폭 140px 미만의 소형 발판(`04_stage2_route_choice.png` 중앙)은 `platform_data.has_supports` 조건(폭 > 140)에 걸려 지지대나 덩굴이 전혀 없이 허공에 떠 있는 상태로 남음.
- **Cycle B 해결책**:
  - 소형 발판에도 Stage 2 전용 거목 덩굴 지지 슬링(Hanging Vine Sling) 또는 고목 가지 받침대(`branch_brackets`)를 연결하여 100% 발판 부유감 제거.

### 3) 랜드마크 1 & 2 조형성 고도화 (Landmark Sculpting)
- **현상**:
  - `01_stage2_entry.png`의 고대 폐허 문(Landmark 1)이 두 개의 수직 녹색 직사각형 기둥으로 단순화되어 고대 석조 유적의 웅장함이 부족함.
- **Cycle B 해결책**:
  - 두께감 있는 거석 석조 기둥(Masonry Blocks & Fissures), 파손된 상인방(Cracked Lintel), 기둥을 나선형으로 휘감은 거대 나무뿌리(Coiling Strangler Fig) 묘사를 강화하여 장엄한 고대 문으로 업그레이드.

### 4) 보스 아레나 무대감 및 중앙 피의 제단 (Boss Arena Presentation)
- **현상**:
  - Beast Chieftain 보스전 구역(`05_stage2_boss_combat.png`)의 좌측 투구 관문(Landmark 3)은 인지되나, 우측 보스 위치 뒤편의 고대 맹수 제단 실루엣이 평지에 묻혀 무대 중심성이 약함.
- **Cycle B 해결책**:
  - 중앙 피의 제단(Sacrificial Altar)의 계단 기단(Stepped Dais)과 거석 제단 크기를 확대하고, 맹수의 붉은 발톱 자국 및 앰버 불씨 광원 대비를 강화하여 결전의 무대감 완성.

---

## 3. Cycle B 추진 계획

1. **지형/이끼 고도화**:
   - 가랜드형 삼각형 이끼 완전 제거 ➔ 다층 유기적 이끼 클러스터 + 수직 덩굴 실선 구현.
   - 모든 크기의 발판에 덩굴 슬링/뿌리 브래킷 부여로 부유감 100% 소멸.
2. **랜드마크 3종 디테일 완성**:
   - Landmark 1 (고대 거석 폐허 문): 파손된 석재 블록, 나선형 뿌리, 발광 룬 각인.
   - Landmark 2 (쓰러진 고대 수호 동물상): 거대 뿔/턱선 및 이끼/크리스탈 안광.
   - Landmark 3 (맹수 우두머리 영역 관문 & 피의 제단): 거대 상아 토템 및 제단 붉은 불씨.
3. **전투 시인성 & 전조 시연 캡처**:
   - Charging Beast 돌진 전조(호박색 셰브론 지면 활주로 `>> >> >>` 및 안광 스파크)가 발동된 역동적 순간 캡처.
4. **Cycle B 완료 후**:
   - 10개 평가 기준 점수표 산정 (평균 ≥ 8.0 목표).
   - 6개 최종 장면 캡처 (`after/`).
