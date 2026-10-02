# 프로젝트 현재 상태(Project State)

## 프로젝트

Project Knight

## 기준 상태

- 기준일: **2026-10-02**
- 기준 브랜치: `task/art-stage-batch-001`
- 기준 HEAD: `96dd4f71` — `chore(tests): test script uid 파일 추가`
- 게임 엔진: Godot 4.7.2 stable / GDScript / Compatibility Renderer
- Android export 설정 버전: **v1.1.5 (versionCode 6)**

## 현재 단계

5스테이지 캠페인의 핵심 플레이 루프와 5대 관문 보스, 모바일 조작, 저장/보상/유물 성장 루프가 구현된 상태에서 **게임 플레이 감각·그래픽 품질·보스 가독성·QA 안정성을 집중 고도화하는 상용화 폴리시 단계**에 진입했다.

현재는 신규 시스템을 계속 확장하기보다 실제 플레이 완주 품질, 밸런스, 시각적 일관성, 모바일 실기 검증과 출시 파이프라인 정리가 우선이다.

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
- 5대 관문 보스:
  - `BossCommander`
  - `BeastChieftain`
  - `CrossbowCommander`
  - `AncientGolemGuardian`
  - `AbyssalArbiter`
- 고해상도 보스/일반 적 리소스 적용
- 보스 전용 페이즈/특수기/VFX
- 최근 보스 3배급 대형화, 불투명 오라 판 제거, 림 라인 중심 표현으로 개선
- 석궁 보스 투사체 충돌 및 플레이어 타게팅 신뢰성 보완

### 성장 / 보상 / 저장
- `SaveManager` 기반 로컬 진행 저장
- `soul_shards` 영혼 파편 재화
- 업그레이드 데이터
- Stage 클리어 기록
- 5종 보스 유물 및 장비 외형
- 유물별 전투 패시브 연동
- 스테이지 클리어 보상 카드/장비 갱신

### 그래픽 / 연출
- 플레이어 모션별 아틀라스 리소스
- 적/보스 고해상도 리소스
- HDR Glow / Ambient 연출
- 초승달형 참격 리본
- 대시 네온 고스트 잔상
- 타격 충격파 링 및 파편
- 지형 상단 발광 림 라인
- 보스 림 라이트 및 투명 오라 표현

### 모바일
- 가로 Landscape 기준 1280×720
- 멀티터치 `MobileControls`
- Left / Right / Down / Attack / Jump / Dash / Guard
- PC 마우스 터치 에뮬레이션
- Android export preset
- 패키지: `com.junypapa.projectknight`
- ABI: arm64-v8a + armeabi-v7a

## 2026-10-01 ~ 2026-10-02 최근 완료 작업

- `4052efec`: 공중 공격, 저스트 패링, 3타 검기 방출, 햅틱 피드백 구현 (v1.1.0)
- `18e643ec`: Stage 1 보스 크기 확대 및 검기/가시성 개선 (v1.1.1)
- `2ad5d281`: 스테이지 클리어 유물 획득 카드 및 기사 외형 장비 시스템 구현 (v1.1.2)
- `7856673e`: Stage 1→2 연속 플레이 시네마틱 디렉터 및 보스 HUD 연동
- `5907d240`: WorldEnvironment HDR Glow, 앰비언스, 5대 보스 림라이트, 유물 5종 패시브, 입력 버퍼링, 검기 지형 충돌 고도화 (v1.1.3)
- `5a99903a`: 플레이어 초승달 참격 리본, 대시 네온 잔상, 타격 충격파 링, 지형 발광 림 라인 고도화 (v1.1.4)
- `40b93e47`: 5대 보스 대형화, 불투명 오라 판 제거, 석궁탄 플레이어 타게팅/충돌 개선 (v1.1.5)
- `cd13f545`: `game_and_graphic_quality_smoke.gd` 테스트 생명주기 및 보스 물리 비활성화 보완, **60/60 PASS**
- `96dd4f71`: 테스트 스크립트 UID 파일 추가

## QA 상태

자동화 테스트 스위트가 전투, 보스, 캠페인, 체크포인트, 모바일 컨트롤, 스테이지 전환/페이싱, 플레이어 모션, 애니메이션 동기화, 그래픽 품질, 보상/장비, 상용 루프 등으로 세분화되어 있다.

최신 확인 가능한 품질 회귀 기록:
- `game_and_graphic_quality_smoke.gd`: **60/60 PASS** (`cd13f545`)

주의:
- 자동화 PASS는 실제 기기 플레이 품질을 대체하지 않는다.
- GitHub Chat 환경에서는 로컬 Godot 실행 및 Android APK 설치 검증을 수행할 수 없다.
- 실제 플레이 완주, 터치 감각, 프레임 안정성, 화면 가독성은 Android 실기 검증이 계속 필요하다.

## 빌드 / 배포 상태

- `.gitignore`에 `CLIENT/Game/builds/`, `*.apk`, `*.aab`가 제외되어 있어 APK 바이너리는 저장소에서 직접 검증할 수 없다.
- `export_presets.cfg` 현재 설정:
  - `version/name="1.1.5"`
  - `version/code=6`
  - `package/unique_name="com.junypapa.projectknight"`
- Debug keystore 경로가 `C:/Users/jjang/.android/debug.keystore`로 로컬 환경에 고정되어 있다. 향후 CI/다른 PC 빌드 시 환경 분리가 필요하다.

## 알려진 관리 이슈

1. `STATE.md`와 `PROJECT.md`가 한동안 실제 구현보다 뒤처져 있었으며 2026-10-02 기준으로 갱신함.
2. 현재 원격에서 확인되는 주 브랜치는 `task/art-stage-batch-001`이며 이 브랜치가 통합 기준선 역할을 하고 있다.
3. 오래된 TASK/설계 문서의 “미구현” 또는 “REVIEW” 표현이 실제 최신 코드와 충돌할 수 있으므로 코드/최신 커밋을 우선한다.
4. Android 서명/빌드 설정의 로컬 경로 의존성을 향후 정리해야 한다.

## 다음 우선 작업

1. Stage 1→5 실제 플레이 완주 QA 및 난이도/보스 패턴 밸런스 점검
2. 모바일 Android 실기에서 멀티터치, UI 크기, 프레임, 히트 피드백 검증
3. 플레이어/적/보스/배경 아트 스타일 일관성 검토
4. 자동 QA가 놓치는 실제 조작감·가독성·카메라·충돌 문제 목록화
5. 출시용 브랜치/CI/Android 서명·빌드 파이프라인 정리
6. 신규 기능 추가는 실제 플레이 QA에서 필요성이 확인된 경우에만 진행

## 인계 규칙

Codex, Antigravity, ChatGPT Chat 간 작업 전환은 `AGENTS.md`의 **CODEX ↔ ChatGPT 인계 규칙**을 따른다.

특히 ChatGPT Chat은 GitHub에 push된 내용만 볼 수 있으므로, 로컬 작업 에이전트는 인계 전 반드시 커밋 및 push를 완료한다.

## 마지막 갱신

- 날짜: **2026-10-02**
- 갱신자: ChatGPT / GitHub 인계 정비
