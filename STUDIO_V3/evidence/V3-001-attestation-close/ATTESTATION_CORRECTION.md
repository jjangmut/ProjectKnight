# ProjectKnight Studio V3 — Git 증거 계보 및 과거 귀속 정정서 (Attestation Correction)

**작업 ID:** `V3-001-ATTESTATION-CLOSE`  
**책임자:** `PK_Producer` (Studio V3 총괄)  
**기술 검증:** `PK_ClientLead`  
**독립 검수:** `PK_QALead`, `PK_GameDirector`  
**기준 커밋:** `fa5d900f8e9cb6f0853af85bc7bf09e6725951ed`  
**동결 원본 증거 SHA:** `c55714745ac15776d5ffa449da6058da3dd777ea`  
**사후 검수 보고서 최초 커밋 SHA:** `0d99e2b0da5ecd30cff8641348ba4ed3e897423b`  
**일자:** 2026-11-07  

---

## 1. 정정 배경 및 문제 정의

이전 태스크인 `V3-001-EVIDENCE-RECONCILE`에서 성능 텔레메트리 해석(60Hz 물리 틱 vs 240FPS 렌더 루프), 7대 정본 결함 백로그 확정, 11개 원본 캡처 매니페스트 구축 등 핵심 기술적·통계적 정합성이 모두 완비되었습니다.

그러나 외부 독립 검수([`V3-001-RECONCILE-INDEPENDENT-REVIEW.md`](../reviews/V3-001-RECONCILE-INDEPENDENT-REVIEW.md))에서 다음과 같은 중대한 **Git 증거 귀속(Evidence Attestation) 불일치**가 지적되었습니다:

1. **사후 생성 파일의 선행 커밋 귀속 오류**:
   - `QA_ADDENDUM.md`, `DIRECTOR_ADDENDUM.md`, `FINAL_RECONCILIATION_REPORT.md` 3개 파일은 동결 커밋(`c557147`)을 검수한 후 생성되어 커밋 `0d99e2b`에 처음 포함되었습니다.
   - 그러나 `queue.json`의 `evidence_manifest`와 양쪽 검수자의 `evidence_hashes`에 위 3개 파일이 사전 동결 커밋 `c557147`에 존재하는 것처럼 기록되었습니다.
2. **인과율 및 무결성 위반**:
   - `git cat-file -e c557147...:<3개 파일>` 실행 시 Git blob이 존재하지 않아 exit code 128로 실패합니다.
   - 즉, 검수자가 검수 대상 커밋에 존재하지 않던 미래 파일의 해시를 소스 증거로 확약하는 인과적 모순이 발생했습니다.

---

## 2. 정정 원칙 (2-Tier Git Evidence Model)

본 정정 작업은 다음 5대 절대 원칙 하에 수행됩니다:

1. **소급 위조 금지 (No Retroactive Forgery)**:
   - 과거 `events.jsonl`의 기존 행이나 `queue.json`의 과거 검수 세션 ID, 타임스탬프, 역사적 내부 승인 기록을 임의로 삭제하거나 변조하지 않습니다.
2. **엄격한 2계층 증거 분리 (Strict 2-Tier Evidence Architecture)**:
   - **계층 A (Reviewed Source Evidence)**: `c55714745ac15776d5ffa449da6058da3dd777ea`에 실제 존재하는 7개 파일만 인정하며, [`REVIEWED_SOURCE_MANIFEST.json`](./REVIEWED_SOURCE_MANIFEST.json)에 분리 수록합니다.
   - **계층 B (Review Output Evidence)**: 검수 후 생성된 3개 보고서는 `first_containing_commit: 0d99e2b0da5ecd30cff8641348ba4ed3e897423b` 및 `created_after_review_source_sha: c55714745ac15776d5ffa449da6058da3dd777ea`를 명시하여 [`REVIEW_OUTPUT_MANIFEST.json`](./REVIEW_OUTPUT_MANIFEST.json)에 분리 수록합니다.
3. **Git Blob 기반의 실질 검증**:
   - 현재 로컬 작업 디렉터리에 파일이 존재한다는 사실만으로 커밋에 포함된 것으로 간주하지 않고, 반드시 `git cat-file`, `git show`, `git ls-tree`를 통해 검증된 blob 바이트만을 대상으로 SHA256을 확정합니다.
4. **Append-Only 정정 감사 이벤트 기록**:
   - 잘못된 증거 바인딩을 식별하고 대체하는 공식 `EVIDENCE_ATTESTATION_CORRECTED` 이벤트를 `events.jsonl`에 추가합니다.
