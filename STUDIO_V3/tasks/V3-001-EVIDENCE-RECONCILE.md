# TASK V3-001-EVIDENCE-RECONCILE — 실제 게임 기준점 감사 증거 정합성 보완

**상태:** READY — 지시서 등록 단계, 수정/재측정 미실행  
**우선순위:** P0 (V3-001 외부 독립 검수 보완)  
**작업 브랜치:** `studio/v3-001-evidence-reconcile`  
**기준 증거 커밋:** `studio/v3-001-playable-baseline@5c25a98084ba6885e1b9b4e2bac40a9c74568473`  
**게임 감사 대상 소스 SHA:** `a71223615d0b77e36dd85edb24e138fc67ecc140`  
**독립 검수 원문:** `STUDIO_V3/reviews/V3-001-INDEPENDENT-REVIEW.md`  
**총괄:** PK_Producer / **자료 보완:** PK_ClientLead / **독립 검수:** PK_QALead + PK_GameDirector  
**범위:** 증거 분석·계측 방법 재현·감사 문서 정합성·신규 검수. **게임 개발/리팩터링 아님.**

## 목표

V3-001에서 이미 확보한 실제 Godot Stage 1 실행 기록, 11개의 1280×720 PNG, 14,404행 성능 CSV, 입력 실행 로그 및 **Option C 디자인 결정**을 보존하고, 외부 독립 검수에서 발견한 4가지 불일치를 한 차례의 좁은 범위 수정으로 마무리한다.

**주의: 이번 작업의 승인 대상은 '기준점 감사의 정확성'이지 '게임 품질 또는 Android 출시 준비 완료'가 아니다.** 코드에 남아 있는 P1 문제는 V3-003 이후 개발 작업에서 해결해야 한다. QA PASS를 얻으려고 문제를 숨기거나 게임 버그를 삭제하지 않는다.

## 0. 작업 시작 및 이력 보전

1. `origin/studio/v3-001-evidence-reconcile`를 Fetch/Checkout하고 Git branch, 현재 SHA, working tree 상태를 기록한다. 되도록 독립 Git worktree를 사용한다.
2. `STUDIO_V3/reviews/V3-001-INDEPENDENT-REVIEW.md`, `STUDIO_V3/tasks/V3-001.md`, `STUDIO_V3/PROTOCOL.md`, 현재 `STUDIO_V3/evidence/V3-001/` 일체를 읽는다.
3. `CLIENT/Game/` 아래 소스/씬/그래픽/사운드/프로젝트 설정/밸런스를 **수정하지 않는다**. `main`, `integration`을 건드리거나 Force Push 하지 않는다.
4. **기존 원본** `raw_frames.csv`, `performance.json`, 11개 PNG, 실행 로그, 기존 QA/Director 보고서와 `events.jsonl`은 덮어쓰지 않는다. 신규 분석 결과와 정정 이력은 별도 폴더 `STUDIO_V3/evidence/V3-001-reconcile/`에 생성한다.
5. 로컬 `queue.db`가 있으면 안전하게 백업 후 기존 `queue.json`와 정합성을 확인한다. 이력을 지우거나 DB를 새로 만들어 검수 PASS를 강제로 얻지 않는다.
6. 현재 `V3-001.status=APPROVED`는 **내부 Two-Key 검수 결과라는 역사적 상태**로 보존하고, 신규 보완 작업 `V3-001-EVIDENCE-RECONCILE`에서 **외부 FIX_REQUIRED 해결 여부**를 따로 관리한다. 기존 승인 기록을 아무 이벤트 없이 되돌리거나 덮어쓰지 않는다.

## P1-A — PC FPS 계측 정의와 실제 테스트 부하의 검증

**기존 문제:** `raw_frames.csv`는 14,404행, `dt_ms` 약 16.66 ms로 약 60회/초이지만 `fps` 열은 이동/일반전투/보스 구간에서 239~240을 보고한다. 보고서의 60.03 평균 FPS, 59.46 1% Low는 `dt_ms` 기반 값이다. `median_fps=240`과도 모순처럼 보인다. 또한 4개 구간의 draw calls/nodes가 거의 일정해 실제 행동 부하와의 연결 증거가 필요하다.

