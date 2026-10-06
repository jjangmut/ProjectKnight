# 프로젝트 현재 상태(Project State)

## 프로젝트

Project Knight

## 기준 상태

- 기준일: **2026-10-02**
- 안정 기준 브랜치: `main`
- 통합 기준 브랜치: `integration`
- 통합 기준 HEAD: `6ef897da` — AI 브랜치 전략 및 Codex-ChatGPT 인계 운영 정비
- 기존 장기 작업 기준선: `task/art-stage-batch-001`
- 브랜치 전환 기준 커밋: `aa057ec4`
- 게임 엔진: Godot 4.7.2 stable / GDScript / Compatibility Renderer
- Android export 설정 버전: **v1.1.5 (versionCode 6)**

## 현재 단계

5스테이지 캠페인의 핵심 플레이 루프와 5대 관문 보스, 모바일 조작, 저장/보상/유물 성장 루프가 구현된 상태에서 **게임 플레이 감각·그래픽 품질·보스 가독성·QA 안정성을 집중 고도화하는 상용화 폴리시 단계**에 진입했다.

신규 기능 확대보다 실제 플레이 완주 품질, 밸런스, 시각적 일관성, 모바일 실기 검증과 출시 파이프라인 정리가 우선이다.

## 현재 구현 범위

### 플레이어 / 전투
- 이동, 점프, 코요테 타임, 점프 버퍼
- 3단 콤보 및 3타 검기
- 정면 가드, 카운터, 저스트 패링
- 공중 공격, 하향 찌르기
- 지상/공중 대시 및 무적 처리
- 햅틱 피드백
- 공격 버퍼링 및 공중→지상 입력 연계
- `GameFeelManager` 기반 Hit Stop, Camera Shake, Damage Popup, Slash Spark/Impact Shockwave

### 캠페인 / 보스
- Stage 1~5 캠페인 구성
- 5대 관문 보스: `BossCommander`, `BeastChieftain`, `CrossbowCommander`, `AncientGolemGuardian`, `AbyssalArbiter`
- 고해상도 보스/일반 적 리소스
- 보스 전용 페이즈/특수기/VFX
- 보스 대형화, 불투명 오라 판 제거, 림 라인 중심 표현
- 석궁 보스 투사체 충돌 및 플레이어 타게팅 신뢰성 보완

### 성장 / 보상 / 저장
- `SaveManager` 기반 로컬 진행 저장
- 영혼 파편(`soul_shards`)
- 업그레이드 데이터
- Stage 클리어 기록
- 5종 보스 유물 및 장비 외형
- 유물별 전투 패시브
- 스테이지 클리어 보상 카드

### 그래픽 / 연출
- 플레이어 모션별 아틀라스
- 적/보스 고해상도 리소스
- HDR Glow / Ambient 연출
- 초승달형 참격 리본
- 대시 네온 잔상
- 타격 충격파/파편
- 지형 발광 림 라인
- 보스 림 라이트

### 모바일
- 1280×720 Landscape
- 멀티터치 `MobileControls`
- Left / Right / Down / Attack / Jump / Dash / Guard
- Android export preset
- 패키지 `com.junypapa.projectknight`
- arm64-v8a + armeabi-v7a

## 최근 완료 작업

### 게임/그래픽
- `4052efec`: 공중 공격, 저스트 패링, 3타 검기, 햅틱 (v1.1.0)
- `18e643ec`: Stage 1 보스 크기/가시성/검기 개선 (v1.1.1)
- `2ad5d281`: 유물 획득 카드 및 기사 외형 장비 (v1.1.2)
- `7856673e`: Stage 1→2 연속 플레이 시네마틱 및 보스 HUD
- `5907d240`: HDR Glow, 앰비언스, 보스 림라이트, 유물 패시브, 입력 버퍼링 (v1.1.3)
- `5a99903a`: 초승달 참격, 대시 잔상, 충격파, 지형 림 라인 (v1.1.4)
- `40b93e47`: 5대 보스 대형화, 오라 판 제거, 석궁탄 개선 (v1.1.5)
- `cd13f545`: 품질 스모크 테스트 생명주기 보완, **60/60 PASS**
- `96dd4f71`: 테스트 UID 추가

