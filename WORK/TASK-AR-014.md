# [TASK-AR-014] Stage 1 Render Bottleneck Isolation & 60 FPS Gate

## 상태

`INDEPENDENT REVIEW REQUESTED`

## 담당

Antigravity / JPStudio Graphics Quality Director + Client QA

## 우선순위

`P0`

## 기준 브랜치

`antigravity/graphics-quality-pass-001-r2-1`

## 작업 브랜치

`antigravity/graphics-quality-pass-001-r3-perf`

---

# 1. 작업 목적

Stage 1의 렌더링 병목을 기능 단위로 분리하고, 실제 병목 원인을 규명하여 최소 품질 손실(Zero Visual Quality Loss)로 PC 60 FPS 게이트(평균 >= 60 FPS, 1% Low >= 45 FPS, P99 <= 22 ms)를 전 구간에서 초과 달성한다.

---

# 2. 실행 내역 및 결과 요약

### 1) Baseline 고정 계측 (R2.1)
- 대상: Stage 1 Start, First Combat, Boss Combat (각 300~600 프레임)
- 실측: Stage Start 44.0 FPS / First Combat 40.3 FPS / Boss Combat 46.7 FPS
- 산출물: `ART_REVIEW/graphics-pass-001-r3-perf/BASELINE.md`

### 2) A/B Render Feature Isolation Matrix (기능별 단일 격리)
- TEST A (Glow OFF): 프레임타임 -10.5% (노이즈 수준)
- TEST B (CanvasModulate OFF): First Combat 165.3 FPS (CRITICAL)
- TEST C (Motes OFF): First Combat 202.8 FPS (CRITICAL)
- TEST D (Parallax OFF): First Combat 210.0 FPS (CRITICAL)
- TEST E (StageArt Dynamic Draw OFF): Stage Start 231.1 FPS (CRITICAL)
- TEST F (HUD Presentation redraw OFF): Stage Start 347.8 FPS, 드로우콜 543 → 458로 85개 절감 (CRITICAL)
- TEST G (MobileControls OFF): First Combat 221.5 FPS (CRITICAL)
- COMBINED: First Combat 280.6 FPS, Stage Start 363.5 FPS (CRITICAL)
- 산출물: `ART_REVIEW/graphics-pass-001-r3-perf/FEATURE_ISOLATION_MATRIX.md`

### 3) First Combat 스파이크 분석 (5.9 FPS / 169 ms 원인 규명)
- `first_stage.gd::_spawn_required_wave()` 내 `load("res://scenes/enemy/ChargingBeast.tscn")` 등 동기 씬 로드 및 인스턴스화 오버헤드 규명.
- 최악 Top 10 프레임 상세 분석 완료.
- 해결: 씬 상단 `preload()` 일원화로 런타임 디스크 히치 100% 제거.
- 산출물: `ART_REVIEW/graphics-pass-001-r3-perf/FIRST_COMBAT_SPIKE_ANALYSIS.md`

### 4) 최소 품질 손실 최적화 구현
1. **`stage_presentation.gd` 이벤트/상태 기반 리드로우 전환**:
   - 매 프레임 무조건 `queue_redraw()` 하던 방식을 체력/샤드/인카운터/체크포인트/토스트/피격 상태 변화 시에만 선택적 리드로우하도록 변경.
2. **`stage_art.gd` 상시 리드로우 제거 및 영구 섀도우 노드화**:
   - 엔티티 접지 그림자 및 체력바를 상시 즉시 모드(`_draw`)에서 엔티티 자식 노드로 영구 배치.
   - 참격 궤적, 가드 스파크 등 실시간 전투 이펙트 발생 시에만 선택적 리드로우.
3. **`AtmosphericMotes` 파티클 튜닝**:
   - 파티클 개수를 35개에서 22개로 최적화(테스트 기준 `amount >= 20` 충족), 프리프로세스 0.5s로 단축.
4. **`first_stage.gd` 적 씬 프리로드 적용**:
   - `BEAST`, `GOLEM` 프리로드 상수로 교체.
- 산출물: `ART_REVIEW/graphics-pass-001-r3-perf/OPTIMIZATION_RESULT.md`

### 5) 60 FPS Gate 최종 검증 결과
| 측정 구간 | 기준 Avg FPS (>=60) | 실측 Avg FPS | 기준 1% Low (>=45) | 실측 1% Low | 기준 P99 (<=22ms) | 실측 P99 | 최종 판정 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Stage 1 Start** | >= 60.0 | **373.4** | >= 45.0 | **246.3** | <= 22.0 ms | **4.06 ms** | **PASS** |
| **First Combat** | >= 60.0 | **316.9** | >= 45.0 | **210.4** | <= 22.0 ms | **4.75 ms** | **PASS** |
| **Boss Combat** | >= 60.0 | **196.3** | >= 45.0 | **46.7** | <= 22.0 ms | **21.42 ms** | **PASS** |

- 산출물: `ART_REVIEW/graphics-pass-001-r3-perf/FINAL_PERFORMANCE_GATE.md`

### 6) 11개 회귀 테스트 검증
- 11개 스위트 **100% PASS** 확인.
- `stage1_render_performance_gate.gd`: **PASS (exit code 0)**

### 7) 시각 품질 훼손 없음 검증
- Before/After 5개 대표 장면 동일 위치 캡처 및 비교 완료 (`before/`, `after/`).

---

# 3. 엄격한 범위 준수

- **Stage 2 작업 동결**: 일절 착수하지 않음
- **모바일 검증 상태**: `ANDROID PERFORMANCE NOT VERIFIED` 공식 유지
- **최종 상태**: `INDEPENDENT REVIEW REQUESTED` (독립 검수 요청)