**수행할 작업:**
1. 과거 실행에 사용했다는 `benchmark_stage1_windowed.gd` 및 실행용 Python/PowerShell 스크립트가 로컬 scratch에 실제로 남아 있다면 **원문 사본**을 증거에 추가하고 생성 시각, 경로, 해시와 당시 호출 커맨드를 명확하게 기록한다. 없으면 **MISSING**으로 표기하며 새 코드를 과거에 사용했다고 주장하지 않는다.
2. `Godot Engine.get_frames_per_second()`, `Performance.TIME_FPS`, `_process(delta)`, 타이머 샘플 간격 등 **실제로 사용한 API/샘플링 방식**을 원본 코드에 근거해 확인한다. 239~240 FPS와 16.7 ms의 이유를 자료 기반으로 설명한다.
3. 기존 CSV는 그대로 두고 **별도 재현 가능한 분석 스크립트**로 행 수, 구간별 시간, dt 분포, fps 열 분포, 중앙값, p95/p99, 1% Low 계산 방법과 이상치 처리 기준을 검증한다. 숫자 맞추기용 데이터 보정 금지.
4. 게임 화면이 60Hz 간격으로 샘플링된 것이라면 지표를 `sampling interval 60 Hz`로 명시하며 **실제 렌더링 FPS 60 및 1% Low 59.46을 실측했다고 단정하지 않는다.** 반대로 원본 프로파일러 기록으로 실제 60fps 렌더링이 입증되면 어떤 프레임/캡 구조인지 설명한다.
5. `idle/walking/normal_combat/boss_combat` 구간에서 플레이어 입력, 적/보스 존재, 실제 전투 상태/스폰, draw call 및 node 변화, 관련 시간 태그를 연결하는 근거를 제시한다. 단순히 CSV의 `sector` 문자열만으로 해당 구간이 실제 보스 전투였다고 판단하지 않는다.
6. 검증이 불가능하면 `PC_FRAME_RENDER_METRIC_NOT_VERIFIED`와 `BOSS_STRESS_NOT_VERIFIED`로 **보수적으로 수정**한다. Android는 `NOT_TESTED` 유지. 과거 60FPS PASS 주장에 근거가 없으면 철회한다.
7. 정말 새 데이터가 필요하면 **최대 1회** 재측정한다. 이때 실제 **windowed** Godot Stage 1을 켜고 입력/보스/스폰 상태를 기록하는 스크립트를 먼저 Commit 한 뒤, 정확한 코드 SHA에 대한 raw stdout/stderr, 시각, 프로파일러 원본을 저장한다. 실행이 불가하면 추정값을 작성하지 않는다.

**산출물:** `performance/PERFORMANCE_METHOD.md`, `performance/analysis.py` (또는 동일하게 재현 가능한 스크립트), `performance/analysis_output.json`, `performance/benchmark_source/` (존재한다면), `performance/retest/` (실제 재측정 시에만 생성).

**필수 통과조건:** `fps=240`와 `dt≈16.7ms` 차이를 설명하거나 명확한 NOT_VERIFIED로 정정. 전투 구간별 실제 부하 입증 여부 명시. 계산/스크립트/실행 커맨드·원본 해시 재현 가능.

## P1-B — 7개 게임 결함의 단일 정본과 상태 정리

**기존 문제:** `ISSUES.md` 요약표에 `ISSUE-V3-001-07`이 3번 반복된다. 초기 BASELINE/QA는 6건(2 P1, 2 P2, 2 P3), 최종 결과/Director는 7건(3 P1, 2 P2, 2 P3)이라고 썼다. `ISSUE-V3-001-02`는 **Option C 결정만 완료**, 실제 `SideQVPlayer`/Enemy 등의 Z=0 고정은 아직 미구현인데 RESOLVED로 표기되어 있다.

**수행할 작업:**
1. `V3-001` 기존 원본은 감사이력으로 보존하고, 보완 폴더에 **고유 Issue ID 7개를 하나씩** 기록하는 `GAMEPLAY_ISSUE_BACKLOG.md` / JSON을 작성한다.
2. 상태는 다음 사실을 반영한다.
   - `ISSUE-V3-001-01`: P1 OPEN — 모바일 가상 이동/액션 버튼 미구현.
   - `ISSUE-V3-001-02`: P1 `DECIDED / IMPLEMENTATION_PENDING` — Option C 채택, **Z=0 게임 코드 수정 및 재테스트 전에는 RESOLVED 아님**.
   - `ISSUE-V3-001-03`: P2 OPEN — 게임 부팅 `add_child()` 오류.
   - `ISSUE-V3-001-04`: P2 OPEN — Sprite3D 접지/깊이 시각 문제.
   - `ISSUE-V3-001-05`: P3 OPEN — 보스 차지 전조.
   - `ISSUE-V3-001-06`: P3 OPEN — 스테이지 결과 화면.
   - `ISSUE-V3-001-07`: P1 OPEN — 보스전 전방 벽/기둥 시야 차단.