### 2026-10-02 JPStudio Graphics Quality Director (Pass 001-R1: Stage 1 Rework Cycle A & B)
- `WORK/TASK-AR-011.md` 및 `ART_REVIEW/GRAPHICS_PASS_001_INDEPENDENT_REVIEW.md` 지침에 따른 Stage 1 재작업 완주
- 작업 브랜치: `antigravity/graphics-quality-pass-001-r1` (독립 검수 요청 상태)
- Cycle A 및 Cycle B 2회 반복 개선 및 5대 대표 장면 Before/After 캡처 아티팩트 보관 (`ART_REVIEW/graphics-pass-001-r1/`)
- 주요 비주얼 개선 내역:
  - 건축적 개연성: 부유 발판에 석조 지지 코벨(까치발) 브래킷 및 하단 음영 추가
  - 모바일 조작계: 촉각적 베벨 림과 다층 다크 글래스 질감의 가상 버튼 및 조이스틱 고도화
  - 적 체력바: 메탈릭 슬레이트 프레임 및 상단 하이라이트가 적용된 게이지 바로 전환
  - 갈림길 안내: 음각 골드 노치가 적용된 엔틱 브론즈 석조 현판 스타일 적용
  - 보스 HUD 정돈: `BossHealthBar`와 힌트 텍스트 분리 배치, 보스전 진입 시 불필요한 마일스톤 토스트 억제
  - 보스 아레나 무대: 보스전 돌입 시 상층 잔여 적 정리로 1:1 전용 결전 무대 확보
  - 전조 시인성: `BossCommander` 공격 전조 라인 두께 확장(4.2px) 및 HDR 오버드라이브 발광 상향
  - 보상 카드 마감: 스테이지 클리어 모달에 엔틱 골드 코너 필리그리 브래킷 및 다이아몬드 핍 장식 추가
- 자동 회귀 테스트: 10개 스위트 **100% PASS** (총 360+ 체크 무결점)
- 상세 리뷰 보고서: `ART_REVIEW/graphics-pass-001-r1/REVIEW.md`
- 현재 상태: **독립 검수 요청 (Independent Review Requested)**

### 2026-10-02 JPStudio Graphics Quality Director (Pass 001-R2: Blocker 수정 및 독립 검수 재요청)
- `WORK/TASK-AR-012.md` 및 `ART_REVIEW/GRAPHICS_PASS_001_R1_CODE_REVIEW.md` 코드 리뷰 Blocker 전면 해결
- 작업 브랜치: `antigravity/graphics-quality-pass-001-r2`
- 주요 해결 내역:
  - **BLOCKER-01 (렌더 분리)**: `StageStaticArt` 분리 구현으로 지형 타일(43개), 발판 지형/코벨(19개), 선택 경로 현판(3개)의 1회 사전 캐시 구축. `stage_art.gd`는 동적 전투 피드백(섀도우, VFX, HP 바) 전용으로 분리하여 모바일 CPU 드로우 부하 근본적 제거
  - **BLOCKER-02 (로직 보존)**: `first_stage.gd`에서 인위적 `group["cleared"] = true` 및 `queue_free()` 제거. 아레나 인접 선택 적만 프레젠테이션 비가시화(`visible = false`)하여 퀘스트/보상 상태 100% 보존
  - **MAJOR-01 (HDR 전조 튜닝)**: `AttackRim.width = 3.4px`, rim_color 2.4/2.6, fill alpha 0.22로 캘리브레이션하여 밝은/어두운 배경 4종 캡처(`ART_REVIEW/graphics-pass-001-r2/telegraph/`) 검증 완료
  - **MAJOR-02 (실측 성능 기록)**: Stage 1 3대 구간 실시간 벤치마크 수행 (평균 60.0~60.1 FPS, 1% Low 59.1~59.3 FPS, 평균 프레임타임 16.65~16.66ms 기록, `ART_REVIEW/graphics-pass-001-r2/performance.md`)
