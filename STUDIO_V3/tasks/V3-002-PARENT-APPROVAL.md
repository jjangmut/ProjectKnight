# TASK V3-002-PARENT-APPROVAL — Studio V3 오케스트레이터 상위 마일스톤 최종 롤업

**Status:** READY (지시서만 등록, 최종 롤업 미실행)  
**Priority:** P0 — V3-003 개발 착수 전 마지막 거버넌스 게이트  
**Branch:** `studio/v3-002-parent-approval`  
**Base commit:** `8172175c9434dbc2765400e2c38ec2b84e035b2b`  
**Parent task:** `V3-002` (GitHub queue: FIX_REQUIRED, owner PK_Producer, iteration 1, unreviewed parent)  
**Approved implementation child:** `V3-002-CLOSE` (internal APPROVED, external review ACCEPTED)  
**Immutable infrastructure code SHA:** `214000678186b6ebb42349eeb28336b4dcfe0e42`  
**Audit evidence status:** `V3-001` internally APPROVED and externally accepted after `V3-001-ATTESTATION-CLOSE`  
**Coordinator/parent owner:** PK_Producer  
**Independent reviewers:** PK_QALead + PK_GameDirector (two distinct NEW Antigravity native sessions for **parent milestone**)  
**Goal:** existing V3-002 formal approval only. No Studio V3 rebuild, new R4, gameplay implementation, changes to `CLIENT/Game/`, or historical event rewriting.

## 0. 중요한 구분

이번 작업은 **구현·테스트를 재실행하는 R5 작업이 아니라** 기존 V3-002 전체 마일스톤의 승인 증거를 연결하고 독립 검수하는 **final roll-up**이다. 아래 세 개의 SHA는 혼동 금지.

- **`INFRA_SOURCE_SHA = 214000678186b6ebb42349eeb28336b4dcfe0e42`** — QA가 통과했던 *실제 구현 코드*의 동결 커밋. 그 이후 `STUDIO_V3/orchestrator/` 소스가 수정됐다면 diff를 확인하고 더 이상 해당 SHA를 최신 구현이라고 단정하지 말 것.
- **`PARENT_REVIEWED_SHA`** — 이번에 작성하는 **부모 마일스톤 승인 패킷**(rollup manifest, 기존 품질·실행 증거에 대한 정확한 포인터, 검증 명령/로그, 미해결 리스크)이 실제 커밋된 후 동결되는 새 SHA. **이번 parent task의 직접 검수 대상은 이 SHA**. 이 SHA가 실제 저장소에 포함한 파일만 source-evidence로 등록한다.
- **`PARENT_REVIEW_OUTPUT_SHA`** — QA/Director가 `PARENT_REVIEWED_SHA`를 검수한 **이후** 작성한 최종 검수 JSON, provider provenance 및 최종 보고서의 별도 커밋. 이 파일들을 과거 `PARENT_REVIEWED_SHA`에 존재했다고 주장하면 FAIL.

독립 검수자는 `PARENT_REVIEWED_SHA`에 포함된 **승인 패킷**과, 그 패킷에서 명시한 실제 구현 `INFRA_SOURCE_SHA`를 함께 검사한다. 리뷰의 `reviewed_commit_sha`는 작업 큐에 제출한 `PARENT_REVIEWED_SHA`와 정확히 일치해야 하며, 패킷 내부 `infrastructure_source_sha`는 `214000...`에 정확히 고정한다. SHA를 억지로 동일하게 만드는 잘못된 후행 증거 바인딩 금지.

## 1. 준비 및 현재 사실 확인

