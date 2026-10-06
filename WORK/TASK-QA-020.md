# [TASK-QA-020] Stage 1→5 Full Campaign Playthrough QA 작업 내역서

## 1. 작업 개요

- **태스크 ID**: `TASK-QA-020`
- **담당**: Antigravity / JPStudio QA Lead + Client Lead
- **우선순위**: `P0`
- **기준 브랜치**: `antigravity/graphics-quality-pass-005-stage5`
- **신규 작업 브랜치**: `antigravity/qa-full-campaign-playthrough-020`
- **작업 공간**: `D:\JUNYPAPA_STUDIO\Worktrees\ProjectKnight\ART-STAGE-BATCH-001`
- **엔진 버전**: Godot 4.7.2 stable (Windows 64-bit console)

---

## 2. 작업 목표 및 원칙

1. **상태 머신 실제 구동 기반 풀 캠페인 완주**:
   - 단위 변수 조작(`cleared[i] = true`)이 아닌, `Campaign.tscn` 인스턴스에서 New Game -> Stage 1 -> Boss -> Reward -> Stage 2 -> ... -> Stage 5 -> Abyssal Arbiter -> 엔딩까지 실제 씬 전환 및 게임 루프를 통한 완주 검증.
2. **이전 스테이지 승인 상태 유지 원칙**:
   - Stage 1: `APPROVED`
   - Stage 2: `INDEPENDENT REVIEW REQUESTED` (유지)
   - Stage 3: `INDEPENDENT REVIEW REQUESTED` (유지)
   - Stage 4: `APPROVED`
   - Stage 5: `TECHNICAL PASS / VISUAL APPROVAL HOLD` (유지)
   - Android: `ANDROID PERFORMANCE NOT VERIFIED` (과장 금지 원칙 준수)
3. **핵심 게임 파라미터 불변 원칙**:
   - 플레이어 이동속도(230), 점프, 대시, 가드, 공격력 등 물리/조작 수치 100% 보존.

---

## 3. 구현 및 검증 내역

### 3.1 신규 QA 테스트 스위트 작성 (5개)
1. **`tests/full_campaign_playthrough_qa.gd`**
   - Stage 1부터 Stage 5까지 31개 인카운터 및 5대 보스 연속 격파 완주.
   - 5개 대표 게임플레이 캡처 저장 및 런타임 통계 수집 (`full_campaign_playthrough.json`).
   - 결과: **225/225 PASS (100%)**
2. **`tests/full_campaign_transition_qa.gd`**
   - 스테이지 간 씬 언로드/로드, 노드 누수 방지, 트레이트/유물 계승 검증.
   - 결과: **85/85 PASS (100%)**
3. **`tests/full_campaign_checkpoint_qa.gd`**
   - 스테이지별 체크포인트 도달 시 저장 활성화 및 사망 시 리스폰 좌표 동기화 검증.
   - 결과: **20/20 PASS (100%)**
4. **`tests/full_campaign_reward_qa.gd`**
   - 보스 격파 후 보상 화면, 5종 유물 패시브 스탯 연동, SaveManager 라운드트립 검증.
   - 결과: **26/26 PASS (100%)**
5. **`tests/full_campaign_combat_readability_qa.gd`**
   - 전 보스 및 일반 몬스터의 공격 텔레그래프 가독성, 저스트 패링, 히트스탑, 공중 콤보 버퍼링 검증.
   - 결과: **21/21 PASS (100%)**

### 3.2 대표 게임플레이 캡처 아티팩트 (5종)
- `QA_REVIEW/full-campaign-020/captures/stage2_beast_combat_gameplay.png`
- `QA_REVIEW/full-campaign-020/captures/stage3_ranged_combat_gameplay.png`
- `QA_REVIEW/full-campaign-020/captures/stage5_entry_gameplay.png`
- `QA_REVIEW/full-campaign-020/captures/stage5_mixed_combat_gameplay.png`
- `QA_REVIEW/full-campaign-020/captures/stage5_arbiter_gameplay.png`

### 3.3 QA 종합 보고서 작성 완료
- `QA_REVIEW/full-campaign-020/FULL_CAMPAIGN_REPORT.md`
- `QA_REVIEW/full-campaign-020/STAGE_BY_STAGE_REPORT.md`
- `QA_REVIEW/full-campaign-020/BOSS_REPORT.md`
- `QA_REVIEW/full-campaign-020/CHECKPOINT_REPORT.md`
- `QA_REVIEW/full-campaign-020/REWARD_SAVE_REPORT.md`
- `QA_REVIEW/full-campaign-020/TRANSITION_REPORT.md`
- `QA_REVIEW/full-campaign-020/PERFORMANCE_REPORT.md`
- `QA_REVIEW/full-campaign-020/ISSUE_LIST.md`

---

## 4. 최종 품질 지표

- **P0 이슈**: 0건
- **P1 이슈**: 0건
- **P2 이슈**: 1건 (`export_presets.cfg` 로컬 디버그 키스토어 절대 경로)
- **전체 회귀 스위트**: 23개 스위트 결함 0건 (100% PASS)
- **최종 상태**: `INDEPENDENT REVIEW REQUESTED`