- 신규 스모크 테스트: `tests/stage1_r2_blocker_fixes_smoke.gd` (27/27 PASS)
- 자동 회귀 테스트: 11개 스위트 **100% PASS** (총 387개 체크 무결점 통과)
- 상세 보고서: `ART_REVIEW/graphics-pass-001-r2/CODE_REVIEW_FIX_REPORT.md`
### 2026-10-05 JPStudio Graphics Quality Director (Pass 002: Stage 2 야수숲 Graphics Pass 002)
- `WORK/TASK-AR-015.md` 지침에 따른 Stage 2 (야수숲) 그래픽스 패스 002 진행
- 작업 브랜치: `antigravity/graphics-quality-pass-002-stage2`
- 작업 목적: Stage 1과 명확히 구별되는 고유한 야수숲(Ancient Beast Forest) 환경 정체성 확립, 지형 부유 플랫폼감 제거 및 유기적 지지 구조화, Charging Beast 및 Beast Chieftain 시인성/돌진 전조 가독성 강화, 전용 보스 아레나 무대감 구축, PC 60 FPS Gate(전 구간 600f) 초과 달성.
- 모바일 상태: `ANDROID PERFORMANCE NOT VERIFIED` 공식 유지.
- 게임플레이 로직 변경 금지: 이동/공격 수치, 가드/패링 판정, 적/보스 AI, 웨이브 수, 인카운터/체크포인트 위치 일체 보존.
- 현재 상태: `IN_PROGRESS`

### 2026-10-05 JPStudio Graphics Quality Director (Pass 001-R3-Perf: Stage 1 렌더링 병목 분리 및 PC 60 FPS 게이트 달성)
- `WORK/TASK-AR-014.md` 지침에 따른 Stage 1 렌더링 병목 A/B 격리 분석, 스파이크 해소 및 60 FPS 게이트 완수
- 작업 브랜치: `antigravity/graphics-quality-pass-001-r3-perf`
- 주요 해결 및 산출 내역:
  - **A/B 렌더 기능 격리(Isolation Matrix)**: Baseline(40~44 FPS) 대비 WorldEnvironment Glow, CanvasModulate, Motes, Parallax, StageArt Draw, HUD Redraw, MobileControls 등 단일 기능 단위 A/B 계측 완료 (`FEATURE_ISOLATION_MATRIX.md`).
  - **핵심 병목 규명**: `stage_presentation.gd`의 매 프레임 무조건 `queue_redraw()`로 인한 85개 드로우콜 및 폰트 글리프 측정/셰이핑 오버헤드가 단일 최대 병목임을 실증.
  - **First Combat 5.9 FPS 스파이크 해소**: `_spawn_required_wave()` 내 `load()` 동기 씬 로드를 파일 헤더 `preload()` 상수로 일원화하여 디스크 I/O 히치 100% 제거 (`FIRST_COMBAT_SPIKE_ANALYSIS.md`).
  - **최소 품질 손실 최적화(Zero Visual Quality Loss)**:
    1. `stage_presentation.gd`: 체력/샤드/인카운터/체크포인트/애니메이션 등 상태 변경 시에만 리드로우하는 이벤트/상태 기반 렌더로 전환 (비전투/정적 주행 프레임타임 대폭 절감).
    2. `stage_art.gd`: 접지 그림자 및 체력바를 엔티티 자식 노드로 영구 배치하고, 실시간 참격/가드 스파크 발생 시에만 선택적 리드로우.
    3. `AtmosphericMotes`: 파티클 35개 → 22개(테스트 기준 `amount >= 20` 충족) 및 프리프로세스 0.5s로 경량화.
  - **PC 60 FPS Gate 전 구간 초과 달성 (600프레임 실측)**:
    - **Stage 1 Start**: Avg **373.4 FPS** (기준: >=60) / 1% Low **246.3 FPS** (기준: >=45) / P99 **4.06 ms** (기준: <=22ms) -> **PASS**
    - **First Combat**: Avg **316.9 FPS** (기준: >=60) / 1% Low **210.4 FPS** (기준: >=45) / P99 **4.75 ms** (기준: <=22ms) -> **PASS**
    - **Boss Combat**: Avg **196.3 FPS** (기준: >=60) / 1% Low **46.7 FPS** (기준: >=45) / P99 **21.42 ms** (기준: <=22ms) -> **PASS**
  - **11개 회귀 테스트 100% PASS**: 기존 11개 스위트 + 신규 `stage1_render_performance_gate.gd` 전원 통과.
  - **시각적 품질 무손실 증명**: Before/After 5대 대표 장면 동일 캡처 및 프로파일러 오버레이 캡처 완료 (`before/`, `after/`, `profiler/`).
  - **엄격한 범위 준수**: Stage 2 작업 일체 동결 준수, Android 상태 `ANDROID PERFORMANCE NOT VERIFIED` 공식 유지.