1. `git fetch origin`, `studio/v3-002-parent-approval` 전용 worktree checkout. 시작 시 branch, HEAD, working tree, 원격 SHA, `CLIENT/Game/` 변경 여부를 기록한다.
2. `STUDIO_V3/tasks/V3-002.md` 원래 요구사항과, `STUDIO_V3/tasks/V3-002-CLOSE.md`, `STUDIO_V3/PROTOCOL.md`, `STUDIO_V3/docs/NATIVE_PRODUCER_RUNBOOK.md`, `STUDIO_V3/orchestrator/`의 실제 현재 정책 및 계약을 읽는다.
3. 승인 보고서 **두 건**을 읽는다.
   - `STUDIO_V3/reviews/V3-002-CLOSE-INDEPENDENT-REVIEW.md` (외부 코드/증거 검수 ACCEPTED)
   - `STUDIO_V3/reviews/V3-001-ATTESTATION-CLOSE-INDEPENDENT-REVIEW.md` (외부 게임 *감사* 증거 ACCEPTED, **게임 출시 승인 아님**)
4. 로컬 SQLite `queue.db`가 있으면 백업하고 GitHub `queue.json`와 실제 상태를 대조한다. 실제 state authority가 SQLite인 환경에서 **JSON 파일만 수정해 APPROVED를 위조하지 말 것**.
5. **기준 상태:** V3-002 parent = FIX_REQUIRED, V3-002-CLOSE = APPROVED, V3-001 = APPROVED (audit only), V3-003 = BLOCKED. 만약 실제 DB가 다른 상태라면 원인을 먼저 기록하고 공식 reconciliation으로 해결하며 status를 추측해 쓰지 말 것.
6. `git merge-base --is-ancestor 214000678186b6ebb42349eeb28336b4dcfe0e42 HEAD`와 `git diff --name-status 214000... HEAD -- STUDIO_V3/orchestrator STUDIO_V3/tests .agents/agents`로 구현에 실질적인 이후 변경이 있는지 확인한다. 이후 코드 변경을 발견하면 해당 SHA의 수용 범위를 명시해 정확한 롤업 범위를 결정한다. 증거-only commit과 구현 변경을 혼동하지 않는다.

## 2. 최종 승인에 포함할 필수 증거 — 교차검증

**공인 기준:** `V3-002-CLOSE` 승인 및 `V3-002-CLOSE-INDEPENDENT-REVIEW.md`의 한계와 caveat까지 유지한다.

### A. 코드 및 음성적 PASS가 아닌 실제 기능 증거
- Python 57/57 PASS 원본 로그 및 exit code, Godot 74/74 PASS 원본 로그를 **기존 파일에서 참조**한다. 이 Godot 검증은 **독립 stamina fixture**이고 실제 Stage 1 그래픽/입력/Android 품질을 보증하지 않는다.
- `policies.py`: 실패 시 차단되는 Git/provenance gate, 원본 blob SHA256 일치 및 dirty source 차단.
- `dispatcher.py`: strict review JSON, P0/P1 open issue 차단, independent two-key approval 및 Lease 정리.
- `adapters/subagent_bridge.py`, `runner.py`: parent/session/terminal/role/task/replay 연계. 이전 DONE만 보고 새 작업이 완료된 것처럼 처리하지 않음.
- `queue_store.py`: SQLite 전이 및 검수 세션 등록, single-entry run_id, 상태 스냅샷과 event log 동기화.

### B. 실제 Antigravity IDE-native 에이전트 흐름
- 기존 `FIXTURE-V3-LIVE-003` 및 필요 시 R2 이슈-재작업-재검수-Director 증거를 참조한다.
- 과거 5세션 체인은 Worker→QA 반려→Worker 수정→QA PASS→Director 승인에 대한 **기록상 IDE-native 실행 증거**다. 단, 이는 **Python standalone/headless 에이전트 자동 실행**의 증거가 아님.
- 실제 신규 parent reviewer 검수는 별도로 수행한다. 역사적 stamina fixture의 reviewer session IDs 및 `V3-002-CLOSE` child reviewer IDs를 **부모의 신규 QA/Director 세션으로 재사용하지 않는다**.

