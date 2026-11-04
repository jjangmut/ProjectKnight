# ProjectKnight QA Issue List (v2 Multi-Agent Production)

- **마일스톤**: `VS-001 — 3D Background + 2D Character Vertical Slice`
- **책임자**: `PK_QALead`
- **최종 갱신**: 2026-11-04 22:41 (KST)

---

## 1. 이슈 분류 기준

| 심각도 | 명칭 | 정의 및 조치 규칙 |
| :--- | :--- | :--- |
| **P0** | **BLOCKER** | 게임 진행 불가, 크래시, 치명적 렌더링 파괴. 즉시 최우선 할당 및 마일스톤 블록. |
| **P1** | **MAJOR** | 주요 시스템 오작동, 심각한 조작감 결함, 보스 패턴 불가 판정. 마일스톤 완료 전 필히 해결. |
| **P2** | **MINOR** | 경미한 시각 클리핑, 사운드 타이밍 오차, 비필수 UI 어긋남. 폴리시 백로그 추가. |
| **P3** | **POLISH** | 연출 강화 제안, 부유 파티클 농도 조절 등 추가 미적 개선안. |

---

## 2. 활성 이슈 목록 (Active Issues)

| Issue ID | Severity | Description | Component | Status | Owner | Reviewer |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `ISSUE-VS001-01` | P2 | 3D 아레나 측면 경계 이동 시 2D 캐릭터 발끝 접지 그림자 강도 미세 감쇄 | Visual/Art | IN_PROGRESS | `PK_ArtDirector` | `PK_QALead` |
| `ISSUE-VS001-02` | P3 | 보스 1페이즈 진입 전 3D 카메라 줌인 연출 시 모바일 터치 HUD 페이드인 타이밍 조율 | UI/Pacing | READY | `PK_ClientLead` | `PK_GameDirector` |

---

## 3. 해결된 이슈 목록 (Resolved Issues)

| Issue ID | Severity | Description | Resolution | Evidence |
| :--- | :--- | :--- | :--- | :--- |
| `ISSUE-RES-001` | P1 | 28종 캐릭터/보스 스프라이트 시트 셀 경계 침범(Bleed) | 1px 안전 패딩 및 정밀 아틀라스 슬라이싱 적용 | `test_sprite_alignment_audit.gd` 28/28 PASS |
| `ISSUE-RES-002` | P1 | 3D 보스 대치 시 가변 FOV 프레이밍 미동기화 | Lookahead 및 듀얼 타깃 바운딩 박스 가변 FOV 구현 | `daily_dev_process_runner.gd` PASS |
| `ISSUE-RES-003` | P0 | 공중 하향 슬램 시 지상 착지 충격파 범위 판정 누락 | `DiveShockwaveRing3D` 3.8m AoE 2x 피해 및 체간 4 피해 구현 | `test_advanced_combat_expansion.gd` PASS |
