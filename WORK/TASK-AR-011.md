# [TASK-AR-011] Stage 1 Graphics Pass 001 재작업 및 독립 검수 게이트 통과

- 상태: IN_REVIEW (독립 검수 요청)
- 담당: Antigravity / JPStudio Graphics Quality Director
- 우선순위: P0
- 작성일: 2026-10-02
- 선행 작업: `antigravity/graphics-quality-pass-001`
- 검수 문서: `ART_REVIEW/GRAPHICS_PASS_001_INDEPENDENT_REVIEW.md`
- 완료 보고: `ART_REVIEW/graphics-pass-001-r1/REVIEW.md`
- 목표: Stage 1을 한 번 더 재작업해 독립 검수 가능한 수준으로 만든 뒤에만 Stage 2로 이동

## 1. 현재 상태

Pass 001-R1 Cycle A 및 Cycle B 2회 반복 개선 완료 후 독립 검수 요청 상태.

```text
Stage 1 Pass 001
→ Self Review PASS
→ Independent Review
→ REWORK REQUIRED
→ Pass 001-R1 Cycle A & Cycle B 완주
→ 독립 검수 요청 (IN_REVIEW)
```

Antigravity는 Stage 2 작업을 시작하지 말고 Stage 1을 먼저 재작업한다.

## 2. 필수 작업 브랜치

`antigravity/graphics-quality-pass-001-r1`

기준:
- `antigravity/graphics-quality-pass-001` 최신 커밋에서 분기

## 3. 재작업 목표

### P0-1. 화면 전체의 프로토타입 느낌 추가 제거
특히 다음 흔적을 다시 찾는다.

- 단색/평면 폴리곤
- 반복되는 기계적 구조
- 텍스처와 절차적 도형의 스타일 불일치
- 캐릭터와 배경의 명암/채도 충돌
- 지형 경계선의 인공적 반복
- HUD가 개발툴처럼 보이는 부분

### P0-2. 플레이어 시각적 품질
플레이어는 전체 화면에서 가장 중요한 시각적 기준점이다.

확인:
- 실루엣
- 장비와 본체의 스타일 일치
- 달리기/점프/공격 자세
- 공격 프레임 간 연결
- 지면 접촉
- 그림자 방향/크기
- Glow 과다 여부

### P0-3. BossCommander 품질
더 이상 크기 확대를 사용하지 않는다.

개선 방향:
- 실루엣 정보량
- 갑옷 재질 구분
- 방패/무기 존재감
- 공격 준비 자세
- 공격 전조와 실제 공격 범위의 일치
- 바닥 룬 오라가 캐릭터를 가리지 않도록 조정
- 사망 연출

### P0-4. 배경 깊이
Stage 1은 다음 레이어가 읽혀야 한다.

1. 전경 장식
2. 플레이 지형
3. 중경 구조물
4. 원경 성채/산/하늘

카메라 이동 시 레이어 속도 차이가 체감되어야 한다.

### P0-5. UI
다음 화면을 다시 점검한다.

- 일반 플레이 HUD
- 보스 HUD
- 보상 카드
- Stage Clear
- 모바일 컨트롤

UI는:
- 크기
- 대비
- 정렬
- 여백
- 계층

기준으로 다시 정리한다.

## 4. 반복 검증 방식

이번에는 최소 2 Cycle을 강제한다.

### Cycle A
1. Pass 001 기준 캡처
2. 문제점 5개 이상 작성
3. 수정
4. 자동 회귀 테스트
5. 동일 장면 캡처
6. 자체 검수

### Cycle B
1. Cycle A 결과 다시 검토
2. 남은 문제점 3개 이상 작성
3. 추가 수정
4. 자동 회귀 테스트
5. 동일 장면 캡처
6. 최종 비교

Cycle B 없이 완료 처리 금지.

## 5. 캡처 장면

동일한 장면을 유지한다.

1. Stage 1 Start
2. First Combat
3. Route Choice
4. Boss Combat
5. Boss Defeat / Reward

각 장면마다:
- Pass 001
- Rework Cycle A
- Rework Cycle B

비교 가능하도록 저장한다.

## 6. 평가 방식

이번 패스부터 자기 점수만으로 PASS 금지.

각 항목을:

- 개선됨
- 변화 미미
- 악화됨

중 하나로 판정한다.

항목:
- Character
- Environment
- Lighting
- Readability
- VFX
- UI

숫자 점수는 부가 정보일 뿐이다.

## 7. 성능 검증

가능하면 실제 실행에서:

- 평균 FPS
- 최저 FPS
- Boss 전투 최저 FPS

기록.

불가능하면 최소:
- 노드 수 증가
- CPUParticles 증가
- Line2D/Polygon2D 증가
- 오버드로우 위험
- 대형 투명 레이어

를 점검한다.

## 8. Android 검증

가능하면 Android APK 빌드 후 Stage 1을 실제 기기에서 실행한다.

최소 확인:
- HUD 가독성
- 터치 UI 간섭
- 캐릭터 식별성
- 보스 전조
- 보상 카드
- 프레임 안정성

Android 실행이 불가능하면 완료 보고에 반드시:
`ANDROID NOT VERIFIED`

를 남긴다.

## 9. 변경 분리

게임 로직 수정이 필요한 경우:
- 그래픽 커밋과 분리
- 이유 기록
- 별도 회귀 테스트

그래픽 패스 커밋에 전투 난이도, HP, AI, 진행 조건 변경을 섞지 않는다.

## 10. 완료 조건

다음 조건을 모두 충족해야 완료.

- Cycle A 완료
- Cycle B 완료
- 동일 장면 Before/After 존재
- Pass 001 대비 개선 항목 명확
- 자동 테스트 PASS
- 성능 관찰 기록
- Android 검증 여부 명시
- 독립 검수 요청 문서 작성
- STATE.md 갱신
- commit + push
- PR 생성

## 11. 완료 보고 문구 제한

다음 표현을 근거 없이 사용하지 않는다.

- AAA
- 상용 수준 확정
- 완벽
- 100% 그래픽 완료
- 최종 퀄리티

완료 보고는 관찰 사실만 작성한다.

## 12. 다음 단계

Stage 1 Rework가 독립 검수 PASS를 받은 뒤에만:

`Stage 2 Graphics Pass 002`

로 이동한다.
