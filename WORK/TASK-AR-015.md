# [TASK-AR-015] Stage 2 — 야수숲 Graphics Pass 002

## 상태

`INDEPENDENT REVIEW REQUESTED`

## 담당

Antigravity / JPStudio Graphics Quality Director

## 우선순위

`P0`

## 기준 브랜치

`antigravity/graphics-quality-pass-001-r3-perf`

## 신규 작업 브랜치

`antigravity/graphics-quality-pass-002-stage2`

---

# 1. Stage 2 목표

- 이름: **야수숲 (Ancient Beast Forest)**
- 목적: Stage 1(성문 외곽)과 확실히 구별되는 야생 숲/고대 폐허 환경을 구축하고, Charging Beast와 Beast Chieftain 전투가 녹색 배경에 묻히지 않도록 대비를 강화하며, 모바일 화면에서도 진행 방향과 위험 신호(전조)를 명확히 전달한다.

---

# 2. 절대 변경 금지 항목

- 플레이어 이동 수치, 공격 수치
- 가드/패링 판정
- ChargingBeast AI, BeastChieftain AI, 보스 공격 패턴
- 데미지, HP, 웨이브 수, Encounter 구조, Checkpoint 위치, Stage progression, Optional Encounter 보상 규칙

---

# 3. 진행 단계

1. **디렉터리 준비**: `ART_REVIEW/graphics-pass-002-stage2/{before,after,profiler,raw}`
2. **Baseline 감사 및 6개 대표 장면 Before 캡처**:
   - `01_stage2_entry`
   - `02_stage2_first_beast`
   - `03_stage2_mid_forest`
   - `04_stage2_route_choice`
   - `05_stage2_boss_combat`
   - `06_stage2_boss_reward`
3. **Cycle A**:
   - 배경/패럴랙스 재작업 (4-Layer: Sky canopy, Distant ancient trees, Overgrown ruins, Foreground framing)
   - 지형 품질 및 부유 플랫폼감 제거 (유기적 뿌리/석주/덩굴 지지 구조화)
   - 랜드마크 3종 구축 (고대 뿌리 폐허문, 쓰러진 고대 수호석상, 맹수 우두머리 영역 관문)
   - Charging Beast 시인성 및 돌진 전조(Amber/Orange) 대비 강화
   - Beast Chieftain 보스 아레나 중앙 클리어링 및 고대 제단 무대감 구축
   - Cycle A 캡처 및 자체 감사 ([`CYCLE_A_REVIEW.md`])
4. **Cycle B**:
   - 깊이감, 환경 조명(CanvasModulate/Glow/Motes), UI 조화 고도화
   - 10개 평가 항목 자체 점수표 산정 (평균 ≥ 8.0 목표)
   - Cycle B 캡처 및 자체 감사 ([`CYCLE_B_REVIEW.md`])
5. **성능 계측 및 신규 회귀 테스트**:
   - 4개 장면 (Entry, First Beast, Mid Forest, Boss Combat) 각 600프레임 PC 60 FPS Gate 계측
   - 신규 `stage2_graphics_pass_smoke.gd`, `stage2_render_performance_gate.gd` 작성 및 PASS
   - 기존 11개 회귀 테스트 100% PASS (Stage 1 무회귀 입증)
6. **산출물 및 독립 검수 요청**:
   - `FINAL_REVIEW.md`, `PERFORMANCE.md`, `VISUAL_COMPARISON.md` 등 작성
   - 상태: `INDEPENDENT REVIEW REQUESTED`
