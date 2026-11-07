# ProjectKnight Studio V3 — Producer 공인 종합 요약서 (Corrected Summary)

**작업 ID:** `V3-001-ATTESTATION-CLOSE`  
**작성자:** `PK_Producer` (Studio V3 총괄 Producer)  
**기준 커밋:** `fa5d900f8e9cb6f0853af85bc7bf09e6725951ed`  
**정본 참조 문서:**  
- 결함 정본: [`GAMEPLAY_ISSUE_BACKLOG.md`](../V3-001-reconcile/GAMEPLAY_ISSUE_BACKLOG.md)  
- 성능 정본: [`analysis_output.json`](../V3-001-reconcile/performance/analysis_output.json), [`PERFORMANCE_METHOD.md`](../V3-001-reconcile/performance/PERFORMANCE_METHOD.md)  
- 캡처 정본: [`CAPTURE_MANIFEST.json`](../V3-001-reconcile/CAPTURE_MANIFEST.json)  
**일자:** 2026-11-07  

---

## 1. 정본 게임 결함 7개 (Canonical Gameplay Defect Matrix)

이전 대외 완료 보고서에서 혼선이 있었던 결함 명칭을 GitHub 공인 정본인 [`GAMEPLAY_ISSUE_BACKLOG.md`](../V3-001-reconcile/GAMEPLAY_ISSUE_BACKLOG.md)에 의거하여 아래와 같이 확정 정정합니다:

| Issue ID | 우선순위 | 구분 | 정본 결함 명칭 및 핵심 내용 | 담당 에이전트 | 공식 거버넌스 상태 | 후속 마일스톤 |
| :--- | :---: | :--- | :--- | :--- | :---: | :---: |
| **ISSUE-V3-001-01** | **P1** | 모바일/입력 | **모바일 가상 조이스틱 및 액션 버튼 누락**<br>CanvasLayer에 HUD는 존재하나 터치 이동/공격/점프 가상 패드가 미인스턴스화됨. | PK_ClientLead | **OPEN** | V3-003 |
| **ISSUE-V3-001-02** | **P1** | 전투/아키텍처 | **Z축 자유 이동 vs 횡스크롤 전투 평면 설계 불일치**<br>Z축 오차(0.3 이상)로 인한 평타 히트 판정 실패. 디렉터 **Option C ($Z=0.0$ 고정 평면)** 승인 완료, 코드 구현 대기. | PK_ClientLead | **DECIDED /<br>IMPLEMENTATION_PENDING** | V3-003 |
| **ISSUE-V3-001-03** | **P2** | 엔진/안정성 | **시작 시 `add_child()` 노드 등록 오류**<br>노드 트리 바쁜 상태에서 `add_child()` 호출로 인한 부팅 콘솔 경고. | PK_ClientLead | **OPEN** | V3-003 |
| **ISSUE-V3-001-04** | **P2** | 그래픽/아트 | **Sprite3D 접지/점프 위치 문제**<br>3D 배경 깊이감 대비 빌보드 캐릭터의 발밑 접지 그림자 및 고도 오프셋 약화. | PK_ArtDirector | **OPEN** | V3-003 |
| **ISSUE-V3-001-05** | **P3** | 디자인/연출 | **보스 돌진 전조 연출 부족**<br>커맨더 보스의 쉴드 차지 전조 모션/VFX가 불충분하여 반응 난도 급상승. | PK_GameDesign | **OPEN** | V3-003 / Polish |
| **ISSUE-V3-001-06** | **P3** | UI/플로우 | **스테이지 결과/보상 화면 부재**<br>보스 격파 후 보상 및 스테이지 클리어 결과 화면 플로우 누락. | PK_GameDesign | **OPEN** | V3-003 / Polish |
| **ISSUE-V3-001-07** | **P1** | 카메라/시야 | **보스전 전방 성벽·기둥에 따른 캐릭터/보스 시야 가림**<br>전경 성벽 오브젝트가 카메라와 플레이 평면 사이를 가려 전투 시인성 훼손. | PK_ArtDirector /<br>PK_ClientLead | **OPEN** | V3-003 |

