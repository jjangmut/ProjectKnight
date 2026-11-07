# TASK V3-001-ATTESTATION-CLOSE — 동결 증거/사후 검수 산출물 연결 정정

**상태:** READY — 지시서 등록만 완료, 실행 전
**우선순위:** P0 (V3-001 외부 검수 종료를 막는 단일 증거 결함)
**작업 브랜치:** `studio/v3-001-attestation-close`
**기준 커밋:** `0d99e2b0da5ecd30cff8641348ba4ed3e897423b`
**동결 원본 증거 SHA:** `c55714745ac15776d5ffa449da6058da3dd777ea`
**사후 보고서가 최초 포함된 커밋:** `0d99e2b0da5ecd30cff8641348ba4ed3e897423b`
**원본 게임 SHA:** `a71223615d0b77e36dd85edb24e138fc67ecc140`
**독립 검수 원문:** `STUDIO_V3/reviews/V3-001-RECONCILE-INDEPENDENT-REVIEW.md`
**총괄:** PK_Producer / **증거 수정:** PK_ClientLead / **독립 검수:** PK_QALead + PK_GameDirector
**범위:** Git 증거 계보 및 과거 작업 큐 검수 귀속 정정 + 잘못된 대외 완료 요약 정정. **코드/게임/성능 재개발 아님.**

## 목표와 제약

외부 독립 검수에서 유일한 차단 문제로 남은 **"검수 전 동결 SHA에 검수 후 만들어진 3개 파일을 포함해 증명한 오류"**를 정정한다. 현재 게임 기준점과 개발 결론은 보존한다. 예전 검수 이벤트를 지우거나 뒷날 작성한 파일을 과거 커밋에 있었던 것으로 위조하지 않는다.

이 작업에는 **최대 1회의 정정 실행 사이클**만 허용한다. 증거 시스템의 새 아키텍처, R4, 게임 개발, 반복 벤치마크, 에이전트 신규 역할 추가, 무제한 재검수 금지.

## Gate 0 — Git 실제 내용 재현 (실행의 첫 단계)

1. `studio/v3-001-attestation-close` fetch 및 독립 worktree checkout. `git status --short`, `git rev-parse HEAD`, branch와 청결 상태를 기록한다.
2. `STUDIO_V3/reviews/V3-001-RECONCILE-INDEPENDENT-REVIEW.md`, `STUDIO_V3/tasks/V3-001-EVIDENCE-RECONCILE.md`, `STUDIO_V3/PROTOCOL.md`, `STUDIO_V3/orchestrator/{queue_store,policies,dispatcher}.py`의 실제 검수/정정 계약을 확인한다.
3. **이력 진실성 검증:** 아래 명령을 그대로 수행한 raw 출력과 exit code를 저장한다.
   ```sh
   git diff --name-status c55714745ac15776d5ffa449da6058da3dd777ea 0d99e2b0da5ecd30cff8641348ba4ed3e897423b
   git ls-tree -r --name-only c55714745ac15776d5ffa449da6058da3dd777ea -- STUDIO_V3/evidence/V3-001-reconcile/
   git cat-file -e c55714745ac15776d5ffa449da6058da3dd777ea:STUDIO_V3/evidence/V3-001-reconcile/QA_ADDENDUM.md
   git cat-file -e c55714745ac15776d5ffa449da6058da3dd777ea:STUDIO_V3/evidence/V3-001-reconcile/DIRECTOR_ADDENDUM.md
   git cat-file -e c55714745ac15776d5ffa449da6058da3dd777ea:STUDIO_V3/evidence/V3-001-reconcile/FINAL_RECONCILIATION_REPORT.md
   ```
   마지막 3개 파일의 `git cat-file -e`는 **실패해야 정상**이다. 실패를 성공으로 포장하지 말 것.
4. 작업 전 `queue.db`가 있으면 백업하고 `queue.json`과 비교한다. 기존 승인 이벤트/원본 세션 메타/타임스탬프를 삭제하거나 소급 변경하지 않는다.

## P0 — 정확한 2계층 Git 증거 모델로 정정

### A. 리뷰 대상 동결 증거 — `c557147...`에 실제 존재하는 7개만