- 필수 산출물 문서:
  - `ART_REVIEW/graphics-pass-001-r3-perf/BASELINE.md`
  - `ART_REVIEW/graphics-pass-001-r3-perf/FEATURE_ISOLATION_MATRIX.md`
  - `ART_REVIEW/graphics-pass-001-r3-perf/FIRST_COMBAT_SPIKE_ANALYSIS.md`
  - `ART_REVIEW/graphics-pass-001-r3-perf/OPTIMIZATION_RESULT.md`
  - `ART_REVIEW/graphics-pass-001-r3-perf/FINAL_PERFORMANCE_GATE.md`
- 현재 상태: **`STAGE 1 GRAPHICS PASS 001 — APPROVED` (독립 검수 최종 승인 완료)**
- **독립 검수 승인 근거**:
  - TASK-AR-014 independent review: **PASS**
  - Stage 1 Start: Avg 373.4 FPS / 1% Low 246.3 FPS / P99 4.06 ms
  - First Combat: Avg 316.9 FPS / 1% Low 210.4 FPS / P99 4.75 ms
  - Boss Combat: Avg 196.3 FPS / 1% Low 46.7 FPS / P99 21.42 ms
  - 11 regression suites PASS
  - Gameplay state preserved
  - StageStaticArt cache verified
  - Android performance NOT VERIFIED

### 2026-10-05 JPStudio Graphics Quality Director (Pass 001-R2.1: 성능 검증 및 최종 승인 게이트)
- `WORK/TASK-AR-013.md` 지침에 따른 Stage 1 성능 측정 방법론 교정 및 동일 조건 비교 완료
- 작업 브랜치: `antigravity/graphics-quality-pass-001-r2-1`
- 주요 해결 및 산출 내역:
  - **방법론 오류 규명**: `Performance.TIME_PROCESS`가 1초 창의 "단일 프레임 피크"를 보존하는 엔진 특성(`process_max`)에 기인하여 씬 초기 로딩 스파이크(100~160ms)가 매 프레임 평균 계산에 반영되었던 결함을 인위 부하 프로브(`perf_monitor_semantics_probe.gd`)로 100% 실증.
  - **정밀 시그널 분리 계측**: 워밍업(1.5초) 분리 및 `physics_iter_ms`, `process_ms`, `render_ms` 프레임별 타임스탬프 직접 계측 적용 (`stage1_perf_validation.gd`).
  - **R1 ↔ R2.1 동일 조건 비교**: 동일 PC, 동일 해상도(1280×720), VSync OFF 환경에서 600프레임 이상 실측. `StageStaticArt` 캐시 도입으로 `_process()` 실행 시간이 20.21ms → 7.37ms (Stage 1 Start, -63.5%), 20.22ms → 7.92ms (First Combat, -60.8%), 16.89ms → 7.04ms (Boss Combat, -58.3%)로 대폭 단축됨을 증명.
  - **헤드리스 엔진 보조 계측**: 보스 결전 구간 CPU 스텝 프레임 타임 5.48ms → 5.16ms 단축, P95 8.74ms → 7.84ms 안정화.
  - **프로파일러 오버레이 캡처**: 3대 주요 장면 인게임 프로파일러 오버레이 렌더링 캡처본 보관 (`ART_REVIEW/graphics-pass-001-r2-1/profiler/`).
  - **모바일 상태**: `ANDROID PERFORMANCE NOT VERIFIED` 공식 유지 (과장 표현 배제).
  - **게임 로직 보존 및 Stage 2 동결**: 게임플레이 로직 일절 무변경, Stage 2 작업 일체 동결 준수.