### C. 종료된 결함과 한계
- R2/R3/R3-PATCH가 과거 FIX_REQUIRED였던 것은 이력으로 유지. 해당 결함을 **V3-002-CLOSE의 개선된 커밋에서 해결했음을 mapping table로 입증**하되 이전 실패 상태를 임의로 APPROVED로 변경하지 않는다.
- 다른 사용자의 기기와 보안·프로바이더 환경에서 자동 실행 보장을 선언하지 않는다. 제공된 엔진/테스트/런타임 범위만.
- Game client는 P1=3 OPEN (터치 UI, Z=0 미구현, 보스전 occlusion), Stage1 출시 `NOT_APPROVED`. 해당 이슈는 V3-002 인프라 자체의 blocking issues와 구별한다.

## 3. 부모 마일스톤 롤업 패킷 작성 및 동결

아래 파일만 **실제 검사 결과를 바탕으로 작성하고 첫 커밋**한다. 새로운 test run을 했다고 위조하지 않는다.

```text
STUDIO_V3/evidence/V3-002-parent/
  PARENT_ACCEPTANCE_MATRIX.md
  PARENT_ROLLUP.md
  SOURCE_AND_EVIDENCE_MANIFEST.json
  verification/commands_and_raw_output.txt
  verification/invariants.json
```

- Matrix는 원래 `STUDIO_V3/tasks/V3-002.md`의 모든 acceptance bullet을 **VERIFIED / PARTIAL / NOT_VERIFIED / NOT_APPLICABLE** 중 하나로 평가하고, 정확한 Git 파일·SHA·test log·session ID·실제 command를 링크한다. 검증 안 된 acceptance item에 임의 PASS 금지.
- 롤업 문서는 최초 V3-002 요구사항과 현재 IDE-native 설계의 차이(실제 CLI 미지원 가능성, standalone headless autonomy 미입증 등)를 정확히 남긴다. **마일스톤 범위에서 원래 약속했던 기능이 여전히 필수인데 빠졌다면 parent는 FIX_REQUIRED로 유지하고 이유와 증거를 제출**한다. 원래 요구사항을 나중에 몰래 바꾸어 승인하지 않는다.
- `SOURCE_AND_EVIDENCE_MANIFEST.json`은 **두 계층으로 분리**한다.
  1. `infrastructure_source`: 각 소스 경로+정확한 `INFRA_SOURCE_SHA` 및 `git show` blob SHA256.
  2. `historical_evidence`: 원본 로그/QA 결과/이전 외부 검수 보고서의 정확한 *최초 또는 현재 포함 커밋 SHA*, 해시·증거 역할. 서로 다른 브랜치 커밋에 있는 파일을 `INFRA_SOURCE_SHA`에 있었다고 거짓 표기하지 않는다.
- 제출 대상은 패킷이 실제로 포함된 새 `PARENT_REVIEWED_SHA`. 패킷 작성 전 **검수 결과 파일을 생성하거나 PASS로 미리 채우지 않는다**.
- 필수 Git 오류 테스트: 없는 경로를 있는 것처럼 넣기 / SHA mismatch / 리뷰 이후 생성될 QA output을 입력 evidence에 포함하기 / 동일 역할 session 중복 / 서로 다른 SHA 리뷰는 반드시 거부한다. 실제 실행 결과 및 exit code 보존.

## 4. 공식 V3-002 부모 상태 전이와 두-키 독립 검수

1. `STUDIO_V3/queue.json`에서 부모 `V3-002=FIX_REQUIRED`, owner `PK_Producer`, reviewers `PK_QALead` + `PK_GameDirector`임을 확인. 전이:
   ```text
   V3-002: FIX_REQUIRED
       -> IN_PROGRESS (PK_Producer / new iteration)
       -> IN_REVIEW (PARENT_REVIEWED_SHA + verified manifest submitted)
       -> APPROVED only when BOTH newly invoked independent QA & Director PASS same SHA
              otherwise FIX_REQUIRED with issue and evidence
   ```
