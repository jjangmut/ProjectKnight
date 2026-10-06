# [TASK-AR-016] Stage 3 (무너진 성벽) Cycle A 자체 품질 감사 보고서

- **작업**: TASK-AR-016 Stage 3 Graphics Pass 003 — Cycle A
- **기준 브랜치**: `antigravity/graphics-quality-pass-002-stage2`
- **작업 브랜치**: `antigravity/graphics-quality-pass-003-stage3`
- **검토일**: 2026-10-06
- **모바일 상태**: **`ANDROID PERFORMANCE NOT VERIFIED`**

---

## 1. Cycle A 캡처 분석 결과

6개 대표 장면 캡처 완료 (`ART_REVIEW/graphics-pass-003-stage3/cycle_a/`):
1. `01_stage3_entry.png`: 붕괴 성벽 진입로 및 오프닝 전경 (황혼 폭풍 하늘, 원경 연기, Landmark 1 무너진 망루 확인)
2. `02_stage3_first_ranged.png`: 첫 RangedEnemy 전투 (호박색 조준선 궤적, 총구 스파크, 타겟 레티클 확인)
3. `03_stage3_vertical_wall.png`: 중반부 수직 성벽/망루 횡단 지형
4. `04_stage3_route_choice.png`: 상층 흉벽 vs 하층 통로 분기 표지판 및 지형
5. `05_stage3_boss_combat.png`: Crossbow Commander 보스 결전 구역 및 Landmark 3 사령관 성루
6. `06_stage3_boss_reward.png`: 보스 격파 및 유물 카드("폐허 저격수의 예기 화살깃") 보상 UI

---

## 2. 발견된 시각적 결함 및 개선 과제

### 1) 소형 부유 발판의 지지대 누락 결함 (Critical Platform Grounding Issue)
- **현상**:
  - `04_stage3_route_choice.png` 및 `05_stage3_boss_combat.png`에서 폭 140px 미만의 소형 발판에 목재 비계(`scaffold_struts`)가 연결되지 않고 공중에 부유함.
- **원인**:
  - `stage_static_art.gd`의 `valid_height` 및 `valid_width` 조건문에서 Stage 2(`cached_stage_num == 2`)만 `p_width > 40` 및 `top_y < 595`로 허용되고, Stage 3는 Stage 1 조건(`p_width > 140.0`, `top_y < 540`)으로 평가되어 소형 발판이 지지대 생성에서 제외됨.
- **Cycle B 해결책**:
  - `is_grounded_stage = cached_stage_num >= 2`로 확장하여 폭 40px 이상의 모든 공중 발판에 목재 비계 트러스(`scaffold_struts`)와 하단 탄화 들보(`slab_timber`)를 강제 연결, 부유감 100% 제거.

### 2) Landmark 1 (무너진 망루) HUD 겹침 및 단조로운 실루엣 (Landmark 1 Sculpting)
- **현상**:
  - `01_stage3_entry.png`에서 망루의 상단 높이가 y=175까지 치솟아 상단 HUD 인카운터 진행바(`1구간으로 이동하세요`)와 일부 겹침. 또한 타워 본체가 단순 사다리꼴 단색으로 칠해져 거대 석조 망루의 질감이 부족함.
- **Cycle B 해결책**:
  - 망루 상단을 y=220 수준으로 낮춰 HUD와의 겹침을 완전 해소.
  - 망루 벽면에 횡방향 조적선(Masonry Courses), 부서진 아치 창문(Broken Arrow Slit), 붕괴된 석재 파편(Fractured Stone Boulders)을 다층 묘사하여 고대 공성전 잔해의 중후함 부여.

### 3) Landmark 3 (사령관 성루) 깃발 및 기단 조형성 고도화 (Banner & Parapet Fidelity)
- **현상**:
  - `05_stage3_boss_combat.png`의 붉은 군기(War Banners)가 단순 마름모 2개로 표현되어 바람에 찢긴 깃발의 역동성이 떨어짐.
- **Cycle B 해결책**:
  - 찢어진 깃발 끝단(Tattered Swallow-tail Banners)을 다각 폴리곤으로 조형하고, 깃대(Flagpole)와 금속 장식 링을 추가하여 전장의 처절함을 시각화.

### 4) Crossbow Commander 보스 공격 전조 대비 및 무대감 강화 (Boss Telegraph & Arena Polish)
- **현상**:
  - 보스 주변의 공격 전조 박스가 밋밋한 백색 테두리로만 표시되어 원거리 저격 보스로서의 위협감이 부족함.
- **Cycle B 해결책**:
  - 저격 윈드업 시 고대비 앰버/오렌지 충격 림과 방향성 전조 라인을 부각하고, 보스 아레나 바닥에 불탄 쇠말뚝 및 공성 화살통 디테일을 강화.

---

## 3. Cycle B 추진 계획

1. **전 발판 지지대 100% 연결**: `is_grounded_stage = cached_stage_num >= 2` 적용으로 소형 발판 부유감 완전 제거.
2. **Landmark 1 & 3 조형성 및 HUD 조화**: 망루 높이 조절, 조적선/화살 슬릿 추가, 찢긴 군기 디테일링.
3. **보스 아레나 및 사격 전조 고도화**: 고대비 사격 전조와 전장 소품 디테일 보강.
4. **10대 품질 평가 산정 (평균 ≥ 8.0 목표)** 및 6개 대표 장면 최종 캡처 (`after/`).
