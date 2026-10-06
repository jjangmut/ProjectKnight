# [TASK-QA-020] Checkpoint & Respawn QA Report

본 문서는 Stage 1부터 Stage 5까지 각 스테이지의 체크포인트 작동 상태 및 플레이어 사망 시의 리스폰(Respawn) 무결성 검증 결과를 기술합니다.

---

## 1. 스테이지별 체크포인트 구성 및 활성화 임계점

| 스테이지 | 체크포인트 인덱스 | 좌표 (X, Y) | 요구 인카운터 수 | 검증 상태 |
| :--- | :--- | :--- | :--- | :--- |
| **Stage 1** | CP 0 / CP 1 | (1600, 580) / (4500, 580) | Encounter 1 / 3 완료 후 | **PASS** |
| **Stage 2** | CP 0 / CP 1 | (2800, 580) / (6500, 580) | Encounter 2 / 4 완료 후 | **PASS** |
| **Stage 3** | CP 0 / CP 1 | (2800, 580) / (6500, 580) | Encounter 2 / 4 완료 후 | **PASS** |
| **Stage 4** | CP 0 / CP 1 | (2800, 580) / (6500, 580) | Encounter 2 / 4 완료 후 | **PASS** |
| **Stage 5** | CP 0 / CP 1 / CP 2 | (2800, 580) / (5800, 580) / (8800, 580) | Encounter 2 / 4 / 6 완료 후 | **PASS** |

---

## 2. 체크포인트 갱신 및 리스폰 로직 검증

1. **체크포인트 도달 시 플래그 갱신**:
   - 플레이어가 요구 인카운터를 클리어한 상태에서 체크포인트 위치 반경에 도달 시 `stage.checkpoint_active = true` 및 `stage.checkpoint_index`가 최신 위치로 갱신됨.
   - 시각 피드백: 체크포인트 깃발/비석의 활성화 이펙트 정상 발동.

2. **사망 및 리스폰 위치 무결성 (`_respawn_at_checkpoint`)**:
   - `player.take_damage(99)`로 플레이어가 사망 상태에 진입했을 때:
     - 체크포인트가 활성화된 경우: 직전 활성화된 체크포인트 좌표로 정확히 위치 복구 (`player.position == checkpoint_positions[index]`).
     - 체크포인트가 없는 상태의 사망: 스테이지 시작 지점(`start_position`)으로 리셋.
   - 플레이어 체력: 최대 체력(`player.max_hp == 3`)으로 온전히 회복.
   - 카메라 뷰: 플레이어의 리스폰 위치로 `Camera2D.force_update_scroll()` 즉시 동기화.

3. **적 스폰 및 인카운터 상태 재동기화**:
   - 리스폰 후 이미 완료된 인카운터(`stage.completed[i] == true`)는 게이트가 열려 있고 적이 재스폰되지 않음.
   - 미완료 인카운터의 몬스터들은 초기 상태로 깔끔하게 리셋되어 무한 루프나 유령 인스턴스 발생 차단.

---

## 3. 검증 결론
- `tests/full_campaign_checkpoint_qa.gd` 스위트(총 20개 항목) 100% PASS 달성.
- 사망/리스폰 시 씬 크래시, 메모리 누수, 좌표 텔레포트 오작동 없음 확인.