2. **Producer**가 공식 `TaskDispatcher.start_task/submit_work` / SQLite QueueStore와 정당한 revision/lease flow를 통해 상태를 전이한다. 부모가 owner=Producer인 것은 기존 정책이므로 **QA 또는 Director가 Producer와 독립적임을 증명**한다. Owner = reviewer 금지.
3. `FIX_REQUIRED -> IN_PROGRESS` 시의 iteration bump/기존 issue 처리, `active_branch` 제약, exact source SHA와 evidence hash verification을 검증한다. 정책이 요구하는 다른 필드를 막연히 채우지 말고 실제 구현을 따른다.
4. **신규** PK_QALead native `invoke_subagent` 세션이 frozen `PARENT_REVIEWED_SHA` 패킷과 실제 `INFRA_SOURCE_SHA` 및 기능/증거/리스크를 독립 검수한다. **QA가 PASS하기 전에 원본 V3-002 acceptance 충족 여부를 실제 판단해야 한다.**
5. **신규** PK_GameDirector native `invoke_subagent` 세션도 같은 frozen packet SHA를 검수하고 **상위 마일스톤 acceptance**를 판단한다. 별도 provider-authenticated session ID, parent conversation ID, terminal DONE, role, run ID, iteration, reviewed SHA, final structured JSON verdict, reviewer issue/evidence 필수.
6. QA FAIL 또는 Director FAIL, 누락된 독립성, parent 기능 미충족, 실제 provider unavailable, evidence mismatch, stale source -> **FIX_REQUIRED**. **Producer/Worker 자체 PASS 금지**, 기록의 `APPROVED` 문자열만 바꾸는 수동 JSON 패치 금지.
7. QA + Director가 모두 PASS하면 승인 로직을 통해 부모 `V3-002=APPROVED` 처리. Lease owner/expiry NULL 확인, SQLite 트랜잭션과 JSON snapshot 동기화, `TASK_APPROVED` append-only event, 동일 source SHA로 각 reviewer record 저장.
8. 정식 검수 후 발생한 reviewer JSON, provider provenance, 큐 export, events, final report는 **새 `PARENT_REVIEW_OUTPUT_SHA` 커밋**에 넣고 동결 source packet SHA에는 있었다고 기록하지 않는다. 이력 유지, no force-push.

## 5. V3-003 잠금 해제는 **별도 판단**

- 이번 task가 목표로 하는 것은 **V3-002 상위 마일스톤의 진짜 승인 여부 확인**이다.
- `V3-001`의 **외부 감사 정확성**은 통과했으나 게임 클라이언트는 3개 P1 미해결로 출시 불가. 이는 V3-003 **개발**을 시작할 이유이며, V3-001 감사의 승인과 혼동하지 않는다.
- `V3-002` parent가 공식 APPROVED가 되고 이번 parent rollup 결과의 외부 독립 검수가 확인되기 전까지 `V3-003`의 status는 **BLOCKED** 유지.
- 두 선행 마일스톤 승인과 외부 검수 증거가 일치하면 **별도 explicit authorization/queue state transition**으로 `V3-003`을 READY로 변경한다. 이번 작업에서 임의 `READY`로 바꿔 미승인 구현을 실행하지 않는다.
- 다음 실제 개발 범위 순서는: **Option C Z=0 (player/enemy/boss/hitboxes)** → **모바일 조작 UI** → **보스전 전경 시야 가림**. 그 뒤 P2/P3. 새 그래픽/코드 구현은 V3-003에서만.

## 6. 종료 조건

