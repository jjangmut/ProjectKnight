# ProjectKnight Studio V3 — 실제 게임 기준점 감사 보완 상태

업데이트: 2026-11-06
작업 브랜치: `studio/v3-001-evidence-reconcile`
원본 게임 기준 SHA: `a71223615d0b77e36dd85edb24e138fc67ecc140`
V3-001 최초 증거 제출: `studio/v3-001-playable-baseline@5c25a98084ba6885e1b9b4e2bac40a9c74568473`

## 실제로 확보한 자료
- Stage 1 실제 Godot 실행/입력 로그 및 11개 PNG 캡처 파일, 14,404행 성능 CSV가 GitHub에 존재.
- 게임 코드 `CLIENT/Game/` 변경은 최초 증거 커밋에서 없었음.
- PK_GameDirector가 Option C(2.5D 시각 표현 + X/Y 게임플레이 평면, Z=0)를 선택했으나 **게임 코드에 아직 적용하지 않았음**.
- 기존 V3-001 내부 Two-Key 리뷰 및 큐는 APPROVED. **외부 독립 검수는 FIX_REQUIRED**: 두 상태는 서로 다른 검수 단계이며 내부 기록을 조용히 덮어쓰지 않는다.
- Windows/Godot 실행 및 이미지 픽셀은 이 외부 검수에서 직접 재실행/디코딩하지 못했음. 실제 파일 존재와 실제 화면 콘텐츠 인증을 혼동하지 않는다.

## 외부 검수에서 확인한 정합성 문제
1. PC performance: CSV `fps` 239~240 vs `dt_ms` 약 16.7 ms(약 60Hz 샘플), 원본 벤치마크 스크립트 미제출, 전투/보스 구간 실제 부하 근거 미확정.
2. Issue registry: 고유 7개(3 P1 / 2 P2 / 2 P3), -07 요약표 세 번 등장, 초안 6개 vs 최종 7개, -02 Option C 채택만 완료되고 게임 구현 미실행.
3. QA 선행 타임스탬프와 이후 Director가 추가한 이슈/최종 파일 해시 간 시점 불일치. 최종 정정 증거 SHA에 대한 새 독립 QA/Director 검수 필요.
4. 11개 PNG 파일 존재는 확인했지만 픽셀 직접 외부 검수 불가. 파일별 SHA256·차원 매니페스트 필요.

## 작업 큐
- **V3-001-EVIDENCE-RECONCILE READY**: 감사 자료 정합성 패치. `STUDIO_V3/tasks/V3-001-EVIDENCE-RECONCILE.md` 우선.
- V3-001 **내부 APPROVED / 외부 FIX_REQUIRED**: 기존 승인 이력 보존, 외부 보완 중.
- V3-002-CLOSE **APPROVED (child)**: 외부 코드/증거 검수 통과.
- V3-002 **FIX_REQUIRED (parent)**: 별도의 공식 롤업 승인 필요. 외부 child 승인만으로 자동 완료 금지.
- V3-003 **BLOCKED**: V3-001 외부 감사 수락 및 V3-002 parent 정식 승인 전 불가.

## 제한
이번에는 원본 `CLIENT/Game/`, 이전 PNG/CSV/로그 및 과거 검수 이력을 변경하지 않는다. 성능 수치는 근거가 없으면 NOT_VERIFIED로 수정한다. Stage 1 모바일 UI·Z 평면·보스 시야 등 실제 게임 P1은 후속 개발 백로그로 보존한다. 새 게임 에이전트 프레임워크를 만들지 않는다.