- **고유 결함 총계:** **7개 (P1 3건, P2 2건, P3 2건)**
- **주의 사항:** `ISSUE-02`는 Option C로 설계 방향이 공식 확정되었으나 현재 감사 단계에서는 코드 수정이 금지되어 있으므로 반드시 `IMPLEMENTATION_PENDING`으로 유지됩니다.

---

## 2. 성능 데이터 정밀 규명 (Performance Telemetry Interpretation)

원본 14,404 샘플([`raw_frames.csv`](../V3-001/performance/raw_frames.csv)) 분석을 통한 공식 수치 및 기술적 한계를 아래와 같이 명확히 규정합니다:

1. **엔진 FPS 모니터링 (`Performance.TIME_FPS`)**:
   - **전체 샘플 평균 (Overall Mean):** **238.34 FPS** (중앙값 240.0 FPS)
   - **안정적 활동 구간 평균 (Steady Sectors Mean):** **약 239.54 FPS**
     - Walking (이동): 239.54 FPS
     - Normal Combat (일반 전투): 239.55 FPS
     - Boss Combat (보스 전투): 239.54 FPS
     - Idle (대기): 234.74 FPS (초기 로딩 및 씬 진입 과도 구간 포함)
   - **VSync 및 리프레시율 규격:**
     - 창모드 렌더링 환경에서 240Hz 디스플레이 주사율 동기화 또는 내부 렌더 루프 특성이 반영된 수치이며, 런타임 VSync 설정이 완전히 비활성화(uncapped)되었다고 단정할 수 없음.
2. **물리 틱 수집 주기 (Physics Tick Interval)**:
   - 벤치마크 하네스([`benchmark_stage1_windowed.gd`](../V3-001-reconcile/performance/benchmark_source/benchmark_stage1_windowed.gd))는 `_physics_process(delta)`에서 실행됨.
   - 평균 물리 간격: **16.66 ms** (중앙값 16.698 ms).
   - 파생 물리 샘플링 레이트: **평균 60.03 Hz** (1% Low 59.46 Hz).
   - 과거 보고서의 '60 FPS'는 그래픽 렌더 속도가 아니라 **물리 틱 호출 주기($1000 / \Delta t$)**임.
3. **렌더 프로세스 부하 지표 한계**:
   - `Performance.TIME_PROCESS`는 CPU 메인 루프 프로세스 시간(평균 4.43 ms)을 측정한 것으로, 독립적으로 검증된 **GPU 총 프레임 렌더 시간(GPU Frame Time)이 아님**.
   - 따라서 이 수치만으로 모바일 디바이스의 GPU 헤드룸을 보증할 수 없음.
4. **전투 차등 부하 및 안드로이드 상태**:
   - **전투 차등 부하:** 이동/전투/보스전 전 구간에서 드로우 콜(224.9)과 노드 수(155.0)가 균일하게 유지되어 추가 부하가 입증되지 않았으므로 **`COMBAT_STRESS_DIFFERENTIAL_NOT_VERIFIED`**로 규정.
   - **Android 성능:** 실기기 프로파일링이 수행되지 않았으므로 공식적으로 **`NOT_TESTED`** 유지.

---

## 3. 거버넌스 및 마일스톤 승인 분리 (Governance Separation)

1. **V3-001 Baseline Audit 성격**:
   - V3-001은 출시 가능한 게임을 만드는 마일스톤이 아니라, **현존 게임의 상태를 정직하게 감사하고 기준점을 수립하는 단계**입니다.
   - 따라서 감사 절차와 증거의 완전성은 내부 승인(`queue.json issues: []`)되었으나,
2. **게임 클라이언트 출시 판정 (Game Client Release Readiness)**:
   - 3건의 P1 블로커(`ISSUE-01`, `ISSUE-02`, `ISSUE-07`)가 해결되지 않았으므로 게임 클라이언트 자체는 **`NOT_APPROVED`**입니다.
3. **마일스톤 종속 관계**:
   - **V3-002 Parent:** 하위 `V3-002-CLOSE`의 검수 통과와 별개로, 공식 상위 롤업 승인 전까지 **`FIX_REQUIRED`**를 유지합니다.
   - **V3-003:** V3-001 외부 증거 검수 통과 및 V3-002 부모 마일스톤 공식 승인 완료 시까지 **`STRICTLY BLOCKED`**를 유지합니다.