```text
STUDIO_V3/evidence/V3-001-reconcile/performance/PERFORMANCE_METHOD.md
STUDIO_V3/evidence/V3-001-reconcile/performance/analysis.py
STUDIO_V3/evidence/V3-001-reconcile/performance/analysis_output.json
STUDIO_V3/evidence/V3-001-reconcile/performance/benchmark_source/benchmark_stage1_windowed.gd
STUDIO_V3/evidence/V3-001-reconcile/GAMEPLAY_ISSUE_BACKLOG.md
STUDIO_V3/evidence/V3-001-reconcile/ISSUE_RECONCILIATION.md
STUDIO_V3/evidence/V3-001-reconcile/CAPTURE_MANIFEST.json
```

각 경로를 `git show c557147...:<path>`에서 읽고 Git blob 바이트의 SHA256을 재검증한다. 파일 개수·경로·커밋 SHA·해시를 별도 `REVIEWED_SOURCE_MANIFEST.json`에 기록한다. **현재 작업 디렉터리에 존재한다는 사실만으로 커밋에 포함됐다고 간주하지 말 것.**

### B. 리뷰 완료 이후 만들어진 출력 — `0d99e2...`에만 결속

```text
STUDIO_V3/evidence/V3-001-reconcile/QA_ADDENDUM.md
STUDIO_V3/evidence/V3-001-reconcile/DIRECTOR_ADDENDUM.md
STUDIO_V3/evidence/V3-001-reconcile/FINAL_RECONCILIATION_REPORT.md
```

세 파일을 `REVIEW_OUTPUT_MANIFEST.json`으로 구분하고 `created_after_review_source_sha=c557147...`, `first_containing_commit=0d99e2...`를 명시한다. 이 파일들의 SHA256은 `git show 0d99e2...:<path>`에서 검증한다. **세 파일의 source_commit_sha를 c557147로 적으면 무조건 오류.**

### C. 불변 과거 검수 정정 및 현재 유효 상태

현재 `STUDIO_V3/queue.json`의 `V3-001-EVIDENCE-RECONCILE.evidence_manifest`와 양쪽 `reviews[*].evidence_hashes`에 사후 출력 3개가 `c557147...`에 있는 것처럼 기록되어 있다.

- 원본 `events.jsonl`의 과거 행은 반드시 그대로 둔다.
- `EVIDENCE_ATTESTATION_CORRECTED` 혹은 프로젝트 정책상 지원되는 동등한 **신규 보정 이벤트**를 append-only로 남긴다. 어떤 기존 이벤트/매니페스트 항목이 왜 잘못됐고 무엇으로 대체됐는지 old ref, source SHA, output SHA, correction commit, actor, time, run_id를 명시한다.
- 정확히 존재하는 **7개**만 `reviewed_source_evidence`로 인정한다. 사후 보고서 **3개**는 `review_output_evidence`로 분리한다.
- 기존 `APPROVED` 상태를 가짜 성공으로 취급하지 않는다. **과거 내부 승인 사실**과 **외부 증거 정정 전 승인 근거의 미흡함**을 명시한다.
- QueueStore/TaskDispatcher가 정당한 감사 보정/상태 전이를 지원하면 **정식 API/감사 이벤트**로 반영한다. 단순히 `queue.json` 문자열을 일괄 교체하여 정책을 우회하거나 과거 검수자를 속이는 방법은 금지한다.
- 현행 코드가 승인 상태의 사후 정정을 안전하게 지원하지 않으면 무리하게 우회하지 말고 `CORRECTION_NOT_SUPPORTED`를 보고한다. 이 경우 작업은 `FIX_REQUIRED`이며 **최소 범위의 검증된 migration 또는 신규 correction task**로만 처리한다.

## Gate 1 — 자동 검증 및 부정 테스트

기존 Git/증거 검증 함수를 재사용하여 다음 항목을 자동 확인한다.

1. `git show c557...:<7 source paths>` 모두 성공, SHA256 일치.
2. `git show c557...:<3 postreview paths>` 모두 **실패**.
3. `git show 0d99...:<3 postreview paths>` 모두 성공, SHA256 일치.
4. 동결 전 7개를 10개로 속여도 provenance gate가 거부.
5. 원본 `STUDIO_V3/evidence/V3-001/performance/raw_frames.csv`와 11 PNG, `CLIENT/Game/`가 작업 전과 동일.
6. 정정 이벤트는 이전 events 줄을 보존한 **추가 이벤트**이며 실행 시 이전 감사기록 해시를 확인.
7. 동일 task/run/iteration/검수자/검수 SHA의 재사용·모순된 최종 결과를 무조건 PASS로 세탁하지 않음.

