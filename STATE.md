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

### 2026-10-02 AI 인계/브랜치 운영 정비
- `main`, `integration` 생성
- 첫 ChatGPT 전용 작업 브랜치 `chatgpt/handoff-governance` 생성
- `AGENTS.md`에 표준 브랜치 정책, CODEX ↔ ChatGPT 인계 규칙, 작업 종료 강제 체크리스트 추가
- `WORK/DEC-014.md`에 AI 다중 작업 환경 브랜치 정책 결정 기록
- `WORK/HANDOFF_CHECKLIST.md`에 공통 인계 체크리스트 추가
- PR #1 `chatgpt/handoff-governance → integration` **병합 완료**
- 통합 커밋: `6ef897da`

## QA 상태

최신 확인 가능한 게임 품질 회귀 기록:
- `game_and_graphic_quality_smoke.gd`: **60/60 PASS** (`cd13f545`)

이번 브랜치 운영/문서 정비는 GitHub 기반 작업으로, Godot 로컬 실행이나 Android APK 빌드는 **미실행**이다. 게임 로직은 변경하지 않았다.

## 빌드 / 배포 상태

- `.gitignore`에 `CLIENT/Game/builds/`, `*.apk`, `*.aab` 제외
- `export_presets.cfg`: v1.1.5 / versionCode 6 / `com.junypapa.projectknight`
- Debug keystore 경로가 `C:/Users/jjang/.android/debug.keystore`로 로컬 고정되어 있어 향후 CI 분리가 필요

## 알려진 관리 이슈

1. GitHub 저장소의 default branch는 아직 기존 `task/art-stage-batch-001`일 수 있다. 표준 통합 기준은 `integration`으로 전환했다.
2. 오래된 TASK/설계 문서의 상태 표현이 최신 코드와 충돌할 수 있으므로 코드/최근 커밋 우선.
3. Android 서명/빌드 설정의 로컬 경로 의존성 정리 필요.

## 다음 우선 작업

1. Codex/Antigravity 로컬 환경을 `integration` 기준 전용 브랜치 방식으로 전환
2. Stage 1→5 실제 플레이 완주 QA 및 난이도/보스 밸런스 점검
3. Android 실기에서 멀티터치, UI 크기, 프레임, 히트 피드백 검증
4. 플레이어/적/보스/배경 아트 스타일 일관성 검토
5. 자동 QA가 놓치는 실제 조작감·가독성·카메라·충돌 문제 목록화
6. CI/Android 서명·빌드 파이프라인 정리

## 인계 규칙

`AGENTS.md`와 `WORK/HANDOFF_CHECKLIST.md`를 따른다.

ChatGPT Chat은 GitHub에 push된 내용만 볼 수 있으므로, Codex/Antigravity는 인계 전 반드시 **STATE 갱신 + commit + push**를 완료한다.

## 마지막 갱신

- 날짜: **2026-10-02**
- 갱신자: ChatGPT / 브랜치·인계 운영 정비 완료
