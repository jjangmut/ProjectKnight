# [TASK-QA-009] 모바일 가상 컨트롤러 및 멀티터치 자동화 검증 스위트

- 상태: DONE
- 담당: QA Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `DESIGN/MOBILE_UI_AND_APK_EXPORT_SPEC_001.md`

## 1. 개요
모바일 가상 컨트롤러 HUD의 노드 계층 구조, 개별 가상 버튼의 터치 다운/업 액션 에뮬레이션, 양손 동시 멀티터치(Multi-touch) 독립성, 그리고 화면 표시 토글 기능을 자동화 스위트로 검증함.

## 2. 완료 내역
- `CLIENT/Game/tests/mobile_controls_smoke.gd` 구축 완료.
- 검증 결과: 총 28개 검증 항목 100% PASS 달성:
  - Check 1: 가상 컨트롤러 UI 계층 구조 및 버튼 7종(좌/우/하향/공격/점프/대시/가드/토글) 바인딩 검증 (9/9 PASS).
  - Check 2: 단일 터치 다운/업 이벤트에 따른 `Input.action_press` 및 릴리즈 검증 (4/4 PASS).
  - Check 3: 액션 버튼 4종(Attack, Jump, Dash, Guard)의 개별 액션 트리거 검증 (8/8 PASS).
  - Check 4: 멀티터치 동시 입력(Finger 0 이동 누른 상태에서 Finger 1 점프 입력 및 개별 해제) 검증 (5/5 PASS).
  - Check 5: 모바일 컨트롤러 뷰 가시성 토글 기능 검증 (2/2 PASS).
