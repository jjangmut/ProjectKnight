# ProjectKnight Studio V3 — R3 독립 검수

- Reviewed: `studio/v3-002-agent-orchestrator-r3@e298c4d8ed0c7d4ff77bc86b6e096a9e3fd1ab6d`
- Scope: GitHub source, committed R3 QA logs, tests, queue and uploaded Antigravity action trace.
- Limitation: Windows Antigravity/Godot 실행을 여기서 직접 재현하지 못했으므로 도구 출력은 원격 제출 증거로 평가함.
- **Decision: FIX_REQUIRED — 제한된 단기 수정 후 재검수.** Parent V3-002와 V3-003을 승인하지 않는다.

## 검증한 진전
- Antigravity IDE 실행 기록은 한 Producer 문맥에서 `invoke_subagent` 5회와 각 결과 인계가 순서대로 일어났음을 보여 준다. 이는 R2에 비해 의미 있는 증거다. 다만 이는 **IDE-native orchestration** 증거이며, Python CLI/headless 단독 자율 실행 증거는 아니다.
- 서로 다른 PK_ClientLead ×2, PK_QALead ×2, PK_GameDirector ×1 세션, 실제 코드 수정과 QA 반려/재검수 기록이 GitHub에 있다.
- `test_fixture_stamina_r3.gd`는 실제 조건 검사와 실패 시 `quit(1)`을 실행하는 테스트 코드이고, 74/74 PASS 출력 로그가 커밋됐다.
- 신규 모의 검수 차단, 중복 invocation 차단 및 승인 시 lease 정리 코드가 추가됐다.
- R3 fixture `FIXTURE-V3-LIVE-003`는 APPROVED, 실제 인프라 작업 `V3-002-R3`는 IN_REVIEW이다. **픽스처 승인은 인프라 승인이 아니다.**

## 수정 필요 사항

### P0-01 — 필수 검수 JSON 필드 누락 허용
`dispatcher.py::parse_reviewer_verdict`는 `role`이 없으면 검사하지 않고, `reviewed_commit_sha`가 빠지면 현재 task SHA로 **자동 보충**한다. `task_id`, `iteration`도 JSON에서 검증하지 않는다. 따라서 단순 `{"verdict":"PASS"}`도 적절한 인증 세션의 출력에 포함되면 PASS로 변환될 수 있다. 이것은 R3 지시서의 필수 스키마 계약과 충돌한다.

**Fix:** task_id, iteration, role, reviewed_commit_sha, verdict, evidence_manifest를 명시적으로 요구하며 현재 task/세션/커밋과 정확히 비교. 필드 누락·타입 오류·복수 JSON 응답·정확한 최종 결과 부재는 fail closed. 이를 증명하는 부정 테스트를 추가.

### P0-02 — 실제 Git 커밋과 증거 내용의 결속 미완성
`dispatcher.py::submit_work`는 `target_commit_sha`가 Git 객체인지 확인하지만, 산출물의 **파일 경로와 SHA256이 해당 Git tree에 실제 포함된 바이트와 일치하는지**는 확인하지 않는다. 현재 작업 디렉터리에만 존재하는 미커밋 산출물도 증거 매니페스트로 제출될 수 있다.

**Fix:** 제출 대상 커밋을 worker invocation에서 추적하고, `git ls-tree` 및 `git show <sha>:<path>` 등으로 커밋된 파일과 작업 증거 일치를 검증한다. 다른 브랜치의 SHA/작업 범위 이탈/미커밋 변경을 거부하는 테스트 추가.

### P1-03 — 세션 provenance와 완료 검증이 여전히 선택적
`runner.py::step_worker_delivery` 및 `step_reviewer_verdict`의 `parent_conversation_id` 기본값은 빈 문자열이다. 빈 값이면 `subagent_bridge.py`의 부모 대화 비교는 생략된다. `ingest_verified_subagent_execution`는 caller가 지정한 task_id, SHA, evidence를 신뢰하며, transcript 안에서 **어느 한 줄이라도** `status=="DONE"`이면 완료로 인정한다. 동일 task+iteration 내 세션 재등록도 runner 쪽에서 `if not get_invocation`으로 건너뛰므로 무조건 거부하지 않는다.

