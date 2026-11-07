# V3-002-PARENT-GATE-RECONCILE — 최종 외부 검수 증거 보완 지시서 (External Delta Addendum)

**Task ID:** 기존 `V3-002-PARENT-GATE-RECONCILE` 유지 — **새 작업 ID / 새 에이전트 시스템 생성 금지**  
**작업 브랜치:** `studio/v3-002-parent-gate-reconcile` 유지  
**기준 커밋:** `c897f59b85cc001bd42e3c15c580e69f79b4fa5e`  
**원래 정정 검수 SHA:** `924641d335cc2ca308401cc659053e83e44a5136`  
**부모 승인 검수 SHA:** `a1c954e98acbfec95395be973e5b016339888300`  
**인프라 코드 동결 SHA:** `214000678186b6ebb42349eeb28336b4dcfe0e42`  
**외부 독립 검수 결과:** `STUDIO_V3/reviews/V3-002-PARENT-GATE-INDEPENDENT-REVIEW.md` — **FIX_REQUIRED (증거 출처·시각만)**  
**실행 주체:** PK_Producer 조정 / PK_ClientLead 증거 수집 / PK_QALead·PK_GameDirector 결과 확인  
**목표:** 이번 한 차례의 증거 정정으로 V3-002 외부 검수를 종결할 수 있도록 한다. **R4/R5·게임 기능·에이전트 오케스트레이터 코드 개발 금지.**

## 1. 이번 작업에서 바꾸지 않는 것

- `V3-001` 기준점 감사의 외부 수락, `V3-002-CLOSE` 구현 외부 수락을 되돌리지 않는다.
- `V3-002` 부모의 현재 **내부 APPROVED** 이력과 기존 실제 QA/Director 세션 ID는 보존한다. 다만 **외부 수락은 아직 FIX_REQUIRED**.
- `V3-002-PARENT-APPROVAL` wrapper의 `FIX_REQUIRED / SUPERSEDED` 정정 결과를 유지한다.
- `CLIENT/Game/`, `STUDIO_V3/orchestrator/`, `STUDIO_V3/tests/`, `.agents/agents/`, 원본 PNG/CSV, 기존 QA·Director 출력 및 `events.jsonl` 과거 행을 수정하지 않는다.
- `V3-003`은 **BLOCKED** 유지. 외부 재검수 완료와 이후 명시적인 상태 전이 전에는 Stage 1 구현을 시작하지 않는다.
- 기존 `V3-002-PARENT-GATE-RECONCILE=APPROVED` 내부 기록을 임의 재승인·덮어쓰기·별도 신규 작업으로 복제하지 않는다. 이번 산출물은 **외부 검수 정정 Addendum**이다.

## 2. P1-A — 6개 에이전트가 실제 IDE에서 열거된 원본 결과

기존 `AGENT_DISCOVERY_EVIDENCE.json`의 `ide_runtime_listed=true`는 **작성된 요약 데이터이지 실제 네이티브 목록 출력이 아니다.** “Found 20/22 subagents”라는 건수도 여섯 역할의 이름 증거가 아니다.

반드시 **실제 Antigravity 실행 환경**에서 지원되는 공식 UI/네이티브 도구로 에이전트 목록을 조회한다. `manage_subagents(Action="list")` 등 현재 IDE에 **실제로 노출된** 기능만 사용하고, 사용할 수 없는 `agy agents` 명령을 만들어 실행하거나 성공한 것처럼 기록하지 않는다.

검증 대상 이름 그대로:
```text
PK_Producer
PK_ClientLead
PK_QALead
PK_GameDirector
PK_GameDesign
PK_ArtDirector
```

**가장 좋은 자료:** 역할 6개 이름을 모두 포함하는 **원본 도구 응답** 또는 **편집하지 않은 IDE 화면 캡처**. 원본에는 도구명·동작 인자·IDE 버전·워크스페이스·로컬 시각 및 시간대·결과가 드러나야 한다. 수집된 원본을 별도 파일에 보관하고 SHA256 계산한다. 로그에 비밀정보가 있다면 먼저 원본 파일의 비공개 SHA256을 계산하고, 민감 정보만 삭제한 **명시적으로 sanitized** 버전을 Git에 저장한다. 삭제 사실·원본 보관 위치·검증 제한을 기록한다.

