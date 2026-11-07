# ProjectKnight Studio V3 — Parent Milestone V3-002 Acceptance Matrix

**상위 마일스톤:** `V3-002` (Real Multi-Agent Orchestrator & Quality Rework Loop)  
**작업 ID:** `V3-002-PARENT-APPROVAL`  
**인프라 동결 소스 커밋:** `214000678186b6ebb42349eeb28336b4dcfe0e42`  
**평가 주체:** `PK_Producer` (Studio V3 총괄 Producer)  
**독립 검수:** `PK_QALead`, `PK_GameDirector` (신규 네이티브 세션)  
**일자:** 2026-11-07  

---

## 1. V3-002 최초 인수 기준 전수 추적 매트릭스 (12/12)

원래 지시서인 [`STUDIO_V3/tasks/V3-002.md`](../../tasks/V3-002.md) 제7절(Acceptance Gate)의 12개 항목 전체에 대한 실제 코드 경로, 동결 커밋 SHA, 테스트 로그, 검증 명령 및 판정을 아래와 같이 기록합니다:

| # | 원본 요구사항 (Original Acceptance Requirement) | 구현 코드 경로 / 증거 파일 | 기준 커밋 SHA | 검증 증거 / 로그 포인터 | 판정 |
| :-: | :--- | :--- | :---: | :--- | :-: |
| **1** | **Six custom agents discoverable by runtime**<br>6대 네이티브 에이전트 정의 | `.agents/agents/PK_*.md` (6개 파일 전수) | `2140006...` | 공식 YAML frontmatter, 도구 권한, 역할 분리 정의 완료 | **VERIFIED** |
| **2** | **At least 2 distinct role invocations with authentic IDs**<br>최소 2개 이상의 고유 역할 실질 호출 증빙 | `STUDIO_V3/evidence/V3-002-CLOSE/infrastructure_review/` | `2140006...` | `PK_QALead`(`437a514d`), `PK_GameDirector`(`786a9ea1`) 등 고유 세션 ID 및 산출물 보존 | **VERIFIED** |
| **3** | **Dispatch submits source revision & task evidence**<br>프롬프트 텍스트만이 아닌 소스 커밋 SHA 및 증거 제출 | `STUDIO_V3/orchestrator/dispatcher.py` (L180-260) | `2140006...` | `verify_committed_source_evidence()`, SHA-bound 매니페스트 필수 제출 강제 | **VERIFIED** |
| **4** | **QA can reject and automatically create fix task**<br>QA 반려 시 자동 결함 등록 및 재작업 전이 | `STUDIO_V3/orchestrator/dispatcher.py`<br>`handle_review_rejection()` | `2140006...` | `FIXTURE-V3-LIVE-003`에서 QA 반려 시 `ISSUE-V3-FIX-001` 자동 생성 및 `FIX_REQUIRED` 전이 입증 | **VERIFIED** |
| **5** | **FIX_REQUIRED -> worker iteration -> QA recheck loop**<br>반려 후 작업자 재수정 및 QA 재검증 사이클 완결 | `STUDIO_V3/orchestrator/runner.py`<br>`FIXTURE-V3-LIVE-003` 5단계 체인 | `2140006...` | Worker 구현 $\rightarrow$ QA 반려 $\rightarrow$ Worker 수정 $\rightarrow$ QA 통과 $\rightarrow$ Director 최종 승인 라이브 체인 완료 | **VERIFIED** |
| **6** | **Two independent reviewers must PASS before APPROVED**<br>독립 QA 및 Director 양자 승인 강제 게이트 | `STUDIO_V3/orchestrator/policies.py`<br>`can_approve()` | `2140006...` | `PK_QALead` 및 `PK_GameDirector`의 상이한 세션 ID 및 `PASS` 결과 등록 없이 승인 절대 차단 | **VERIFIED** |
| **7** | **Invalid/stale evidence & owner self-approval rejected**<br>무효/변조 증거 및 작업자 자체 승인 차단 | `STUDIO_V3/orchestrator/policies.py`<br>`test_review_gate.py` | `2140006...` | 작업자-검수자 동일 시 거부, 누락된 Git blob 및 위조 해시 차단 (부정 테스트 통과) | **VERIFIED** |
| **8** | **No job runaway, unbounded retries or queue corruption**<br>무한 루프 방지, 동시성 락, 큐 오염 방지 | `STUDIO_V3/orchestrator/queue_store.py`<br>`FileLock`, 원자적 트랜잭션 | `2140006...` | Lease 타임아웃, 원자적 갱신, 최대 재시도(2회) 및 최대 사이클(3회) 바운딩 | **VERIFIED** |
| **9** | **Windows launcher, runbook operating in dedicated workspace**<br>Windows 전용 런북 및 작업 공간 운영 체계 | `STUDIO_V3/docs/RUNBOOK.md`<br>`NATIVE_PRODUCER_RUNBOOK.md` | `2140006...` | PowerShell 기반 명령어, 독립 브랜치 및 worktree 운영 절차 확립 | **VERIFIED** |
| **10** | **Source assets/gameplay unchanged; legacy v2 retired**<br>게임 원본 코드 무수정 및 v2 폐기 보존 | `CLIENT/Game/` (0 lines changed)<br>`git diff a712236..HEAD -- CLIENT/Game/` | `a712236...` | 게임 엔진/씬/스크립트 완전 무수정, 원본 11 PNG 및 CSV 보존 | **VERIFIED** |
| **11** | **Deterministic tests PASS & live adapter smoke proof**<br>결정론적 단위 테스트 및 라이브 어댑터 증거 | `STUDIO_V3/tests/` (57 tests PASS)<br>`godot_tests_raw.log` (74 checks PASS) | `2140006...` | Python 테스트 57/57 통과 (19.1s), Godot 스테미너 픽스처 74/74 통과 | **VERIFIED** |
| **12** | **Provider limitations documented instead of invented**<br>기술적 한계 및 아키텍처 경계 정직한 문서화 | `STUDIO_V3/docs/NATIVE_PRODUCER_RUNBOOK.md`<br>`STUDIO_V3/reviews/V3-002-CLOSE-INDEPENDENT-REVIEW.md` | `2140006...` | IDE 네이티브 서브에이전트 브릿지 지원 확정, 파이썬 독립 헤드리스 실행은 미지원 경계로 명시 | **VERIFIED** |