- [ ] V3-002 parent 최초 acceptance 전체에 대한 traceable PASS/PARTIAL/NOT_VERIFIED matrix.
- [ ] Child V3-002-CLOSE / external code acceptance와 parent evidence를 SHA-bound로 확인.
- [ ] 기존 라이브 IDE-native reject/fix/retest 및 infrastructure QA 기록이 독립적인지 검증.
- [ ] 원래 미입증 standalone headless autonomy를 성공으로 포장하지 않음.
- [ ] Frozen `PARENT_REVIEWED_SHA` 입력 패킷 파일 경로/해시가 실제 Git tree와 일치.
- [ ] 새로운 QA·Director 두 세션이 같은 frozen packet SHA를 검수하며 independent verdict를 제공.
- [ ] parent status를 정식 승인 게이트로만 갱신, events append-only, lease atomically cleared on APPROVED.
- [ ] reviewer output commit은 frozen packet 뒤에 별도 저장, 후속 보고서를 과거 source evidence라고 주장하지 않음.
- [ ] `CLIENT/Game/`, 11개 PNG, original `raw_frames.csv` 불변.
- [ ] V3-003은 이번 작업/외부 승인 전까지 BLOCKED. 게임 3건 P1 OPEN 유지.
- [ ] 미달 기준이 있으면 억지 PASS 대신 parent FIX_REQUIRED + 구체적 남은 issue 보고.

## 7. 기대 산출물 (실제 검증 후에만 생성)

```text
STUDIO_V3/tasks/V3-002-PARENT-APPROVAL.md
STUDIO_V3/reviews/V3-002-CLOSE-INDEPENDENT-REVIEW.md
STUDIO_V3/reviews/V3-001-ATTESTATION-CLOSE-INDEPENDENT-REVIEW.md
STUDIO_V3/evidence/V3-002-parent/
  PARENT_ACCEPTANCE_MATRIX.md
  PARENT_ROLLUP.md
  SOURCE_AND_EVIDENCE_MANIFEST.json
  verification/commands_and_raw_output.txt
  verification/invariants.json
  QA_PARENT_REVIEW.json             # review-output-only commit
  DIRECTOR_PARENT_REVIEW.json       # review-output-only commit
  PROVIDER_PROVENANCE.json          # review-output-only commit
  FINAL_PARENT_APPROVAL_REPORT.md   # review-output-only commit
STUDIO_V3/queue.json                # workflow export (not handwritten approval)
STUDIO_V3/events.jsonl              # append-only
STATE.md
```

## 8. 결과 보고 형식

```text
TASK: V3-002-PARENT-APPROVAL
Branch: studio/v3-002-parent-approval
Infrastructure source SHA: 214000678186b6ebb42349eeb28336b4dcfe0e42
Frozen parent review packet SHA: ...
Parent review output commit SHA: ...
Original V3-002 acceptance matrix: N verified / N partial / N not-verified
Live IDE-native multi-agent execution: VERIFIED / NOT_VERIFIED
Standalone/headless subagent orchestration: VERIFIED / NOT_VERIFIED (do not infer)
Frozen input evidence Git hash checks: N/N PASS
Native parent QA: session ..., target sha ..., PASS / FIX_REQUIRED / NOT_VERIFIED
Native parent Director: session ..., target sha ..., PASS / FIX_REQUIRED / NOT_VERIFIED
Queue V3-002 parent: APPROVED / FIX_REQUIRED
Lease cleared / events append-only: VERIFIED / NOT_VERIFIED
V3-001 audit evidence: EXTERNALLY ACCEPTED
Game client release: NOT_APPROVED (P1=3)
V3-003: BLOCKED
External parent rollup review: REQUESTED
Remaining infrastructure blockers: ...
Commit and original evidence links: ...
```

**실행 명령:** PK_Producer는 `studio/v3-002-parent-approval`을 Fetch 후 `STUDIO_V3/tasks/V3-002-PARENT-APPROVAL.md`를 읽는다. 기존 V3-002 acceptance에 대한 **근거 있는** parent rollup 패킷을 작성하여 Git에 먼저 동결한다. 그다음 새로운 PK_QALead/PK_GameDirector native 세션 두 개로 동일한 패킷 SHA와 `214000...` 구현 코드의 충족 여부를 검수하고, 정식 SQLite/dispatcher 승인 게이트에 반영한다. 성공하더라도 V3-003은 이 작업에서 자동 착수하지 않고 외부 검수를 요청한다. **새 시스템을 개발하거나 게임을 수정하지 않는다.**
