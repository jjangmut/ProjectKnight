# 작업(Task)

## 기본 정보

- 작업 ID: TASK-CL-009
- 제목: 여러 전투 구간과 Goal을 연결하는 최소 Stage 골격
- 상태: DONE
- 담당 영역 / Owner: 클라이언트 / 클라이언트 리드
- Worker: 현재 Codex 세션(직접 구현)
- Reviewer: Director (최소 Stage 플레이 확인 및 커밋 승인)
- 지시: 2026-09-07 Director의 최소 Stage 골격 구현 요청
- 작업 이력: READY → IN_PROGRESS → REVIEW → DONE

## 목적

기존 전투를 E1~E4 순서로 연결해 생존한 Player가 Goal에 도착하는 흐름을 검증한다.

## 작업 내용 및 범위

- 별도 FirstStage Scene, 평지, 순차 진입, 전투별 출구 차단과 해제.
- 승인 Feature 구성: E1 근접 1, E2 원거리 1, E3 근접 1 + 원거리 1, E4 근접 2 + 원거리 1.
- 모든 필수 Encounter 완료 + Player 생존 + Goal 영역 도착 시에만 CLEARED.
- 같은 physics frame 사망 우선, 종료 고정, 1.5초 후 Scene 재시작 1회.
- HP / 진행 / 목표 텍스트, 카메라 범위, 로컬 실행 도구 및 자동 검증.

## 제외 범위

체크포인트 구현, 모바일 입력, 신규 적/아트, 저장, 범용 Framework, 최종 난도 및 5~10분 플레이타임 조정.
S05는 위치 안내만 제공한다. 후속 체크포인트 작업 전까지 실패 시 시작점부터 재시작한다.
이는 전체 Feature 완료가 아닌 중간 골격이다. 승인된 D2와 모바일 요구를 폐기하지 않는다.

## 참조 자료

- PROJECT.md, PROJECT_RULES.md, STATE.md
- StudioOS/WORKFLOW.md, StudioOS/AGENT_RULES.md
- 승인 FEATURE-GP-001의 E1~E4 구성 및 Director D1
- WORK/TASK-CL-008.md 및 기존 Player/Enemy 인터페이스

## 완료 조건(Acceptance Criteria)

- 각 Encounter는 지정 적만 생성하며 모든 지정 적의 전투 사망 후 출구가 열린다.
- 적 없는 시작 구간, E1~E4, Goal로 연결된다.
- 적 제거만으로 Stage 성공하지 않고 생존 상태의 Goal 도착이 필요하다.
- 동일 프레임 사망 우선, 종료 후 상태 고정, 중복 reload 방지.
- 기존 Actor Script와 PrototypeMain 변경 없음.
- Godot 리소스 로드, Stage 실행, 자동 상태/충돌 검증 통과.

## 결과물(Deliverables)

- CLIENT/Game/scenes/stage/FirstStage.tscn
- CLIENT/Game/scripts/stage/first_stage.gd 및 Godot 생성 UID
- CLIENT/Game/tests/stage_smoke.gd 및 Godot 생성 시 UID
- PLAY_STAGE.bat

## 의존성

기존 Player, TestEnemy, RangedEnemy, EnemyProjectile 및 TASK-CL-008 완료 기준.

## 작업 결과

별도 task/task-cl-009 Worktree에서 구현. 기존 main과 기본 실행 Scene은 유지한다.
현재 세션에서 직접 구현했으며 StudioRuntime Execution Worker/Gate를 실행한 것으로 기록하지 않는다.
외부 Runtime Agent 추가 호출 없음. Director 플레이 확인 후 Task Branch 커밋 승인. main 병합은 별도 승인 대기.

## 검증 및 알려진 문제

- Godot 4.7.2 리소스 import 통과.
- 자동 검증 25개 통과(실제 물리 이동·점프·게이트 충돌 포함), 실패 0.
- FirstStage headless 180 frame 실행: 종료 코드 0, Script/Resource 오류 없음.
- git diff --check 통과. main / StudioRuntime / StudioOS clean 확인.
- 자동 테스트 명령: Godot --headless --path CLIENT/Game --script res://tests/stage_smoke.gd
- Director가 최소 Stage 확인 완료를 보고하고 커밋을 승인했다. 정량적인 완주 시간 및 최종 난도 검증은 별도다.
- 체크포인트 전 단계라 후반 실패도 처음부터 재시작한다.
- 생성 도형 기반 평지 골격이며 승인 설계의 이동 구간 세부 레벨 작업은 남아 있다.

## 검토(Review)

- Director 결과: 최소 Stage 확인 완료, 커밋 승인.
- 자체 기능 검증 25개 통과. 독립 Runtime QA는 호출하지 않았으며 QA PASS로 기록하지 않는다.