3. 7개 고유 이슈의 **3 P1/2 P2/2 P3**를 기준으로 정정 요약문을 추가한다. 원본 `ISSUES.md`는 증거로 보존하고 중복 문제를 **정정 Addendum**에서 공개적으로 설명한다.
4. `V3-001`의 `queue.json` `issues: []`는 **감사 작업 자체의 검수 차단 이슈가 0개**라는 뜻으로만 설명될 수 있다. 이것을 '게임 결함 0건'으로 쓰지 않는다. 게임 이슈는 별도 backlog에 보존하고 `V3-003` 개발 입력으로 전달한다.
5. `V3-001` 감사가 적절하게 완료될 수 있어도 게임의 P1 3건은 남아 있다는 차이를 `ISSUE_RECONCILIATION.md`에 명시한다.

## P1-C — 미래 파일 해시를 앞선 검수자가 서명한 불일치 해결

**기존 문제:** PK_QALead 검수 시점보다 뒤에 Director가 `ISSUE-V3-001-07`을 추가했는데, 저장된 QA 증거 목록에는 이후 작성/변경된 `ISSUES.md`, `DIRECTOR_REVIEW.md`, `FINAL_EXECUTION_REPORT.md` 최종 해시까지 연결돼 있다. 실제 QA 당시 확인한 버전과 현재 매니페스트의 동일성을 입증하지 못한다.

**수행할 작업:**
1. **기존 타임스탬프/검수 레코드/파일을 소급 수정하거나 새 해시를 과거 검수자의 것처럼 기입하지 않는다.**
2. 성능 분석/이슈 정정/캡처 인덱스를 모두 마친 뒤, **최종 증거 소스 커밋 `EVIDENCE_SHA`를 확정**한다.
3. **새로운 PK_QALead 세션**이 `EVIDENCE_SHA`의 실제 보완 문서, 일치하는 원본 버전, 성능 분석과 고유 7개 이슈를 검수하도록 한다. 해시·검수한 SHA·세션 ID·종료 상태·부모 대화 ID·run_id·timestamp를 명시한다.
4. **새로운 PK_GameDirector 세션**은 동일 `EVIDENCE_SHA`를 확인하며, 기존 Option C를 유지/변경하는 근거와 향후 게임 이슈 P1 우선순위를 판단한다.
5. 두 검수 결과는 최종 파일들의 실제 해시를 확인한 뒤 append-only audit 이벤트로 기록한다. 리뷰 산출물은 필요하면 **별도의 evidence-only commit**에 보관하고, 검수 대상 SHA와 구분한다. 미래 파일 자체를 과거 검수 해시에 포함시켜 순환 검수/자기 참조를 만들지 않는다.
6. 검수 결과 제출은 현재 Studio V3 guard/SQLite workflow를 통과해야 하며, 전용 보완 Task `V3-001-EVIDENCE-RECONCILE`만 정상 승인 후보로 삼는다. QA/Director를 작업자와 분리한다. 문서나 스냅샷의 status 문자열만 변경해 승인하지 않는다.
7. 검수 전 `QA PASS`를 미리 작성하지 않는다. 리뷰가 불가능하면 `NOT_VERIFIED`로 두고 명시적으로 멈춘다.

## P2-D — PNG 증거의 식별 가능성과 외부 시각 검토

1. 기존 11개 `captures/originals/*.png`는 무편집으로 보존한다.
2. 각 PNG에 대해 실제 파일 바이트의 `sha256`, 해상도, 실제 바이트 길이, 파일/증거 커밋, 원래 인덱스 설명을 별도 `CAPTURE_MANIFEST.json`에 기록한다.
3. 기존 메타 정보의 unique colors 수치만으로 **'실제 화면/비합성'을 암호학적으로 증명했다고 주장하지 않는다**.
4. 외부 GitHub 텍스트 도구는 이미지 바이너리를 보여주지 못하므로, 필요한 경우 원본 11개 중 핵심 4개(`01_stage_entry.png`, `05_attack_impact.png`, `08_boss_telegraph.png`, `09_boss_combat.png`)를 대화에 별도 첨부해 실제 화면을 확인할 수 있도록 한다. 이미지를 새로 만들거나 원본을 교체하지 않는다.
5. QA/Director는 **실제 PNG 픽셀을 열어** 화면의 전방 벽 가림, 캐릭터 접지, 모바일 UI 누락을 확인하고 파일별 관찰 기록을 남긴다. 외부 직접 검토가 불가할 경우 외부 검수 결과는 `PIXEL_LEVEL_NOT_INDEPENDENTLY_VERIFIED`로 남긴다.

## 비핵심 영역 — 이번 작업에서 금지

- `CLIENT/Game/` 이동 X/Z/Y 로직 수정, Z=0 고정, 모바일 버튼 생성, 보스/카메라/배경 개선
- Stage 2~5, Android 출시 패키지, 그래픽 리소스 변경
- 또 다른 Studio V3 오케스트레이터/R4 아키텍처 구축
- 과거 원본 CSV/PNG/로그·QA 결과·디자인 결정 은폐/덮어쓰기
- 기존 게임 P1 이슈들을 '감사 승인'을 위해 해결된 것으로 표시
- 무제한 새 4분 벤치마크 반복 또는 추정 값으로 성능 PASS 채우기