5. **2단계 커밋 분리 (Two-Commit Sequence)**:
   - 검수 전 정정 증거를 먼저 커밋하여 `CORRECTED_EVIDENCE_SHA`를 동결한 후 검수를 수행하고, 신규 검수 결과는 별도의 `REVIEW_OUTPUT_COMMIT_SHA`로 기록하여 자기 참조 오류를 구조적으로 차단합니다.

---

## 3. Git 증거 실사 검증 결과

### A. 동결 커밋 `c55714745ac15776d5ffa449da6058da3dd777ea`
- `git ls-tree -r --name-only c55714745ac15776d5ffa449da6058da3dd777ea -- STUDIO_V3/evidence/V3-001-reconcile/`
  1. `STUDIO_V3/evidence/V3-001-reconcile/CAPTURE_MANIFEST.json`
  2. `STUDIO_V3/evidence/V3-001-reconcile/GAMEPLAY_ISSUE_BACKLOG.md`
  3. `STUDIO_V3/evidence/V3-001-reconcile/ISSUE_RECONCILIATION.md`
  4. `STUDIO_V3/evidence/V3-001-reconcile/performance/PERFORMANCE_METHOD.md`
  5. `STUDIO_V3/evidence/V3-001-reconcile/performance/analysis.py`
  6. `STUDIO_V3/evidence/V3-001-reconcile/performance/analysis_output.json`
  7. `STUDIO_V3/evidence/V3-001-reconcile/performance/benchmark_source/benchmark_stage1_windowed.gd`
  *(정확히 7개 파일 존재 확인)*

- 사후 생성 파일 부재 검증 (`git cat-file -e c557147...:<file>`):
  - `QA_ADDENDUM.md`: **Exit Code 128 (정상 실패 — 커밋 내 부재 확인)**
  - `DIRECTOR_ADDENDUM.md`: **Exit Code 128 (정상 실패 — 커밋 내 부재 확인)**
  - `FINAL_RECONCILIATION_REPORT.md`: **Exit Code 128 (정상 실패 — 커밋 내 부재 확인)**

### B. 사후 보고서 커밋 `0d99e2b0da5ecd30cff8641348ba4ed3e897423b`
- `git diff --name-status c557147... 0d99e2b...`:
  - `A STUDIO_V3/evidence/V3-001-reconcile/QA_ADDENDUM.md`
  - `A STUDIO_V3/evidence/V3-001-reconcile/DIRECTOR_ADDENDUM.md`
  - `A STUDIO_V3/evidence/V3-001-reconcile/FINAL_RECONCILIATION_REPORT.md`
  - `M STUDIO_V3/events.jsonl`
  - `M STUDIO_V3/queue.json`
- 사후 생성 파일 실존 검증 (`git cat-file -e 0d99e2b...:<file>`):
  - `QA_ADDENDUM.md`: **Exit Code 0 (존재 확인)**
  - `DIRECTOR_ADDENDUM.md`: **Exit Code 0 (존재 확인)**
  - `FINAL_RECONCILIATION_REPORT.md`: **Exit Code 0 (존재 확인)**

---

## 4. 정정 조치 명세

1. **매니페스트 이원화**:
   - 7개 원본 증거: [`REVIEWED_SOURCE_MANIFEST.json`](./REVIEWED_SOURCE_MANIFEST.json) (Source SHA: `c55714745ac15776d5ffa449da6058da3dd777ea`)
   - 3개 사후 보고서: [`REVIEW_OUTPUT_MANIFEST.json`](./REVIEW_OUTPUT_MANIFEST.json) (First containing commit: `0d99e2b0da5ecd30cff8641348ba4ed3e897423b`)
2. **이벤트 로그 정정 기록**:
   - `events.jsonl`에 `EVIDENCE_ATTESTATION_CORRECTED` 이벤트를 append-only로 등록.
   - 기존의 잘못된 10개 파일 일괄 바인딩을 무효화하고 정확한 7개 소스 / 3개 사후 보고서 계보로 대체.
3. **신규 독립 검수 실행**:
   - 신규 서브에이전트 세션 `PK_QALead` 및 `PK_GameDirector`를 호출하여 동결된 `CORRECTED_EVIDENCE_SHA` 커밋을 독립 검수.
   - 검수 결과 파일은 후속 커밋인 `REVIEW_OUTPUT_COMMIT_SHA`에 저장.
