# [ART-REVIEW-001] Graphics Quality Pass 001 독립 검수

- 검수일: 2026-10-02
- 검수자: ChatGPT / Studio QA Review
- 대상 브랜치: `antigravity/graphics-quality-pass-001`
- 대상 커밋: `3e1dd9e6`
- 결론: **REWORK REQUIRED**
- Stage 2 진행 허용: **보류**

## 1. 검수 원칙

이번 검수는 Antigravity의 자기평가 점수와 PASS 선언을 그대로 인정하지 않는다.

그래픽 품질 패스는 다음 세 가지가 모두 충족되어야 한다.

1. 실제 플레이 화면의 명백한 개선
2. 독립 검수자가 개선을 확인 가능
3. 개선 과정과 결과가 반복 검증 구조를 따름

자동 테스트 PASS는 기능 회귀 방지 근거이지 그래픽 품질 PASS 근거가 아니다.

## 2. 확인된 긍정 요소

Pass 001은 단순 문서 작업이 아니라 실제 그래픽 관련 코드와 캡처 산출물을 남겼다.

주요 변경:
- `parallax_stage_backdrop.gd`
- `stage_art.gd`
- `boss_commander.gd`
- `stage_presentation.gd`
- `first_stage.gd`
- Stage 1 Before/After 캡처 5세트
- 자동 회귀 테스트 다수 실행 기록

즉, 실제 개선 시도와 검증 흔적은 존재한다.

## 3. 독립 검수에서 PASS를 보류하는 이유

### R1. 자기평가 점수가 과도하게 높고 독립 근거가 부족
REVIEW.md에는 Character 4.5, Environment 4.6, UI 4.8 등 매우 높은 점수가 기재되어 있다.

하지만 해당 점수는 동일 작업 에이전트가 자기 결과에 부여한 값이다.

따라서 이 수치는:
- 완료 판단의 보조 메모로만 사용
- 독립 검수 점수로 사용 금지
- Stage 2 진입 조건으로 사용 금지

### R2. 단일 Pass만 수행하고 종료
원래 지시는 최소 2회 이상 Before/After 비교를 요구했다.

Pass 001은 한 번의 대규모 수정 후 자체 PASS로 종료되었다.

따라서:
- Stage 1에서 추가 패스 필요
- 최소 Pass 001-R1 또는 Pass 002(Stage 1 Rework) 수행 필요

### R3. 그래픽 품질과 구조적 수정이 섞여 있음
Pass 001에는 인카운터 게이트 물리 충돌 복구 같은 게임 진행 로직 수정도 포함되어 있다.

그래픽 패스에서 게임 진행 로직을 함께 바꾸면:
- 아트 개선과 기능 수정의 효과가 섞임
- 회귀 원인 추적이 어려움
- 비주얼 비교의 순수성이 떨어짐

다음 패스부터는:
- 그래픽/VFX/UI 변경
- 게임 로직/충돌 변경

을 별도 커밋 또는 별도 PR로 분리한다.

### R4. Stage 1만으로 전체 그래픽 캠페인 완료 불가
현재 결과는 Stage 1 Vertical Slice에 한정되어 있다.

Project Knight 전체 그래픽 개선 캠페인의 종료 조건은:
- Stage 1~5
- 5대 보스
- UI/보상/모바일
- 실제 Android 화면

까지 포함한다.

따라서 “작업 완료” 표현은 Stage 1 Pass 001 완료로 한정해야 한다.

### R5. 실제 기기 검증 부재
PC 1280×720 캡처와 Headless 회귀 테스트는 확인되었지만 Android 실기 검증은 아직 없다.

모바일 우선 프로젝트이므로 다음을 확인하기 전 최종 PASS 불가:
- 실제 폰 화면에서 텍스트 크기
- HUD 겹침
- 터치 UI 간섭
- Glow/Bloom 과다
- 저사양/중급 기기 프레임
- 발열 후 프레임 저하

## 4. 독립 판정

### Stage 1 Pass 001
- 코드 변경: PASS
- 회귀 테스트 기록: PASS
- 산출물 존재: PASS
- 독립 시각 검수: **PENDING / REWORK**
- Android 실기: **NOT VERIFIED**
- 반복 개선 루프: **INSUFFICIENT**

### 최종 판정
**REWORK REQUIRED**

Stage 2로 넘어가기 전에 Stage 1을 한 차례 더 재작업한다.

## 5. 다음 게이트

Stage 1 Rework는 아래 조건을 만족해야 한다.

- 동일 5개 캡처 포인트 유지
- 신규 Before/After 세트 생성
- 기존 Pass 001보다 실제 개선이 확인되어야 함
- 자기평가 점수는 참고만 하고 독립 검수용 근거를 별도 작성
- Android 또는 최소 실제 창 실행 영상/스크린샷 검증 추가
- 그래픽과 게임 로직 변경 분리
- 변경 전/후 FPS 또는 프레임 안정성 관찰 기록
- Stage 1 Rework 완료 후에만 Stage 2 진행