독립적으로 **각 역할의 존재를 열거하는 자료가 확보되지 못하면 6/6 VERIFIED라고 쓰지 않는다**. 그때는 실제 확인 수량/역할만 기록하고 `RUNTIME_DISCOVERY_NOT_INDEPENDENTLY_VERIFIED` 또는 `PARTIAL`로 표시한다. 여전히 상위 개발을 시작하려면 **원래 V3-002 요구사항을 수정할 권한이 있는 승인 주체의 명시적인 범위 제한/위험 수용 기록**이 있어야 한다. Director의 일반적인 PASS만으로 원래 미입증 조건까지 자동 VERIFIED가 되지 않는다.

산출물 예: `STUDIO_V3/evidence/V3-002-parent-gate/final-delta/IDE_AGENT_LIST_RAW.txt`(실제 텍스트가 있을 때만), `IDE_AGENT_DISCOVERY_PROOF.md`, `IDE_AGENT_LIST.png`(실제 캡처가 있을 때만).

## 3. P1-B — 과거 V3-002 부모 검수자의 **실제** 결과와 임시 해시 구별

**중요: 기존에 복원한 `apply_parent_approval.py`에 다음 코드가 있다.**
```python
hashlib.sha256(b"QA_PARENT_PASS").hexdigest()
hashlib.sha256(b"DIRECTOR_PARENT_APPROVED").hexdigest()
```
이는 `APPROVAL_INVOCATION_REGISTRY_SANITIZED.json`에 `result_hash`로 등록된 실제 값과 일치한다. **이 해시는 에이전트 원본 검수 출력의 해시가 아니라 코드의 상수 문자열 해시다.**

원래 부모 검수 세션:
- QA `3aa4a1d0-4972-4750-852f-04e2675be74f`
- Director `178b4ee7-d8b6-4b9b-8310-4db576501a4b`
- 검수한 소스 SHA `a1c954e98acbfec95395be973e5b016339888300`
- 부모 대화 `c1845c39-fd7b-445c-9a68-644aaac576ff`

수행 작업:
1. 로컬 Antigravity `<brainDir>/<session-id>/.system_generated/logs/transcript.jsonl` 또는 실제 provider-native 세션 메타에서 **원래 두 세션의 종료 기록과 실제 최종 검수 메시지**를 읽는다. 파일이 없으면 `ORIGINAL_TRANSCRIPT_NOT_AVAILABLE`이라고 기록한다.
2. **원본 transcript 바이트** 또는 provider가 제공한 최종 verdict payload의 **실제 바이트**를 기준으로 SHA256을 계산한다. 해시 대상(전체 transcript / 마지막 구조화 출력 / decoded field)을 반드시 명시한다. `result_hash`가 예전 임시 상수와 다르다는 점을 정정표로 제시한다.
3. 각 세션에 대해 `session_id`, 역할, 부모 대화, task ID, iteration, 검수 SHA, 종료상태, 실제 verdict 내용, 원본 경로, 정확한 생성/수정 시각과 시간대를 연결한다.
4. 개인 정보·시스템 비밀이 들어 있을 수 있으므로 전체 비공개 transcript를 GitHub에 무작정 게시하지 않는다. 최종 판정의 필요한 부분만 민감정보 제거 후 발췌해 커밋하고 **원본 해시와 발췌본 해시를 별도** 표시한다. `sanitized excerpt`를 원본 바이트와 동일하다고 주장하면 FAIL.
5. 기존 `queue.db` 과거 `result_hash`, 리뷰 타임스탬프, `events.jsonl`을 소급 변경하지 않는다. `LEGACY_PROVIDER_RESULT_HASH_PLACEHOLDER` 성격의 **명시적 append-only 정정 기록**을 추가하고, 이후 유효 검증 근거를 새 문서/이벤트로 연결한다. 정책상 event append 시 백업과 DB/JSON sync를 확인한다.
6. 세션의 실제 최종 출력 확보에 실패하면 **`PROVIDER_OUTPUT_HASH_NOT_VERIFIED`**와 영향 범위를 명시한다. 불명확한 PASS를 새로 만들어 채우거나 기존 상수 문자열 해시를 다시 유효 증거라고 말하지 않는다. 필요할 경우 **최대 한 번**의 진짜 네이티브 독립 재검증(동일 범위, 새로운 세션, 새 명시적 증거 동결)을 수행할 수 있으나, 예전 세션을 재실행했다고 속이지 않는다.

산출물 예: `PARENT_PROVIDER_OUTPUT_ATTESTATION.md`, `PARENT_PROVIDER_OUTPUT_HASHES.json`, `PARENT_PROVIDER_SANITIZED_EXCERPTS.md`(안전한 경우에만).