## 완료 자료 구조 (실제 생성한 파일만 Commit)

```text
STUDIO_V3/tasks/V3-001-EVIDENCE-RECONCILE.md
STUDIO_V3/reviews/V3-001-INDEPENDENT-REVIEW.md
STUDIO_V3/evidence/V3-001-reconcile/
  ISSUE_RECONCILIATION.md
  GAMEPLAY_ISSUE_BACKLOG.md
  performance/
    PERFORMANCE_METHOD.md
    analysis.py
    analysis_output.json
    benchmark_source/           # 기존 실행 코드가 실제 있다면
    retest/                     # 실제 재측정 시에만
  CAPTURE_MANIFEST.json
  QA_ADDENDUM.md                # 신규 QA 실검수 후
  DIRECTOR_ADDENDUM.md          # 신규 Director 검수 후
  FINAL_RECONCILIATION_REPORT.md
STUDIO_V3/queue.json
STUDIO_V3/events.jsonl           # append-only
STATE.md
```

## Acceptance / Stop Rule

- [ ] 60Hz 샘플링 vs 240FPS 엔진 수치 설명 및 측정 방법 검증 또는 정직한 NOT_VERIFIED.
- [ ] 고유 이슈 7개·P1=3/P2=2/P3=2, 중복 -07과 미구현 -02 처리 명확함.
- [ ] 과거 문서·원본 로그·CSV·11 PNG 불변, 신규 정정 결과만 별도 파일에 기록.
- [ ] 실제 PNG SHA256/크기/치수와 캡처 인덱스 매핑.
- [ ] 확정 EVIDENCE_SHA를 두 **새** 독립 세션이 실제 검수, 최종 결과와 새 실행 메타 등록.
- [ ] 게임 내 문제점이 남아 있어도 '감사 정합성 PASS'와 '게임 품질 FAIL/OPEN'을 분리.
- [ ] 로컬 DB와 GitHub Queue는 수동 상태 위조 없이 정합; `V3-002` parent는 별도 승인 전까지 FIX_REQUIRED.
- [ ] `V3-003`는 V3-001 외부 검수 수락 + V3-002 parent 정식 승인 전까지 BLOCKED.
- [ ] 문제를 1회 보완으로 해결하지 못하면 `FIX_REQUIRED`와 증거를 남기고 종료. 새 품질 프레임워크/대규모 반복 루프 금지.

## Producer가 제출할 최종 보고 형식

```text
TASK: V3-001-EVIDENCE-RECONCILE
Branch: studio/v3-001-evidence-reconcile
Baseline game SHA: a71223615d0b77e36dd85edb24e138fc67ecc140
Reconciled evidence SHA: ...
Review evidence commit: ...
FPS source: engine 239-240 / sample dt ~16.7ms — explanation: ...
True rendered FPS verified: YES / NO / NOT_VERIFIED
Combat/boss load verified: YES / NO / NOT_VERIFIED
Original CSV + 11 PNG unchanged: YES / NO
Unique issues: 7 (P1 3, P2 2, P3 2); ISSUE-02 implementation: PENDING
PNG SHA256 & dimensions verified: 11/11 / ...
Independent QA new session + EVIDENCE_SHA: VERIFIED / NOT_VERIFIED
Independent Director new session + EVIDENCE_SHA: VERIFIED / NOT_VERIFIED
V3-001 audit evidence external acceptance: REQUESTED / FIX_REQUIRED
V3-001 game release readiness: NOT_APPROVED
V3-002 parent: FIX_REQUIRED / IN_REVIEW / APPROVED (only via separate formal gate)
V3-003: BLOCKED
P0/P1 evidence problems remaining: ...
Raw evidence / manifest / GitHub commits: ...
```

**한 번의 Antigravity PK_Producer 작업 지시로 범위 내 보완을 수행하고 GitHub에 Push한 뒤 외부 독립 검수에 제출한다. 스스로 외부 승인 선언 금지.**

## 최초 실행 명령

`studio/v3-001-evidence-reconcile`를 Fetch/Checkout한다. 먼저 본 명세와 외부 리뷰를 읽고, `V3-001` 원본 자료와 게임 코드를 보존한다. PK_ClientLead는 성능 데이터의 240 FPS vs 16.7 ms 불일치를 재현/설명하고 7개 Issue 정본 및 PNG SHA256 인덱스를 만든다. 확정한 EVIDENCE_SHA에 대해 새 PK_QALead와 PK_GameDirector 세션을 호출하여 실제 정정 파일을 독립 검수한다. 게임 기능 수정/에이전트 시스템 재구축 없이 정정 증거만 커밋/푸시하고 외부 검수를 요청한다.
