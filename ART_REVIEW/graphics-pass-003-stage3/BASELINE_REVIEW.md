# [TASK-AR-016] Stage 3 (무너진 성벽) Baseline 자체 품질 감사 보고서

- **작업**: TASK-AR-016 Stage 3 Graphics Pass 003 — Baseline Audit
- **기준 브랜치**: `antigravity/graphics-quality-pass-002-stage2`
- **작업 브랜치**: `antigravity/graphics-quality-pass-003-stage3`
- **검토일**: 2026-10-06
- **모바일 상태**: **`ANDROID PERFORMANCE NOT VERIFIED`**

---

## 1. Baseline 캡처 분석 결과

6개 대표 장면 Baseline 캡처 완료 (`ART_REVIEW/graphics-pass-003-stage3/before/`):
1. `01_stage3_entry.png`: 붕괴 성벽 진입로 및 오프닝 전경
2. `02_stage3_first_ranged.png`: 첫 RangedEnemy(사수) 조우 전투 구역
3. `03_stage3_vertical_wall.png`: 중반부 수직 성벽/망루 횡단 지형
4. `04_stage3_route_choice.png`: 상층 흉벽 vs 하층 통로 분기 및 고지대 발판
5. `05_stage3_boss_combat.png`: Crossbow Commander(폐허의 석궁 사령관) 보스 결전 구역
6. `06_stage3_boss_reward.png`: 보스 격파 및 유물 카드("폐허 저격수의 예기 화살깃") 보상 UI

---

## 2. 현행 시각적 결함 및 문제점 분석

### 1) 배경 분위기 및 테마 완전 불일치 (Critical Theme Mismatch)
- **현상**:
  - `assets/campaign/stage_three_v1.png`가 그대로 노출되어, 푸른 대낮 하늘과 눈 덮인 설산, 온전한 파란 깃발의 왕국 성채가 나타남.
  - "전쟁으로 무너진 외곽 성벽", "공성전의 참화", "황혼 폭풍/먼지/불씨"라는 Stage 3 본래의 컨셉과 정반대의 평화로운 한낮 풍경임.
- **개선 방향**:
  - `parallax_stage_backdrop.gd`에서 Stage 3 전용 4계층 패럴랙스 구축:
    - Layer 1 (LayerSky): 황혼 폭풍 및 짙은 먼지 보라빛 하늘(`Color(0.12, 0.08, 0.14)`), 붉은 석양 광훈.
    - Layer 2 (LayerDistantPeaks): 불타는 공성전 연기(Smoke Wisps), 부서진 망루 및 붕괴된 성채 능선 실루엣.
    - Layer 3 (LayerMidRuins): 파괴된 요새 석벽 일러스트를 어두운 황혼 틴트(`Color(0.55, 0.42, 0.48)`)로 차분하게 침전.
    - Layer 4 (LayerForegroundFog): 전경 부서진 흉벽 파편(Broken Battlements) 및 공중 부유 재/먼지 연무.

### 2) Stage 1 지형/기둥 에셋 재사용 및 부유 발판 결함 (Asset Reuse & Floating Blocks)
- **현상**:
  - 공중 발판 지지대가 Stage 1의 온전한 성벽 석조 기둥과 코벨을 그대로 재사용하고 있음.
  - 폭 140px 미만의 소형 발판(예: `04_stage3_route_choice.png` 중앙)은 아무 지지 구조 없이 허공에 부유.
- **개선 방향**:
  - `stage_static_art.gd`에서 Stage 3 전용 붕괴 구조물 구현:
    - 갈라진 석조 블록(Fractured Masonry), 부러진 목재 비계(Wood Scaffolds), 철제 고정 띠(Iron Braces/Clamps), 끊어진 들보(Collapsed Beams).
    - 소형 발판을 포함한 모든 발판에 성벽 잔해 지지대 또는 비계 브래킷을 연결하여 부유감 100% 제거.

### 3) 랜드마크 3종 완전 부재 (Lack of Landmarks)
- **현상**:
  - 성벽의 역사를 말해주는 공성전 잔해나 대형 구조물이 전무하여 12,000px 횡단 중 위치 인지가 어려움.
- **개선 방향**:
  - **Landmark 1 (x≈450)**: 반쯤 무너진 거대 망루 (Leaning Ruined Watchtower with Fallen Battlements & Cracked Masonry).
  - **Landmark 2 (x≈5500)**: 파괴된 공성 투석기 잔해 (Shattered Trebuchet & Siege Engine Wreckage, Broken Wheels, Massive Beams).
  - **Landmark 3 (x≈10000)**: 석궁 사령관 전용 고지대 방어 성루 (Command Parapet with Iron Ballista Emplacement & Battle-torn Banners).

### 4) RangedEnemy 조준선 및 사격 가독성 부족 (Combat Readability)
- **현상**:
  - 일반 RangedEnemy의 사격 전조가 미약한 보라빛 원에 불과하여, 배경 밝기에 묻히고 어디로 발사되는지 직관적 인지 불가.
- **개선 방향**:
  - `stage_art.gd`에서 원거리 사격 전조 가독성 강화:
    - 호박색/주황빛 조준 레이저 궤적(Warm Aiming Trajectory) 및 석궁 총구 발광(Muzzle Spark).
    - 투사체(Projectile)의 비행 궤적 및 림라이트를 배경 대비 고광도로 강조.

### 5) Crossbow Commander 보스 아레나 무대감 결여 (Boss Arena Staging)
- **현상**:
  - 보스전 공간(x=10000~11000)이 일반 평지와 다를 바 없으며, 사령관으로서의 전장 압도감이 없음.
- **개선 방향**:
  - 보스 뒤편 최상층 성루 실루엣, 부서진 대형 발리스타 거치대, 바람에 찢긴 깃발, 사선 사격 위험을 알리는 경고 조명 구축.

---

## 3. Cycle A 작업 목표

1. **패럴랙스 4계층 고도화**: 황혼 폭풍 하늘, 불타는 망루 실루엣, 차분한 황혼 요새 벽, 전경 파편.
2. **지형 접지 및 붕괴 질감**: 부서진 석조/목재 비계 지지대 구현, 부유 발판 완전 제거.
3. **고대 랜드마크 3종 구축**: 반쯤 무너진 망루(x≈450), 공성 투석기 잔해(x≈5500), 사령관 성루(x≈10000).
4. **원거리 사격 조준 전조(Warm Aiming Line) 및 투사체 시인성 강화**.
5. **보스 아레나 무대화 및 Cycle A 캡처 / 자체 감사**.