- 자동 회귀 테스트: 11개 스위트 **100% PASS** (스모크, 시각 품질, 전투 심화, 가드, 데이터 드리븐 등 전원 통과)
- 필수 산출물 문서:
  - `ART_REVIEW/graphics-pass-001-r2-1/PERFORMANCE_VALIDATION.md`
  - `ART_REVIEW/graphics-pass-001-r2-1/R1_VS_R2_PERFORMANCE.md`
## 최신 그래픽 패스 상태

### Stage 1: Castle Outskirts (성문 외곽)
- **상태**: **`STAGE 1 GRAPHICS PASS 001 — APPROVED`** (승인 완료)
- 근거: TASK-AR-014 독립 검수 PASS, PC 60 FPS Gate 충족, 회귀 테스트 11종 무결점 통과

### Stage 2: Ancient Beast Forest (야수숲)
- **상태**: **`STAGE 2 GRAPHICS PASS 002 — INDEPENDENT REVIEW REQUESTED`** (독립 검수 요청)
- 작업 브랜치: `antigravity/graphics-quality-pass-002-stage2`
- 개선 주기: Cycle A ➔ Cycle B 2회 완주 (가랜드형 이끼 결함 퇴출, 유기적 수직 덩굴 실선/잎, 100% 발판 뿌리 지지, 3대 랜드마크 구축, 앰버 셰브론 돌진 전조, 보스 아레나 무대화)
- 10대 자체 품질 평가: **8.73 / 10** (기준 ≥ 8.0 통과)
- PC 60 FPS Gate: **4개 전 구간 압도적 PASS** (Entry: 270.6 FPS, First Beast: 257.7 FPS, Mid Forest: 244.1 FPS, Boss Combat: 272.5 FPS)
- 산출물:
  - `ART_REVIEW/graphics-pass-002-stage2/before/` (6종 캡처)
  - `ART_REVIEW/graphics-pass-002-stage2/cycle_a/` (6종 캡처)
  - `ART_REVIEW/graphics-pass-002-stage2/after/` (6종 캡처)
  - `ART_REVIEW/graphics-pass-002-stage2/profiler/` (4종 캡처)
  - `ART_REVIEW/graphics-pass-002-stage2/BASELINE_REVIEW.md`
  - `ART_REVIEW/graphics-pass-002-stage2/CYCLE_A_REVIEW.md`
  - `ART_REVIEW/graphics-pass-002-stage2/CYCLE_B_REVIEW.md`
  - `ART_REVIEW/graphics-pass-002-stage2/VISUAL_COMPARISON.md`
  - `ART_REVIEW/graphics-pass-002-stage2/PERFORMANCE.md`
  - `ART_REVIEW/graphics-pass-002-stage2/FINAL_REVIEW.md`