위 검증을 수행한 실제 명령, raw stdout/stderr 및 종료 코드를 저장한다. 증거 계보 문서만 수정했다면 Godot 게임을 다시 4분 재생할 필요는 없다. Studio V3 승인 로직 **코드**를 수정했다면 관련 Python 회귀 테스트를 반드시 재실행한다.

## Gate 2 — 보고서 사실 정정

기존 Antigravity 완료 요약의 이슈 명칭 7개 중 다수가 정본과 다르다. 오직 `STUDIO_V3/evidence/V3-001-reconcile/GAMEPLAY_ISSUE_BACKLOG.md`를 기준으로 새 `PRODUCER_CORRECTED_SUMMARY.md`를 작성한다.

| ID | 정본 제목 | 우선순위/상태 |
|---|---|---|
| ISSUE-V3-001-01 | 모바일 가상 조이스틱 및 액션 버튼 누락 | P1 OPEN |
| ISSUE-V3-001-02 | Z축 자유 이동 vs 횡스크롤 전투 평면 설계 불일치 | P1 DECIDED / IMPLEMENTATION_PENDING |
| ISSUE-V3-001-03 | 시작 시 `add_child()` 노드 등록 오류 | P2 OPEN |
| ISSUE-V3-001-04 | Sprite3D 접지/점프 위치 문제 | P2 OPEN |
| ISSUE-V3-001-05 | 보스 돌진 전조 연출 부족 | P3 OPEN |
| ISSUE-V3-001-06 | 스테이지 결과/보상 화면 부재 | P3 OPEN |
| ISSUE-V3-001-07 | 보스전 전방 성벽·기둥에 따른 캐릭터/보스 시야 가림 | P1 OPEN |

총 7개 고유 이슈(P1 3, P2 2, P3 2); **Option C는 결정됐지만 코드 미구현**. 감사 정확성 승인과 게임 출시 품질 승인을 절대 혼동하지 않는다.

성능 정정 요약도 정확히 기재한다:
- 원본 CSV 약 60Hz = 물리 틱 데이터 수집 간격.
- 엔진 FPS 모니터 = overall 평균 **238.34**, median 240. Steady walking/normal/boss 구간 평균 약 239.54.
- `Performance.TIME_PROCESS`는 GPU 총 프레임 시간의 직접 측정이 아니다.
- VSync enabled 보고와 "uncapped"라는 표현은 구분; 실제 VSync 설정 미확인 시 단정 금지.
- `COMBAT_STRESS_DIFFERENTIAL_NOT_VERIFIED`, Android `NOT_TESTED` 유지.

## Gate 3 — 새로운 최종 증거 검수의 정확한 순서

1. 2종 manifest + 정정 문서 + 검증 스크립트 + 올바른 Producer 요약을 **먼저** 커밋하여 `CORRECTED_EVIDENCE_SHA`를 동결한다. 이후 이 커밋의 내용을 수정하지 않는다.
2. PK_Producer가 **새** native `PK_QALead`와 `PK_GameDirector` 세션을 각각 호출하고, 두 역할 모두 `CORRECTED_EVIDENCE_SHA`의 실제 tree에서 2종 manifest, 정정 이벤트/연결 원칙, 7개 backlog, 보고서 수치, 이전 증거 SHA를 확인하도록 한다. 부모 대화/run/task/iteration/검수 SHA 및 terminal DONE과 최종 schema verdict를 보존.
3. QA와 Director는 **동일한 frozen SHA**에 대한 독립적 결과를 제공해야 한다. 과거 세션을 재사용해 새로운 검수인 척하지 말고, 제공자가 실제 신규 세션을 만들 수 없으면 `NOT_VERIFIED`.
4. 새 `QA_REVIEW_FINAL.json`, `DIRECTOR_REVIEW_FINAL.json`, 실행 provenance/event log, 결과보고서와 Queue snapshot은 **그 이후 별도 `REVIEW_OUTPUT_COMMIT_SHA`**로 저장한다. 이 사후 파일을 `CORRECTED_EVIDENCE_SHA`의 입력 증거 해시에 포함하지 않는다.
5. 기존 `V3-001-EVIDENCE-RECONCILE`의 내부 이력은 보존한다. 정정 Task `V3-001-ATTESTATION-CLOSE`에 대해서만 정상 상태 전이를 수행한다. 원본 Task나 상위 `V3-002`를 임의로 APPROVED로 바꾸지 않는다.
6. 외부 ChatGPT 검수는 **Git tree/manifest와 정정 이벤트의 실제 일치**만 확인하면 종료 가능하도록 결과를 제출한다. 내부 검수 PASS만으로 외부 승인이라고 주장하지 않는다.