## 4. P1-C — 신규 QA/Director/이벤트의 시간대 정합성

현재 `PROVIDER_GATE_PROVENANCE.json`에 다음과 같이 적혀 있다.
```text
PK_QALead   2026-11-08T01:22:11Z -> 2026-11-08T01:26:45Z
PK_Director 2026-11-08T01:22:21Z -> 2026-11-08T01:25:00Z
EventLog    2026-11-07T16:28:09Z  (신규 승인 이벤트)
```

표기 그대로면 이벤트가 검수보다 앞서 발생하므로 **시간 계보가 모순**이다. 한국시간 `2026-11-08 01:22 KST`는 UTC로 `2026-11-07 16:22Z`이나, **현재 값이 원래 KST였는지는 검증 전까지 가정일 뿐**이다.

1. 실제 제공자 메타데이터/전사 로그의 **원본 시간 문자열과 타임존/UTC offset**을 읽어 두 새 세션의 시작·종료 시각을 입증한다.
2. 앱/OS/로그 작성 경로가 어느 시각을 사용했는지 확인한다. 단순히 9시간 빼서 보고서 숫자를 맞추지 않는다.
3. 확정된 경우 **원래 문자열 + 출처 + 원본 시간대 + 환산 UTC + 검수 종료 → 이벤트 기록 순서**를 정정표로 작성한다. 기존 `PROVIDER_GATE_PROVENANCE.json`은 변경하지 않고 `TIMEZONE_NORMALIZATION_ADDENDUM.md`를 추가한다.
4. 실제 시간대 소스를 확인할 수 없으면 `TIMEZONE_ORIGIN_NOT_VERIFIED`로 남기고 승인 타임라인의 신뢰성에 어떤 영향이 있는지 밝힌다.
5. 이벤트 이전 로그 36행 및 현재 42행은 그대로 보존한다. 정정이 필요하면 **행 삭제·수정 없이 append-only 이벤트**로 연결한다.

## 5. 원본 12개 승인 기준의 이름과 순서를 정확히 보존

원본 `STUDIO_V3/evidence/V3-002-parent/PARENT_ACCEPTANCE_MATRIX.md`의 항목은 다음과 같다.

1. Six custom agents discoverable by runtime.
2. At least 2 distinct role invocations with authentic IDs.
3. Dispatch submits source revision & task evidence.
4. QA can reject and automatically create fix task.
5. FIX_REQUIRED → worker iteration → QA recheck loop.
6. Two independent reviewers must PASS before APPROVED.
7. Invalid/stale evidence & owner self-approval rejected.
8. No job runaway, unbounded retries or queue corruption.
9. Windows launcher, runbook operating in dedicated workspace.
10. Source assets/gameplay unchanged; legacy v2 retired.
11. Deterministic tests PASS & live adapter smoke proof.
12. Provider limitations documented instead of invented.

**기존 `ACCEPTANCE_MATRIX_ADDENDUM.md`은 #4부터 일부 이름을 다른 기준으로 바꾸어 11/12 점수를 산출했다.** 이는 원본 마일스톤 기준의 정확한 비교가 아니다.

- `ORIGINAL_12_CRITERIA_DELTA.md`를 추가하여 **위 12개 ID/명칭/순서를 그대로 유지**하고 각 행에 원본 평가, 최종 평가(`VERIFIED` / `PARTIAL` / `NOT_VERIFIED`), 원본 SHA 및 신규 증거를 연결한다.
- 기존 `a1c954...` 매트릭스 및 `924641...` addendum은 **역사적 불변 문서**로 보존한다. 이번 정정표만 외부 검수의 최신 유효 해석으로 사용한다.
- `11/12 VERIFIED + 1 QUALIFIED PASS`는 실제 증거가 그 수치를 지지할 때만 유지한다. 런타임 증거 부족시 완성도 산정에 실제 미검증 상태를 반영한다.

## 6. 두 커밋 규칙, 승인, 외부 재검수

**첫 번째 커밋: `FINAL_DELTA_EVIDENCE_SHA`**
- 위 네 영역의 원본 자료, 원본 출처 정보, 정정표 및 실제 체크 명령·종료 코드를 먼저 커밋한다.
- 개인 정보/인증값을 제외하고 파일별 SHA256을 계산한다.
- 실제 찾지 못한 파일은 생성하지 않는다. 없는 근거를 PASS라고 작성하지 않는다.
- 이 SHA 이전에 존재하지 않는 `QA_FINAL_DELTA_REVIEW`, `DIRECTOR_FINAL_DELTA_REVIEW`를 입력 증거로 포함하지 않는다.

