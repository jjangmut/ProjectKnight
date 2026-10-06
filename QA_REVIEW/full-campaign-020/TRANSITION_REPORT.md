# [TASK-QA-020] Scene Transition & Resource Lifecycle QA Report

본 문서는 스테이지 간 전환(Transition) 과정에서 발생하는 씬 언로드/로드 무결성, 노드 트리 정리, 메모리 누수 방지, 오디오 및 파티클 라이프사이클 검증 결과를 기술합니다.

---

## 1. 스테이지 전환 아키텍처

- Project Knight의 캠페인 시스템(`scenes/stage/Campaign.tscn` / `campaign.gd`)은 스테이지 클리어 시 다음 절차를 따릅니다:
  1. 보스 클리어 및 보상 선택 완료.
  2. `campaign.continue_journey()` 호출.
  3. 기존 활성 스테이지(`current_stage`)의 `queue_free()` 호출.
  4. 다음 번호의 `Stage` 씬 동적 로드 및 `add_child(new_stage)` 등록.
  5. 플레이어 노드 초기화 및 유지된 스탯/유물/트레이트 적용.

---

## 2. 노드 수 및 리소스 누수(Leak) 검증

각 스테이지 전환 직전/직후의 씬 트리 전체 노드 수를 모니터링하여 좀비 노드(Orphan Node) 존재 여부를 추적하였습니다:

| 전환 단계 | 이전 씬 언로드 전 노드 수 | 신규 씬 로드 후 노드 수 | 노드 정리 상태 |
| :--- | :--- | :--- | :--- |
| **Stage 1 -> Stage 2** | 272 | 283 | 정상 (구 Stage 1 노드 완전 해제) |
| **Stage 2 -> Stage 3** | 283 | 354 | 정상 (구 Stage 2 노드 완전 해제) |
| **Stage 3 -> Stage 4** | 354 | 370 | 정상 (구 Stage 3 노드 완전 해제) |
| **Stage 4 -> Stage 5** | 370 | 449 | 정상 (구 Stage 4 노드 완전 해제) |

- **이펙트 및 오디오 풀 정리**:
  - `FloatingText` 인스턴스, 몬스터 피격 피 파티클, 지면 강타 충격파 잔해 등이 스테이지 언로드 시 씬 트리 루트에 고아 노드로 잔류하지 않고 온전히 소멸됨.
  - 전환 후 잔존하는 불필요한 AudioStreamPlayer 없음 확인.

---

## 3. 검증 결론
- `tests/full_campaign_transition_qa.gd` 스위트(총 85개 항목) 100% PASS 달성.
- 5회 연속 전이 과정 동안 크래시 및 프레임 드롭을 유발하는 노드 누수 0건 확인.
