# [TASK-CL-022] 다이내믹 BGM 트랙 및 오디오 엔진 확장

- 상태: DONE
- 담당: Client Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `DESIGN/CAMPFIRE_SHOP_AND_STAGE2_BOSS_SPEC_001.md`

## 1. 개요
`AudioManager`에 탐험 BGM(`exploration`)과 보스 결전 BGM(`boss`)을 지원하는 다이내믹 배경음악 플레이어 시스템을 탑재하고, 스테이지 및 보스룸 진입 시 자연스러운 전환을 연동함.

## 2. 완료 내역
- `audio_manager.gd`: 다이내믹 BGM 플레이어 노드(`_bgm_player`), 탐험 루프(`bgm_exploration`) 및 보스 결전 긴장감 루프(`bgm_boss`) 합성 오디오 스트림 구축.
- `play_music()`, `stop_music()`, `AudioManager.bgm()`, `AudioManager.stop_bgm()` 정적 래퍼 및 질의 메서드(`get_current_bgm()`, `is_bgm_playing()`) 구현.
- `first_stage.gd`: 스테이지 로드 시 `exploration` BGM 재생, 보스 인카운터 진입 시 `boss` BGM 전환, 보스 격파 시 복귀 연동.
- `milestone3_smoke.gd`: BGM 상태 머신 전이 검증 통과 (100% PASS).
