# [TASK-QA-020] Performance & Optimization QA Report

본 문서는 Stage 1부터 Stage 5까지 전 구간 연속 플레이스루 동안의 PC 환경 런타임 성능, 렌더링 최적화 게이트, 메모리 안정성, 그리고 모바일 플랫폼 검증 상태를 기술합니다.

---

## 1. PC 캠페인 런타임 성능 지표

- **전체 캠페인 헤드리스 소요 시간**: 약 **24.95초** (Stage 1~5, 31개 인카운터 및 5대 보스 연속 클리어)
- **메모리 및 노드 프로파일링**:
  - 시작 시점 노드 수: 272개
  - 최대 복합 씬(Stage 5) 노드 수: 449개
  - 스테이지 전환 간 노드 누적 증가(Leak) 없음: 이전 스테이지가 정상 `queue_free()` 됨.
- **드로우 콜 및 리드로우 최적화 (Selective Redraw)**:
  - Stage 1 R3에서 확립된 `StageArt`의 선택적 `queue_redraw()` 아키텍처가 5개 스테이지 전역에서 유지됨.
  - Idle(정지) 상태에서 매 프레임 무조건적인 `queue_redraw()` 발생 차단.
  - Stage 4의 Ground Slam 공격 및 Stage 5의 Final Judgment 연출 시에만 능동적으로 리드로우가 가동되어 불필요한 GPU/CPU 부하 방지.

---

## 2. 렌더링 성능 게이트 검증

- `tests/stage5_render_performance_gate.gd`: PASS
  - 100프레임 연속 벤치마크 수행 시 드로우 호출 상한 및 프레임 타임 기준치 충족.
- `tests/stage4_ground_slam_redraw_smoke.gd`: PASS
  - 정지 상태 리드로우 차단 및 공격 시 실시간 리드로우 보장.

---

## 3. 플랫폼별 성능 검증 상태

| 플랫폼 | 검증 상태 | 상세 내용 |
| :--- | :--- | :--- |
| **PC (Windows / OpenGL3)** | `VERIFIED PASS` | 헤드리스 및 렌더링 모드 전 스위트 100% 정상 구동 확인 |
| **Android (Mobile)** | `ANDROID PERFORMANCE NOT VERIFIED` | 모바일 타겟 패키징 및 실기기 프로파일링 미수행 (과장 표기 금지 원칙 준수) |

---

## 4. 검증 결론
- PC 런타임 성능 및 렌더링 최적화 기준치 충족.
- Android 성능은 원칙에 따라 `NOT VERIFIED`로 명시함.
