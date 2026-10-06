# [TASK-AR-017] Stage 4 (돌의 성소) Baseline 그래픽 품질 감사 보고서

- **작업**: TASK-AR-017 Stage 4 Graphics Pass 004 — Baseline Audit
- **기준 브랜치**: `antigravity/graphics-quality-pass-003-stage3`
- **작업 브랜치**: `antigravity/graphics-quality-pass-004-stage4`
- **검토일**: 2026-10-06
- **상태**: **`IN_PROGRESS`**
- **모바일 상태**: **`ANDROID PERFORMANCE NOT VERIFIED`**

---

## 1. Baseline 캡처 분석 결과 (Before)

6개 대표 장면 캡처 완료 (`ART_REVIEW/graphics-pass-004-stage4/before/`):
1. `01_stage4_entry.png`: 성소 진입로 전경
2. `02_stage4_first_golem.png`: 첫 GroundSlamGolem 전투 및 지면 강타 윈드업
3. `03_stage4_mid_sanctuary.png`: 중반부 성소 수직 발판 지형
4. `04_stage4_route_choice.png`: 상층 성소 vs 하층 회랑 분기점
5. `05_stage4_boss_combat.png`: Ancient Golem Guardian 보스 결전 구역
6. `06_stage4_boss_reward.png`: 보스 격파 및 유물 카드 보상 화면

---

## 2. 발견된 구조적 및 시각적 결함 분석

### 1) 패럴랙스 심도 및 성소 고유 전경 프레이밍 부재
- **현상**:
  - `01_stage4_entry.png`에서 `stage_four_v1.png` 일러스트가 단일 평면으로만 노출되며, Layer 1(심연 보이드/동굴광), Layer 2(거석 원경 기둥 열주), Layer 4(전경 부서진 거대 아치 프레이밍 및 저고도 성소 안개)가 전무함.
  - 고대 거석 문명의 신성하고 압도적인 거대 스케일감(Monumental Scale)이 평면적으로 느껴짐.

### 2) 플랫폼 지지 구조의 Stage 1 성벽 에셋 오용 (Castle Support Defect)
- **현상**:
  - `03_stage4_mid_sanctuary.png` 및 `04_stage4_route_choice.png`의 모든 공중 발판에 인간 왕국의 얇은 성곽형 기둥(`ground_texture` 기반 까치발)이 연결되어 있어 고대 거석 성소의 분위기와 극심한 부조화 발생.
- **요구사항**:
  - 거석 기둥(Monolithic Stone Pillars), 고대 석조 아치(Ancient Arches), 룬 새김 좌대(Ritual Plinths), 붕괴된 신전 거석(Megalithic Blocks)으로 전면 교체 필요.

### 3) 랜드마크 부재 (Landmarks Missing)
- **현상**:
  - `stage_static_art.gd`에 Stage 4 전용 랜드마크 데이터가 전혀 정의되어 있지 않음.
- **필수 구현 3대 랜드마크**:
  - **Landmark 1 (x≈400)**: 거대한 룬 석문 (Paired Monoliths, Rune Lintel, Cyan Seal).
  - **Landmark 2 (x≈5400)**: 쓰러진 수호자 석상 (Colossal Stone Head, Broken Arm, Shield Fragment).
  - **Landmark 3 (x≈10000)**: 고대 수호자 성소 (Ancient Guardian Sanctuary, Sealed Doorway, Braziers, Rune Dais).

### 4) GroundSlamGolem 지면 강타 전조 가독성 미흡 (Telegraph Weakness)
- **현상**:
  - `02_stage4_first_golem.png`에서 골렘이 주먹을 치켜들었을 때 지면에 단순한 1줄 얇은 황색 실선만 표시되어 강타 위험 반경과 타이밍 인지가 매우 어려움.
- **개선 방향**:
  - 고대비 호박색/주황 지면 균열 림(Amber/Orange Floor Crack Rim), 충격 원형(Impact Circle), 지면 룬 활성화(Rune Activation Line), 융기 파편을 조합한 명확한 5단계 전조(Prepare → Impact Zone → Slam → Shockwave → Recovery) 구현.

### 5) Ancient Golem Guardian 보스 아레나 무대감 결여
- **현상**:
  - `05_stage4_boss_combat.png`에서 보스가 일반 평지에 덩그러니 서 있어 최고위 수호자와의 결전 공간으로서의 위압감이 전혀 없음.
- **개선 방향**:
  - 중앙 의식 제단 단상, 거대 수호자 석조 기둥, 거석 봉인문, HDR 2.8 발광 호박색 청동 화로, 바닥 원형 룬을 아레나 후경에 배치하여 신성한 의식의 전당 무대감 완성.

---

## 3. Cycle A 추진 계획

1. **`parallax_stage_backdrop.gd` Stage 4 전용 4계층 패럴랙스 구축**:
   - Layer 1: 깊은 성소 보이드 및 신비로운 동굴광/천창 빛줄기 (Cyan/Warm Amber Void)
   - Layer 2: 거대한 원경 거석 기둥 및 모놀리스 열주 실루엣
   - Layer 3: 성소 벽면 부조 틴트 (`Color(1.05, 0.98, 0.88, 0.95)`)
   - Layer 4: 전경 거석 아치 프레이밍 및 저고도 신성한 성소 안개
2. **`stage_static_art.gd` Stage 4 거석 지형 & 플랫폼 접지 시스템 구축**:
   - 대형 석재 블록(`megalithic_blocks`), 거석 기둥(`monolith_pillars`), 룬 홈 슬래브(`rune_slabs`)
   - 3대 고대 랜드마크 (거대한 룬 석문, 쓰러진 수호자 석상, 고대 수호자 성소)
3. **`stage_art.gd` Ground Slam 전조 및 충격파 가독성 고도화**:
   - 호박색 지면 균열 림, 바닥 룬 펄스, 고대비 충격파 리플
4. **Cycle A 캡처 및 자체 감사 보고서 작성 (`CYCLE_A_REVIEW.md`)**.
