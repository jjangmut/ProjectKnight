# [TASK-AR-017] Stage 4 — 돌의 성소 Graphics Pass 004

## 상태

`INDEPENDENT REVIEW REQUESTED`

## 담당

Antigravity / JPStudio Graphics Quality Director

## 우선순위

`P0`

## 기준 브랜치

`antigravity/graphics-quality-pass-003-stage3`

## 신규 작업 브랜치

`antigravity/graphics-quality-pass-004-stage4`

---

# 0. 이전 Stage 상태 보존

현재 상태:
- `Stage 1 Graphics Pass 001 — APPROVED`
- `Stage 2 Graphics Pass 002 — INDEPENDENT REVIEW REQUESTED`
- `Stage 3 Graphics Pass 003 — INDEPENDENT REVIEW REQUESTED`

Stage 2/3를 임의로 `APPROVED` 처리하지 않고 독립 검수 대기 상태를 유지한다.

---

# 1. Stage 4 목표

- 이름: **돌의 성소 (Ancient Stone Sanctuary)**
- 핵심 목표:
  > 고대 왕국 이전부터 존재한 거대한 석조 의식 공간으로 만들고, 무거운 골렘의 지면 강타와 Ancient Golem Guardian의 압도적인 질량감이 화면만 보아도 이해되게 한다.
- Stage 1(정연한 성문 외곽), Stage 2(야생 야수숲), Stage 3(붕괴된 성벽)과 완전히 구별되는 거석 신전/의식의 전당 환경 정체성 확립.

---

# 2. 절대 변경 금지 항목

- Player movement, Jump, Dash, Attack damage, Guard, Parry
- GroundSlamGolem AI, HP, damage, Ground slam timing
- AncientGolemGuardian AI, HP, damage, phases, attack timings
- Encounter count, Checkpoint positions, Collision geometry, Route logic, Rewards, Stage progression

---

# 3. 진행 단계

1. **디렉터리 준비**: `ART_REVIEW/graphics-pass-004-stage4/{before,cycle_a,after,profiler,raw}`
2. **Baseline 감사 및 6개 대표 장면 Before 캡처**:
   - `01_stage4_entry.png`
   - `02_stage4_first_golem.png`
   - `03_stage4_mid_sanctuary.png`
   - `04_stage4_route_choice.png`
   - `05_stage4_boss_combat.png`
   - `06_stage4_boss_reward.png`
   - [`BASELINE_REVIEW.md`] 작성
3. **Cycle A**:
   - 4계층 패럴랙스 배경 (Layer 1 심연 보이드/동굴광, Layer 2 거석 원경 기둥, Layer 3 성소 벽면 부조 `stage_four_v1.png`, Layer 4 전경 부서진 열주 프레이밍)
   - 거석 지형 품질 및 대형 석재 블록/룬 홈/접지 기둥 구축
   - 3대 고대 랜드마크 구축 (거대한 룬 석문, 쓰러진 수호자 석상, 고대 수호자 성소)
   - GroundSlamGolem 지면 강타 전조 가독성 (호박색/주황 지면 균열 림, 룬 활성화, 충격 원형)
   - AncientGolemGuardian 보스 아레나 무대감 구축 (의식 제단, 거대 수호자 입상, 거석 열주, 봉인문, 화로)
   - Cycle A 캡처 및 자체 감사 ([`CYCLE_A_REVIEW.md`])
4. **Cycle B**:
   - 시각적 결함 보완 및 거대 스케일감/접지력 극대화
   - 장식용 시안 룬과 전투 위험 호박색/주황 전조 명확한 분리
   - 10대 평가 항목 자체 점수 산정 (평균 ≥ 8.0 목표)
   - Cycle B 최종 캡처 및 감사 ([`CYCLE_B_REVIEW.md`])
5. **성능 계측 및 신규 회귀 테스트**:
   - 4개 구간 (Entry, First Golem, Mid Sanctuary, Boss Combat) 각 600프레임 PC 60 FPS Gate 계측
   - 신규 `stage4_graphics_pass_smoke.gd`, `stage4_render_performance_gate.gd` 작성 및 PASS
   - 기존 13개 회귀 테스트 (Stage 1, Stage 2, Stage 3 포함) 100% PASS (무회귀 입증)
6. **산출물 및 독립 검수 요청**:
   - `FINAL_REVIEW.md`, `PERFORMANCE.md`, `VISUAL_COMPARISON.md` 등 작성
   - 테스트 개수 정확한 표기 (신규 2개 + 기존 회귀 14개 = 총 16개)
   - 상태: `INDEPENDENT REVIEW REQUESTED`