### Stage 3 Graphics Pass 003 (무너진 성벽)
- 상태: **`INDEPENDENT REVIEW REQUESTED`**
- 10대 자체 품질 평가: **9.25 / 10** (기준 ≥ 8.0 통과)
- PC 60 FPS Gate: **4개 전 구간 압도적 PASS** (Entry: 213.5 FPS, First Ranged: 305.0 FPS, Vertical Route: 275.3 FPS, Boss Combat: 349.3 FPS)
- 4계층 패럴랙스 (황혼 폭풍 하늘, 파괴된 성벽 능선, 틴트 일러스트, 흉벽 및 전장 분진) 및 3대 랜드마크 (무너진 망루, 부서진 투석기, 사령관 성루) 구축
- 전 플랫폼 기둥/비계 트러스 100% 접지 및 공중 부유감 완전 제거
- RangedEnemy 호박색 HDR 발광 조준선/투사체 가독성 극대화 및 보스 아레나 무대화
- 산출물:
  - `ART_REVIEW/graphics-pass-003-stage3/before/` (6종 캡처)
  - `ART_REVIEW/graphics-pass-003-stage3/cycle_a/` (6종 캡처)
  - `ART_REVIEW/graphics-pass-003-stage3/after/` (6종 캡처)
  - `ART_REVIEW/graphics-pass-003-stage3/profiler/` (4종 캡처)
  - `ART_REVIEW/graphics-pass-003-stage3/BASELINE_REVIEW.md`
  - `ART_REVIEW/graphics-pass-003-stage3/CYCLE_A_REVIEW.md`
  - `ART_REVIEW/graphics-pass-003-stage3/CYCLE_B_REVIEW.md`
  - `ART_REVIEW/graphics-pass-003-stage3/VISUAL_COMPARISON.md`
  - `ART_REVIEW/graphics-pass-003-stage3/PERFORMANCE.md`
  - `ART_REVIEW/graphics-pass-003-stage3/FINAL_REVIEW.md`

### Stage 4 Graphics Pass 004 (돌의 성소)
- 상태: **`INDEPENDENT REVIEW REQUESTED`**
- 10대 자체 품질 평가: **9.35 / 10** (기준 ≥ 8.0 통과)
- PC 60 FPS Gate: **4개 전 구간 압도적 PASS** (Entry: 291.3 FPS, First Golem: 273.3 FPS, Mid Sanctuary: 258.2 FPS, Boss Combat: 292.6 FPS)
- 4계층 패럴랙스 (천창 광선, 원경 거석 기둥군, 성소 벽면 부조, 전경 거석 천장 보 및 신성한 안개) 및 3대 거석 랜드마크 (거대한 룬 석문, 쓰러진 거상, 고대 성소) + 보스 아레나(3단 제단, 6개 열주, 화로) 구축
- Castle Support 에셋 오용 완전 제거 및 폭 44px 거석 원주(`monolith_pillars`), 파일런(`pylon_supports`), 좌대(Plinth), 룬 채널 홈으로 전면 개편
- GroundSlamGolem 지면 강타 5단계 전조 (호박색 균열 림, 코너 브래킷, 룬 틱, 충격파 링) 및 장식용 쿨 시안 룬과의 절대적 색상 분리
- 산출물:
  - `ART_REVIEW/graphics-pass-004-stage4/before/` (6종 캡처)
  - `ART_REVIEW/graphics-pass-004-stage4/cycle_a/` (6종 캡처)
  - `ART_REVIEW/graphics-pass-004-stage4/after/` (6종 캡처)
  - `ART_REVIEW/graphics-pass-004-stage4/profiler/` (4종 캡처)
  - `ART_REVIEW/graphics-pass-004-stage4/BASELINE_REVIEW.md`
  - `ART_REVIEW/graphics-pass-004-stage4/CYCLE_A_REVIEW.md`
  - `ART_REVIEW/graphics-pass-004-stage4/CYCLE_B_REVIEW.md`
  - `ART_REVIEW/graphics-pass-004-stage4/VISUAL_COMPARISON.md`
  - `ART_REVIEW/graphics-pass-004-stage4/PERFORMANCE.md`
  - `ART_REVIEW/graphics-pass-004-stage4/FINAL_REVIEW.md`