**Fix:** 정상 live 모드에서는 부모 대화/run/task/iteration/SHA를 의무적으로 연결하고, 중복 세션을 같은 task+iteration에서도 차단. 완료는 공식 최종 terminal event를 확인. 값이 없으면 NOT VERIFIED, 임의로 채우지 말 것.

### P1-04 — 원본 Python 테스트 로그가 원격 저장소에 없음
`source_manifest.json`에는 `test_logs/python_tests_29_pass.log`가 기록되지만, 검수한 GitHub tree와 R2→R3 변경 파일에는 해당 파일이 없다. Godot 74개 테스트의 스크립트와 원본 로그는 확인했다. Python 29/29의 결과는 현재 **보고서 기준**이며 검수자가 원격 저장소만으로 재확인할 수 없다.

**Fix:** Python 테스트 원본 로그를 추가하고 실행 명령, 종료 코드, Python/패키지 버전을 함께 기록한다. `.gitignore`에 의해 제외된다면 필요한 로그만 명시적으로 추가한다.

### P1-05 — 감사 이벤트의 run_id 미기록
R3의 `events.jsonl` 신규 레코드에도 `parent_run_id:""`가 남아 있다. `TASK_STARTED`의 `claim_token`만으로 전체 `WORK_SUBMITTED`, `REVIEW_REJECTED`, `REVIEW_PASSED`, `TASK_APPROVED`을 직접 결속하기 어렵다.

**Fix:** 모든 이벤트에 동일한 run_id, task ID, iteration, session ID, commit SHA를 연관시킨다. 누락/다른 run_id가 발생하면 승인 거부.

### P2-06 — 이력 정합성과 재사용 가능한 Producer 지침
R3의 `queue.json`은 R2 독립 검수가 FIX_REQUIRED였는데도 `V3-002-R2: IN_REVIEW`로 남아 있다. 과거 `FIXTURE-V3-LIVE-002` APPROVED 레코드에는 구 lease가 남아 있다. 현재 네이티브 `.agents/agents/PK_Producer.md`에는 R3의 새 Runbook 참조가 없다. R3 자체는 `IN_REVIEW`, `iteration:0` 및 검수 SHA가 비어 있어 인프라 소스 자체의 검수 인계가 완료된 상태가 아니다.

**Fix:** 기존 이력은 삭제하지 말고 정정 이벤트/이행 기록으로 보정. Producer 에이전트 지침에서 `NATIVE_PRODUCER_RUNBOOK.md`를 필독으로 연결. R3 인프라 HEAD에 대한 별도 QA/Director 리뷰 요청.

## 재검수 수락 조건
1. IDE-native single-prompt 협업 구조는 유지하되 Python standalone 자동 실행이라고 주장하지 않는다.
2. 불완전 JSON 판정은 반드시 거절.
3. 커밋된 정확한 파일/바이트만 증거 승인.
4. 세션+부모 대화+작업+SHA 연결과 재사용 차단.
5. Python 29개 테스트 raw log와 Godot 74개 로그가 모두 원격에서 확인.
6. 승인된 작업은 활성 lease가 없고, 관련 모든 이벤트에 같은 run_id가 있다.
7. R3 인프라 SHA에 대한 두 독립 리뷰가 별도로 제출됨.
8. `V3-001`이 승인되기 전까지 `V3-003`은 BLOCKED.

**결론:** 현재 **IDE 내 멀티에이전트 워크플로는 작동 증거가 충분히 늘었지만, 프로덕션 승인 게이트는 아직 안전하다고 인증할 수 없다.** 새로운 대규모 R4 재설계가 아니라 좁은 범위의 R3 보안 수정 패치 권장.
