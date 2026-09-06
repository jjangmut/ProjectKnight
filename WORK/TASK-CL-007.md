# 작업(Task)

상태와 검토 절차는 StudioOS의 `WORKFLOW.md`를 따른다.

## 기본 정보

작업 ID: TASK-CL-007
제목: Player 3회 피격과 단일 사망·행동 차단 — 독립 피격 무적 보정
상태: DONE
담당 영역: 클라이언트(Client)
책임자(Owner): Client Lead
작업자(Worker): Client
협의자(Consulted): Planning Lead
검토자(Reviewer): Review/QA

## Revision

Revision: 1

Reason: Director 보고상 기존 피격 무적은 없고 _hurt_flash_remaining은 0.12초 시각 Flash만 처리하므로 재사용 전제가 성립하지 않는다. 제공된 Planning Lead → Client Lead → Review/QA 결과를 종합하여 3회 피격 규칙과 대응 기회를 위한 최소 보정을 제안한다. 함수 본문·기준선·실행 증거가 부족하여 QA 권고는 BLOCKED이며, 이번 응답은 파일 수정이나 Worker 호출 없이 작성한 Revision 제안이다.

Execution Approval: Required Again

## 목적

존재하지 않는 기존 피격 무적을 재사용한다는 Execution BLOCKED 원인을 보정한다. 기존 체력과 receive_hit()를 활용하고 Flash와 독립적인 피격 무적 0.5초를 제안하여 3회 유효 피격 사이의 대응 기회를 확보한다. 0.5초는 본 Revision 승인 전까지 미확정 제안값이다.

## 작업 내용

- player.gd 내부에 Flash와 독립적인 피격 무적을 최소 추가한다.
- 초기 HP 3, 유효 피격당 HP 1 차감, 세 번째 유효 피격의 단일 사망을 유지한다.
- 사망 후 이동·점프·공격·회피와 추가 피해를 차단한다.
- 전투 수치 변경 제외의 예외는 본 Revision에서 제안하는 피격 무적 0.5초 추가로 한정한다.

## 작업 범위

- player.gd 내부에 Flash와 독립적인 피격 무적을 최소 추가한다.
- 초기 HP 3, 유효 피격당 HP 1 차감, 세 번째 유효 피격의 단일 사망을 유지한다.
- 사망 후 이동·점프·공격·회피와 추가 피해를 차단한다.
- 전투 수치 변경 제외의 예외는 본 Revision에서 제안하는 피격 무적 0.5초 추가로 한정한다.

## 제외 범위

- 사망 UI, 재시작, 체크포인트
- 상태·Enemy·Projectile 복원
- 신규 Enemy, 공격 방식 및 피격 무적 외 전투 수치 변경
- 회피 규칙 변경, 신규 무적 연출
- Scene·Resource·Enemy·Projectile 파일 변경
- Singleton 추가, Framework 변경 및 대규모 정리

## 참조 자료

- `PROJECT.md`
- `PROJECT_RULES.md`
- `STATE.md`

## 완료 조건(Acceptance Criteria)

- 초기 HP 3에서 유효 피격마다 2 → 1 → 0으로 변하며 첫 두 피격에서는 생존하고 세 번째에서 사망 진입과 처리가 각각 정확히 한 번 발생한다.
- 0.5초 채택 시 생존 유효 피격 후 0.5초 미만의 Hit는 차단하고 0.5초 이상에서는 기존의 다른 차단 조건이 없으면 허용한다. 차단된 Hit는 HP와 무적 종료 시점을 변경하지 않는다.
- 동일 프레임 근접·투사체·혼합 Hit 중 최초 유효 Hit만 HP를 차감한다. HP 1에서도 사망이 중복 처리되지 않는다.
- 0.12초 Flash 종료가 피격 무적을 해제하지 않는다. 지속 접촉에서도 새 Hit 없이 자동으로 HP를 차감하지 않으며 접촉 이탈을 요구하지 않는다.
- 사망 후 추가 Hit는 HP와 사망 상태를 변경하지 않는다. Move·Jump·Attack·Dodge 입력과 진행 중 공격 피해·회피 추진이 사망 차단을 우회하지 않는다.
- 피격 무적은 추가 행동 잠금을 만들지 않는다. TASK-CL-006 대비 생존 행동, 기존 회피·피격 규칙과 근접·투사체 연동에 Regression이 없다.
- Godot 4.7.2 stable Standard, GDScript, Compatibility 기준 Project load와 Main Scene 검증이 통과하고 Script Error 및 Missing Resource가 없다.
- 모바일에서 첫 피격 후 다음 유효 피격 전 대응 행동 가능 여부와 대응 불가 원인을 기록한다. 체감 기준이나 관측 증거가 없는 항목은 PASS로 처리하지 않는다.
- 실제 변경은 allowed_paths와 승인된 범위 안에 한정되며, 독립 Review/QA 검증 전 DONE으로 처리하지 않는다.

## 결과물(Deliverables)

- 구현 결과
- 실행 및 검증 기록

## 의존성

- 본 Revision 및 0.5초 피격 무적 추가에 대한 실행 재승인
- TASK-CL-006 결과와 실제 함수 본문을 통한 기존 행동·피해·회피 기준선 확인
- Planning Lead와 Client Lead의 기존 회피 중첩 및 사망 후 중력·낙하 처리 기준 확인; 새 규칙이 필요하면 별도 제안
- Runtime의 문서상 READY와 최신 Execution BLOCKED 불일치 정리
- 완료 판정에 필요한 후속 실행·diff·Git Guard·Godot 검증 증거

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