**Self-reference 금지:** 검수자가 검수 대상 커밋에 존재하지 않았던 자신의 검수 결과 파일을 '검수 전 확인한 소스 증거'로 적는 순간 이 작업도 FAIL이다.

## 산출물 (실제 생성된 파일만 제출)

```text
STUDIO_V3/tasks/V3-001-ATTESTATION-CLOSE.md
STUDIO_V3/reviews/V3-001-RECONCILE-INDEPENDENT-REVIEW.md
STUDIO_V3/evidence/V3-001-attestation-close/
  REVIEWED_SOURCE_MANIFEST.json
  REVIEW_OUTPUT_MANIFEST.json
  ATTESTATION_CORRECTION.md
  PRODUCER_CORRECTED_SUMMARY.md
  validation/commands_and_raw_log.txt
  validation/negative_test_results.txt
  QA_REVIEW_FINAL.json                 # 후속 evidence-only commit
  DIRECTOR_REVIEW_FINAL.json           # 후속 evidence-only commit
  PROVIDER_PROVENANCE.json             # 후속 evidence-only commit
  FINAL_EXECUTION_REPORT.md            # 후속 evidence-only commit
STUDIO_V3/queue.json
STUDIO_V3/events.jsonl                 # append-only
STATE.md
```

## 완료 조건

- [ ] frozen source SHA 7개 파일과 review-output SHA 3개 파일을 정확히 구분.
- [ ] SHA256은 각각 실제 Git blob 바이트와 일치.
- [ ] old events 원형 보존 + 정식 corrective event 추가.
- [ ] 과거 검수자의 미래 파일 해시를 현재 유효한 source attestation으로 취급하지 않음.
- [ ] 위조된 path/source SHA 제출 부정 테스트에서 FAIL.
- [ ] 정확한 7개 게임 이슈 및 PC FPS 수치가 대외 요약과 일치.
- [ ] 11 PNG / 14,404-row CSV / `CLIENT/Game/` 원본 보존.
- [ ] 두 개의 **신규** 독립 QA/Director 세션이 동일한 corrected evidence SHA를 검수.
- [ ] 검수 결과 파일은 검수 뒤의 별도 커밋에 기록.
- [ ] parent `V3-002`는 별도 공식 롤업 승인 전까지 FIX_REQUIRED, `V3-003`은 BLOCKED.
- [ ] 누락된 증거나 provider 신원 정보는 NOT_VERIFIED로 기록하고, 자의적 PASS 없이 종료.

## Producer 최종 보고 형식

```text
TASK: V3-001-ATTESTATION-CLOSE
Branch: studio/v3-001-attestation-close
Frozen original evidence: c55714745ac15776d5ffa449da6058da3dd777ea
Post-review original output: 0d99e2b0da5ecd30cff8641348ba4ed3e897423b
Corrected evidence SHA: ...
Review output commit SHA: ...
Frozen 7 source files: 7/7 Git-tree + SHA256 VERIFIED / FAIL
Post-review 3 files absent from frozen tree: 3/3 VERIFIED / FAIL
Post-review 3 files present at output SHA: 3/3 VERIFIED / FAIL
Events append-only correction: VERIFIED / FAIL
Negative provenance tests: N/N PASS
Original game, CSV, 11 PNG untouched: VERIFIED / FAIL
Canonical gameplay defects: 7 (P1 3 / P2 2 / P3 2)
FPS semantic correction: VERIFIED / NOT_VERIFIED
New independent QA: session id ..., verdict ...
New independent Director: session id ..., verdict ...
Corrected work task status: IN_REVIEW / APPROVED / FIX_REQUIRED
External review: REQUESTED
Parent V3-002: FIX_REQUIRED
V3-003: BLOCKED
```

**시작 지시:** PK_Producer는 지금 `studio/v3-001-attestation-close`를 Fetch하여 본 문서를 읽고, **동결 SHA 7개 vs 사후 보고서 3개**의 증거 계보 오류만 바로잡는다. 코드를 다시 설계하지 말고 1회 정정, 신규 QA·Director 검수, GitHub push 후 외부 검수를 요청한다.
