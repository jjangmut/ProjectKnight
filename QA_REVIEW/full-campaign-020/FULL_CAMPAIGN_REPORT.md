# [TASK-QA-020] Stage 1→5 Full Campaign Playthrough QA Comprehensive Report

## 1. 개요 (Overview)

본 문서는 Project Knight의 Stage 1부터 Stage 5까지 전체 캠페인 흐름(`New Game -> Stage 1 -> BossCommander -> Stage 2 -> BeastChieftain -> Stage 3 -> CrossbowCommander -> Stage 4 -> AncientGolemGuardian -> Stage 5 -> AbyssalArbiter -> Campaign Clear`)을 단위 플래그 조작이 아닌 실제 씬 및 상태 머신 페이싱(Pacing) 하에서 연속 관통 검증한 종합 QA 결과 보고서입니다.

- **작업 브랜치**: `antigravity/qa-full-campaign-playthrough-020`
- **기준 브랜치**: `antigravity/graphics-quality-pass-005-stage5`
- **작업 디렉토리**: `Worktrees/ProjectKnight/ART-STAGE-BATCH-001`
- **엔진**: `Godot_v4.7.2-stable_win64_console.exe` (Headless & OpenGL3 Compatibility)
- **최종 검증 상태**: `INDEPENDENT REVIEW REQUESTED`

---

## 2. 기존 Stage 그래픽 상태 보존 요약 (Status Preservation)

TASK-QA-020은 전체 게임 플레이스루의 런타임 안정성과 상호작용 무결성을 검증하는 태스크이며, 이전 스테이지들의 승인 상태를 임의로 상향 변경하지 않습니다.

| 스테이지 | 공식 상태 | 비고 |
| :--- | :--- | :--- |
| **Stage 1 (성문 외곽)** | `APPROVED` | Graphics Pass 001 완료 및 최종 승인 |
| **Stage 2 (야수숲)** | `INDEPENDENT REVIEW REQUESTED` | Graphics Pass 002 독립 검수 대기 유지 |
| **Stage 3 (무너진 성벽)** | `INDEPENDENT REVIEW REQUESTED` | Graphics Pass 003 독립 검수 대기 유지 |
| **Stage 4 (돌의 성소)** | `APPROVED` | TASK-AR-018 Ground Slam 리드로우 수정 완료 및 승인 |
| **Stage 5 (침묵의 성채)** | `TECHNICAL PASS / VISUAL APPROVAL HOLD` | 기술 검증 PASS / 비주얼 홀드 상태 유지 |
| **Android 플랫폼** | `ANDROID PERFORMANCE NOT VERIFIED` | 모바일 실기기 미검증 상태 보존 |

---

## 3. 핵심 QA 검증 항목 및 결과 (Verification Summary)

### 3.1 신규 작성된 Full Campaign QA 스위트 (5개)
1. **`tests/full_campaign_playthrough_qa.gd`**
   - Stage 1부터 Stage 5까지 5개 스테이지, 31개 인카운터(일반 26개 + 보스 5개) 및 5대 클라이맥스 보스 격파 연속 관통
   - **결과**: `225 / 225 checks PASSED (100%)`, 총 실행 소요 24.95초
2. **`tests/full_campaign_transition_qa.gd`**
   - 스테이지 간 씬 언로드/로드, 메모리 릭 방지, 유물 계승, 트레이트 버프 유지, 덱 상태 유지 검증
   - **결과**: `85 / 85 checks PASSED (100%)`
3. **`tests/full_campaign_checkpoint_qa.gd`**
   - 스테이지별 체크포인트 도달 시 저장 활성화, 플레이어 사망 시 체크포인트 위치 리스폰, 적 스폰 재동기화 검증
   - **결과**: `20 / 20 checks PASSED (100%)`
4. **`tests/full_campaign_reward_qa.gd`**
   - 보스 격파 후 보상 패널 표시, 트레이트 3종 선택, Relic 5종(Shield/Cloak/Quiver/Pauldrons/Crown) 활성화 및 SaveManager 세이브/로드 라운드트립 검증
   - **결과**: `26 / 26 checks PASSED (100%)`
5. **`tests/full_campaign_combat_readability_qa.gd`**
   - 텔레그래프 가시성, 히트스탑/카메라 셰이크 연출, 패링 타이밍, 가드 브레이크, 공중 콤보 버퍼링 및 조작 반응성 검증
   - **결과**: `21 / 21 checks PASSED (100%)`

### 3.2 캡처 검증 아티팩트 (5종)
- `QA_REVIEW/full-campaign-020/captures/stage2_beast_combat_gameplay.png` (야수숲 전투)
- `QA_REVIEW/full-campaign-020/captures/stage3_ranged_combat_gameplay.png` (무너진 성벽 원거리 교전)
- `QA_REVIEW/full-campaign-020/captures/stage5_entry_gameplay.png` (침묵의 성채 진입)
- `QA_REVIEW/full-campaign-020/captures/stage5_mixed_combat_gameplay.png` (성채 복합 몬스터 전투)
- `QA_REVIEW/full-campaign-020/captures/stage5_arbiter_gameplay.png` (Abyssal Arbiter Final Judgment 보스전)

---

## 4. 캠페인 런타임 성능 및 리소스 정합성

| 스테이지 | 활성 씬 진입 노드 수 | 인카운터 수 | 보스 HP / 페이즈 | 상태 |
| :--- | :--- | :--- | :--- | :--- |
| Stage 1 | 272 | 5 (일반 4, 보스 1) | 12 (Phase 1, 2) | CLEARED |
| Stage 2 | 283 | 6 (일반 5, 보스 1) | 14 (Phase 1, 2) | CLEARED |
| Stage 3 | 354 | 6 (일반 5, 보스 1) | 16 (Phase 1, 2) | CLEARED |
| Stage 4 | 370 | 6 (일반 5, 보스 1) | 20 (Phase 1, 2) | CLEARED |
| Stage 5 | 449 | 8 (일반 7, 보스 1) | 24 (Phase 1, 2, 3) | CLEARED |

- **오브젝트 정리(Node Leak Check)**: 스테이지 전환 시 이전 스테이지의 StageArt, AudioStreamPlayer, FloatingText, Enemy 인스턴스가 `queue_free()`를 통해 정상 해제됨을 확인 (단위 스테이지 당 잔존 누수 노드 0).
- **HUD 바인딩 무결성**: 보스 출현 시 HUD의 BossHealthBar가 동적 연결되고, 보스 사망 및 스테이지 전환 시 안전하게 제거됨.
- **물리/조작 수치 불변 원칙 준수**: 플레이어 이동 속도(230.0), 점프 속도, 대시 거리, 최대 체력(3) 등 핵심 플레이 파라미터 100% 보존.

---

## 5. 결함 및 이슈 현황 (Issue Summary)

- **P0 Blocker**: **0건**
- **P1 Major**: **0건**
- **P2 Minor / Environment**: **1건**
  - `export_presets.cfg` 내 로컬 디버그 키스토어 절대 경로 하드코딩 (`D:/...`) 관련 사항 (로컬 개발 환경 전용 빌드 파일로 인게임 런타임 영향 없음).

---

## 6. 결론 (Conclusion)

TASK-QA-020을 통해 Project Knight 전 5개 스테이지의 시작부터 엔딩까지 전체 캠페인 흐름이 결함 없이 완주됨을 확인하였습니다.
신규 작성된 5개 QA 스위트 및 기존 18개 회귀 스위트를 포함한 총 23개 테스트가 결함 없이 100% PASS 하였습니다.