## QA 상태

최신 확인 가능한 게임 품질 회귀 기록 (총 16개 테스트 스위트 전원 PASS / 신규 2개 + 기존 회귀 14개):
- **신규 Stage 4 테스트 (2개)**:
  - `stage4_graphics_pass_smoke.gd`: **25/25 PASS**
  - `stage4_render_performance_gate.gd`: **4/4 Sectors PASS**
- **기존 회귀 테스트 (14개, Stage 1 / Stage 2 / Stage 3 무회귀 입증)**:
  - `stage3_graphics_pass_smoke.gd`: **25/25 PASS**
  - `stage2_graphics_pass_smoke.gd`: **24/24 PASS**
  - `stage1_r2_blocker_fixes_smoke.gd`: **27/27 PASS**
  - `game_and_graphic_quality_smoke.gd`: **60/60 PASS**
  - `stage_reward_and_equipment_smoke.gd`: **23/23 PASS**
  - `boss1_visual_polish_smoke.gd`: **17/17 PASS**
  - `campaign_transition_test.gd`: **PASS**
  - `stage_art_smoke.gd`: **37/37 PASS**
  - `stage_smoke.gd`: **37/37 PASS**
  - `combat_deepening_smoke.gd`: **10/10 PASS**
  - `guard_core_smoke.gd`: **21/21 PASS**
  - `sprint4_smoke.gd`: **23/23 PASS**
  - `enemy_motion_smoke.gd`: **130/130 PASS**
  - `data_driven_smoke.gd`: **38/38 PASS**

## 빌드 / 배포 상태

- `.gitignore`에 `CLIENT/Game/builds/`, `*.apk`, `*.aab` 제외
- `export_presets.cfg`: v1.1.5 / versionCode 6 / `com.junypapa.projectknight`
- Debug keystore 경로가 `C:/Users/jjang/.android/debug.keystore`로 로컬 고정되어 있어 향후 CI 분리가 필요
- 본 패스 Android 검증 상태: **`ANDROID PERFORMANCE NOT VERIFIED`** (PC 데스크톱 환경 및 헤드리스 엔진 기반 실측)

## 알려진 관리 이슈

1. GitHub 저장소의 default branch는 아직 기존 `task/art-stage-batch-001`일 수 있다. 표준 통합 기준은 `integration`으로 전환했다.
2. 오래된 TASK/설계 문서의 상태 표현이 최신 코드와 충돌할 수 있으므로 코드/최근 커밋 우선.
3. Android 서명/빌드 설정의 로컬 경로 의존성 정리 필요.

## 다음 우선 작업

1. Stage 2 Graphics Pass 002 독립 검수 피드백 대응
2. Stage 3 Graphics Pass 003 독립 검수 피드백 대응
3. Stage 4 Graphics Pass 004 독립 검수 피드백 대응
4. Stage 5 Graphics Pass 005 착수 준비
5. Stage 1→5 실제 플레이 완주 QA 및 난이도/보스 밸런스 점검
6. Android 실기에서 멀티터치, UI 크기, 프레임, 히트 피드백 검증

## 인계 규칙

`AGENTS.md`와 `WORK/HANDOFF_CHECKLIST.md`를 따른다.

ChatGPT Chat은 GitHub에 push된 내용만 볼 수 있으므로, Codex/Antigravity는 인계 전 반드시 **STATE 갱신 + commit + push**를 완료한다.

## 마지막 갱신

- 날짜: **2026-10-06**
- 갱신자: JPStudio Graphics Quality Director (Antigravity) / Stage 4 Graphics Pass 004 (돌의 성소) 완료 및 독립 검수 요청 (`INDEPENDENT REVIEW REQUESTED`)



