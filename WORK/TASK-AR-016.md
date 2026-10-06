# [TASK-AR-016] Stage 3 — 무너진 성벽 Graphics Pass 003

## 상태

`INDEPENDENT REVIEW REQUESTED`

## 담당

Antigravity / JPStudio Graphics Quality Director

## 우선순위

`P0`

## 기준 브랜치

`antigravity/graphics-quality-pass-002-stage2`

## 신규 작업 브랜치

`antigravity/graphics-quality-pass-003-stage3`

---

# 1. Stage 3 목표

- 이름: **무너진 성벽 (Collapsed Fortress / Ruined Wall)**
- 목적: 무너진 왕국 외곽 성벽과 공성전 흔적이 남은 위험한 고지대 전장으로 만들고, 높이 차이(Verticality)와 원거리 사격 위험(Ranged Threat)을 시각적으로 명확하게 전달한다.
- Stage 1 성문 외곽(안정된 석벽, 블루-골드) 및 Stage 2 야수숲(유기적 녹색 숲, 뿌리/덩굴)과 확실히 다른 환경 아이덴티티 확립.

---

# 2. 절대 변경 금지 항목

- 플레이어 이동 수치, 점프 높이, 대시 거리, 공격력, 가드/패링 수치
- RangedEnemy AI, CrossbowCommander AI, 탄속, 공격 주기, 데미지, HP
- Encounter 수, Checkpoint 위치, 플랫폼 충돌 구조, 보상 규칙, Stage progression

---

# 3. 진행 단계

1. **디렉터리 준비**: `ART_REVIEW/graphics-pass-003-stage3/{before,cycle_a,after,profiler,raw}`
2. **Baseline 감사 및 6개 대표 장면 Before 캡처**:
   - `01_stage3_entry`
   - `02_stage3_first_ranged`
   - `03_stage3_vertical_wall`
   - `04_stage3_route_choice`
   - `05_stage3_boss_combat`
   - `06_stage3_boss_reward`
3. **Cycle A**:
   - 배경/패럴랙스 4계층 고도화 (황혼 폭풍 하늘, 원경 파괴된 망루, 중경 무너진 요새 벽 `stage_three_v1.png`, 전경 부서진 성채 파편)
   - 지형 품질 및 고지대 발판 구조화 (부러진 탑 기둥, 석조 아치, 철제 보강대, 비계 구조물로 접지)
   - 랜드마크 3종 구축 (반쯤 무너진 거대 망루, 부서진 공성 투석기 잔해, 석궁 사령관 전용 고지대 성루)
   - RangedEnemy 및 석궁 조준선/투사체 가독성 강화 (호박색/주황빛 조준선, 선명한 투사체 궤적)
   - Crossbow Commander 보스 아레나 최상층 방어 성루 무대감 구축
   - Cycle A 캡처 및 자체 감사 ([`CYCLE_A_REVIEW.md`])
4. **Cycle B**:
   - 수직 구조 가독성(상층 사수 vs 하층 통로 vs 안전 발판) 및 환경 앰비언스(황혼 보라/오렌지 불씨) 고도화
   - 10개 평가 항목 자체 점수표 산정 (평균 ≥ 8.0 목표)
   - Cycle B 캡처 및 자체 감사 ([`CYCLE_B_REVIEW.md`])
5. **성능 계측 및 신규 회귀 테스트**:
   - 4개 장면 (Entry, First Ranged, Vertical Route, Boss Combat) 각 600프레임 PC 60 FPS Gate 계측
   - 신규 `stage3_graphics_pass_smoke.gd`, `stage3_render_performance_gate.gd` 작성 및 PASS
   - 기존 회귀 테스트 (Stage 1, Stage 2 포함) 100% PASS (Stage 1 & Stage 2 무회귀 입증)
6. **산출물 및 독립 검수 요청**:
   - `FINAL_REVIEW.md`, `PERFORMANCE.md`, `VISUAL_COMPARISON.md` 등 작성
   - 상태: `INDEPENDENT REVIEW REQUESTED`
