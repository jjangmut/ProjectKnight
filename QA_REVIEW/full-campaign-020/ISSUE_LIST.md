# [TASK-QA-020] Issue List & Quality Assessment

본 문서는 Stage 1→5 Full Campaign Playthrough QA 수행 과정에서 식별된 이슈 목록 및 조치 사항을 정리합니다.

---

## 1. 이슈 요약표

| 등급 | 개수 | 상태 | 비고 |
| :--- | :--- | :--- | :--- |
| **P0 (Blocker)** | 0 | CLEARED | 런타임 크래시, 무한 루프, 진행 불가 결함 없음 |
| **P1 (Major)** | 0 | CLEARED | 스테이지 전환 실패, 세이브 유실 결함 없음 |
| **P2 (Minor)** | 1 | OPEN (NON-BLOCKING) | 안드로이드 디버그 키스토어 로컬 절대 경로 |
| **P3 (Trivial/Cosmetic)** | 0 | - | - |

---

## 2. 상세 이슈 내역

### [ISSUE-020-01] P2 (Minor / Environment)
- **항목**: Android Export Preset 키스토어 경로
- **내용**: `CLIENT/Game/export_presets.cfg` 내에 `keystore/debug="D:/JUNYPAPA_STUDIO/..."` 로컬 절대 경로가 지정되어 있음.
- **영향도**: PC 빌드 및 게임 엔진 내부 런타임, 테스트 실행에는 일절 영향이 없으나, CI/CD 환경이나 타 개발 머신에서 안드로이드 빌드 시 상대 경로 또는 환경 변수로 설정 필요.
- **조치 권고**: 안드로이드 빌드 파이프라인 정비 시 상대 경로(`res://...`) 또는 CI 시크릿으로 교체 권장.

---

## 3. 그래픽 패스 상태 참고사항
- **Stage 2 & Stage 3**: `INDEPENDENT REVIEW REQUESTED` 유지.
- **Stage 5**: `TECHNICAL PASS / VISUAL APPROVAL HOLD` 유지.
- 본 QA를 통해 게임 플레이 진행 및 기능 무결성은 100% 검증되었으나, 비주얼 품질 승인은 아트 디렉터 및 독립 검수 절차를 대기합니다.