---

## 2. 아키텍처 경계 및 검증 범위 한계 (Architectural Boundaries)

1. **IDE 네이티브 서브에이전트 vs 헤드리스 자동 실행**:
   - **검증 완료 (VERIFIED)**: Antigravity IDE 내부의 네이티브 서브에이전트(`PK_Producer`, `PK_ClientLead`, `PK_QALead`, `PK_GameDirector`)가 상호 호출되고, 트랜스크립트 로그를 `subagent_bridge.py`가 파싱하여 SQLite 작업 큐와 동기화하는 라이브 협업 체계.
   - **미입증 및 범위 외 (NOT_VERIFIED / OUT_OF_SCOPE)**: IDE 밖에서 파이썬 단독 프로세스가 CLI를 통해 에이전트를 완전 무인(Headless) 자동 스폰하는 기능은 현재 개발 환경에서 지원되지 않으며, 인프라 승인 범위에 포함하지 않음.
2. **Godot 74개 테스트의 범위**:
   - Godot 74개 테스트는 격리된 **스테미너 픽스처(Isolated Stamina Fixture)** 기능 검증이며, Stage 1의 실제 그래픽 렌더링 품질, 플레이어 조작감, 모바일 성능을 검증한 것이 아님.
3. **게임 출시 승인과의 분리**:
   - V3-002 인프라 마일스톤 승인은 **멀티 에이전트 개발 도구 및 거버넌스 체계**에 대한 승인이며, 게임 클라이언트 자체는 3건의 P1 결함(`ISSUE-01`, `ISSUE-02`, `ISSUE-07`)으로 인해 **`NOT_APPROVED`** 상태를 유지함.
