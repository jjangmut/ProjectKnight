# 작업(Task)

상태와 검토 절차는 StudioOS의 `WORKFLOW.md`를 따른다.

## 기본 정보

작업 ID: TASK-CL-008
제목: 첫 전투 세션 종료 및 빠른 재시작 프로토타입
상태: DONE
담당 영역: 클라이언트(Client)
책임자(Owner): Client Lead
작업자(Worker): Client
협의자(Consulted): Planning Lead
검토자(Reviewer): Review/QA

## 목적

현재 전투 Sandbox에 성공·실패 판정과 빠른 Scene 재시작을 추가하여 PLAYING → CLEARED 또는 FAILED → 최소 상태 표시 → 짧은 지연 → 같은 전투 재시작의 최소 게임 루프를 완성한다.

## 작업 내용

- Player 사망을 FAILED로 판정한다.
- 현재 배치된 TestEnemy와 RangedEnemy가 모두 제거되고 Player가 생존한 경우에만 CLEARED로 판정한다.
- 같은 physics frame에 Player 사망과 마지막 Enemy 제거가 함께 발생하면 이벤트와 Signal 처리 순서와 무관하게 FAILED를 우선한다.
- PLAYING에서 확정된 CLEARED 또는 FAILED 상태는 늦은 Projectile Hit나 Enemy 제거로 변경하지 않는다.
- 성공·실패 최소 상태 텍스트를 표시하고 짧은 지연 후 현재 전투 Scene을 한 번만 재시작한다.
- Scene 전체 reload로 Player, Enemy, Projectile과 세션 상태를 초기화하며 별도 Reset 시스템을 만들지 않는다.
- 중복 종료 판정, 중복 Timer와 중복 reload를 차단한다.

## 작업 범위

- Player 사망을 FAILED로 판정한다.
- 현재 배치된 TestEnemy와 RangedEnemy가 모두 제거되고 Player가 생존한 경우에만 CLEARED로 판정한다.
- 같은 physics frame에 Player 사망과 마지막 Enemy 제거가 함께 발생하면 이벤트와 Signal 처리 순서와 무관하게 FAILED를 우선한다.
- PLAYING에서 확정된 CLEARED 또는 FAILED 상태는 늦은 Projectile Hit나 Enemy 제거로 변경하지 않는다.
- 성공·실패 최소 상태 텍스트를 표시하고 짧은 지연 후 현재 전투 Scene을 한 번만 재시작한다.
- Scene 전체 reload로 Player, Enemy, Projectile과 세션 상태를 초기화하며 별도 Reset 시스템을 만들지 않는다.
- 중복 종료 판정, 중복 Timer와 중복 reload를 차단한다.

## 제외 범위

- 체크포인트
- 다중 전투 구간과 스테이지 확장
- 결과 화면
- 새로운 Enemy
- 모바일 UI
- 저장
- 범용 Game State Framework
- Singleton
- Player, Enemy, Projectile 개별 Reset 시스템
- 기존 Player, TestEnemy, RangedEnemy, EnemyProjectile Script 변경

## 참조 자료

- `PROJECT.md`
- `PROJECT_RULES.md`
- `STATE.md`

## 완료 조건(Acceptance Criteria)

- 초기 세션 상태는 PLAYING이다.
- Player 사망 시 FAILED가 정확히 한 번 확정된다.
- Player가 생존한 상태에서 TestEnemy와 RangedEnemy가 모두 제거되면 CLEARED가 정확히 한 번 확정된다.
- 같은 physics frame에 Player 사망과 마지막 Enemy 제거가 발생하면 호출 순서와 무관하게 FAILED가 된다.
- CLEARED 이후 늦은 Projectile Hit가 도착해도 CLEARED를 유지한다.
- FAILED 이후 마지막 Enemy가 제거되어도 FAILED를 유지한다.
- 종료 상태는 한 번만 확정되고 Timer와 Scene reload도 한 번만 실행된다.
- 성공과 실패를 최소 상태 텍스트로 구분할 수 있다.
- 종료 후 1~2초 안에 현재 Scene이 다시 시작된다.
- Scene 재시작 후 Player는 HP 3과 생존 상태이고 두 Enemy는 다시 존재하며 이전 Projectile과 세션 상태가 남지 않는다.
- 기존 이동·점프·공격·회피·피격·사망 동작에 Regression이 없다.
- Godot 4.7.2 Compatibility에서 Project load와 Main Scene 실행이 성공하고 Script Error 및 Missing Resource가 없다.
- 실제 변경은 승인된 두 Allowed Paths에만 한정된다.

## 결과물(Deliverables)

- 구현 결과
- 실행 및 검증 기록

## 의존성

- Director Decision: 같은 physics frame 동시 종료 시 FAILED 우선 확정

## 작업 결과

Execution: PASS

Review/QA: PASS

Director: PASS

## 알려진 문제

없음

## 검토(Review)

검토자: Review/QA
결과: PASS
의견: Director 승인 및 Execution Review PASS
