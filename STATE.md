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
- 현재 상태: **`INDEPENDENT REVIEW REQUESTED` (독립 검수 재요청)**

## QA 상태

최신 확인 가능한 게임 품질 회귀 기록:
- `stage1_r2_blocker_fixes_smoke.gd`: **27/27 PASS**
- `game_and_graphic_quality_smoke.gd`: **60/60 PASS**
- `stage_reward_and_equipment_smoke.gd`: **23/23 PASS**
- `boss1_visual_polish_smoke.gd`: **17/17 PASS**
- `campaign_transition_test.gd`: **PASS**
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
- 본 패스 Android 검증 상태: `ANDROID NOT VERIFIED` (PC 데스크톱 환경 및 헤드리스 엔진 기반 실측)

## 알려진 관리 이슈

1. GitHub 저장소의 default branch는 아직 기존 `task/art-stage-batch-001`일 수 있다. 표준 통합 기준은 `integration`으로 전환했다.
2. 오래된 TASK/설계 문서의 상태 표현이 최신 코드와 충돌할 수 있으므로 코드/최근 커밋 우선.
3. Android 서명/빌드 설정의 로컬 경로 의존성 정리 필요.

## 다음 우선 작업

1. `antigravity/graphics-quality-pass-001-r2` 독립 검수 재심의 진행
2. 독립 검수 승인 확인 후 Stage 2 (야수숲) Pass 002 착수
3. Stage 1→5 실제 플레이 완주 QA 및 난이도/보스 밸런스 점검
4. Android 실기에서 멀티터치, UI 크기, 프레임, 히트 피드백 검증

## 인계 규칙

`AGENTS.md`와 `WORK/HANDOFF_CHECKLIST.md`를 따른다.

ChatGPT Chat은 GitHub에 push된 내용만 볼 수 있으므로, Codex/Antigravity는 인계 전 반드시 **STATE 갱신 + commit + push**를 완료한다.

## 마지막 갱신

- 날짜: **2026-10-02**
- 갱신자: JPStudio Graphics Quality Director (Antigravity) / Pass 001-R2 Blocker 해결 및 독립 검수 재요청