**필요한 경우 검수**
- 기존 `V3-002-PARENT-GATE-RECONCILE` 작업 ID를 재사용하되 **기존 APPROVED 이력을 덮어쓰지 않는다**. 정책상 공식 신규 iteration/review가 필요하면 실제 지원하는 정식 전이를 수행하고 왜 필요한지 기록한다.
- 새로 수집한 증거를 이전 QA/Director가 이미 검수했다고 소급 주장하지 않는다. 전자서명 수준의 새로운 증거가 필요할 때만 새로운 **별개** PK_QALead/PK_GameDirector 네이티브 검수 세션을 호출한다. 검수자 두 명은 동일한 `FINAL_DELTA_EVIDENCE_SHA`와 정확한 작업 범위를 검수한다.
- 원본 검수 결과가 부족하면 `FIX_REQUIRED`라고 정직하게 남긴다. 승인 권한자가 **범위 명확한 위험 수용**을 했다면 근거, 한계, 허용 범위 및 V3-003 조건을 표시한다.
- 새 검수 출력 JSON/최종 보고서/정정 이벤트·queue snapshot은 **후속 별도 `FINAL_DELTA_OUTPUT_SHA` 커밋**에 넣는다. 과거 동결 SHA의 입력 자료로 미래 파일을 연결하지 않는다.
- 과거 리뷰/이벤트/동결 증거의 SHA·내용은 보존한다.
- 외부 리뷰는 **이번 증거 delta만** 다시 받는다. 인프라 재설계, 신규 wrapper 작업, Godot 재측정, 새로운 4분 벤치마크는 금지.

## 7. 산출물 및 stop rule

```text
STUDIO_V3/tasks/V3-002-PARENT-GATE-FINAL-EVIDENCE-ADDENDUM.md
STUDIO_V3/reviews/V3-002-PARENT-GATE-INDEPENDENT-REVIEW.md
STUDIO_V3/evidence/V3-002-parent-gate/final-delta/
  IDE_AGENT_DISCOVERY_PROOF.md
  IDE_AGENT_LIST_RAW.txt                # 진짜 원본 도구 응답을 확보한 경우에만
  PARENT_PROVIDER_OUTPUT_ATTESTATION.md
  PARENT_PROVIDER_OUTPUT_HASHES.json    # 실제 출력/원본 해시인 경우에만
  PARENT_PROVIDER_SANITIZED_EXCERPTS.md # 비밀정보 제거 완료한 경우에만
  TIMEZONE_NORMALIZATION_ADDENDUM.md
  ORIGINAL_12_CRITERIA_DELTA.md
  COMMANDS_AND_RESULTS.txt
  QA_FINAL_DELTA_REVIEW.json            # 검수 후 OUTPUT commit에만
  DIRECTOR_FINAL_DELTA_REVIEW.json      # 검수 후 OUTPUT commit에만
  FINAL_EXTERNAL_REVIEW_REQUEST.md      # 검수 후 OUTPUT commit에만
```

중단 기준: 실제 원본 에이전트 목록/검수 응답/시각 출처를 한 번의 증거 수집으로 확보하지 못하면, 결손을 `NOT_VERIFIED`로 보고하고 **추가 증거 루프를 만들지 말고** 외부 검수에 남은 불확실성을 그대로 제출한다. 승인 조건을 충족하지 못했다면 `V3-003`은 BLOCKED. 필요한 경우 **사용자가 명시적으로 위험과 범위를 수용한 후** 개발 착수 게이트를 따로 결정하게 한다.

## 최종 실행 명령

`studio/v3-002-parent-gate-reconcile`를 Fetch하고 이 문서와 외부 독립 검수 보고서를 읽는다. **새 작업 ID 생성 금지.** 이전 세 가지 결함 중 wrapper 승인 정정은 이미 해결됐으므로 건드리지 않는다. **실제 6개 에이전트 열거 자료 / 원래 부모 QA·Director 최종 출력과 임시 해시의 차이 / 신규 QA·Director UTC 시각 출처 / 원본 12개 매트릭스 동일성**만 한 차례 증거 보완한다. 실제 확인한 데이터만 1차 동결 커밋에 넣고 필요한 신규 검수는 그 다음 진행한다. 외부에 delta-only 검수를 요청한다. `CLIENT/Game/` 등 기존 구현 코드는 수정하지 않는다. `V3-003`은 외부 수락과 별도 착수 승인 전까지 BLOCKED.
