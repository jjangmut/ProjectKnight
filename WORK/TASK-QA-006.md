# [TASK-QA-006] 마일스톤 3 종합 자동화 검증 스위트

- 상태: DONE
- 담당: QA Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `WORK/TASK-CL-020.md`, `WORK/TASK-CL-021.md`, `WORK/TASK-CL-022.md`

## 1. 개요
캠프파이어 상점 구매 및 스탯 반영, 2지역 관문 보스 2페이즈 및 충격파, BGM 상태 전환 및 기존 전 시스템 회귀 테스트를 종합 자동화 스모크 테스트로 검증함.

## 2. 완료 내역
- `milestone3_smoke.gd`: 5개 핵심 축(메타 성장 지갑, 상점 구매/회복, 맹수 우두머리 AI/페이즈/샤드 드랍, 다이내믹 BGM, 2지역 인카운터 연동) 51개 검사 항목 100% PASS.
- 전 스위트 회귀 검증: 총 360개 이상의 체크 항목 전수 무결함 통과 (`milestone2_smoke`, `vertical_traversal_smoke`, `sprint4_smoke`, `combat_deepening_smoke`, `data_driven_smoke`, `guard_core_smoke`, `player_art_smoke`, `enemy_motion_smoke`, `stage_smoke`, `campaign_transition_test`).
