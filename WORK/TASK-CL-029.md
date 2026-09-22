# [TASK-CL-029] 모바일 가상 컨트롤러(MobileControls) UI 및 멀티터치 조작 시스템 구현

- 상태: DONE
- 담당: Client Engineer
- 시작일: 2026-09-10
- 완료일: 2026-09-10
- 상위 문서: `DESIGN/MOBILE_UI_AND_APK_EXPORT_SPEC_001.md`

## 1. 개요
모바일 환경에서 Project Knight를 쾌적하게 조작할 수 있도록 모바일 전용 가상 컨트롤러 HUD(`MobileControls`, `VirtualButton`)를 제작하고, 멀티터치 기반 이동(Left/Right/Down) 및 액션(Attack/Jump/Dash/Guard) 입력 에뮬레이션과 PC 마우스 터치 에뮬레이션을 구축함.

## 2. 완료 내역
- `mobile_controls.gd` & `MobileControls.tscn`:
  - 좌측 가상 D-Pad (Left, Right, Down) 및 우측 4개 액션 클러스터 (Attack, Jump, Dash, Guard) 배치.
  - 절차적 룬 링 및 다크 글래스모피즘 드로잉, 터치 다운 수축 및 펄스 하이라이트.
  - `InputEventScreenTouch` 터치 인덱스 독립 추적으로 왼손 이동 + 오른손 액션 동시 멀티터치 완벽 지원.
  - `Input.action_press` / `Input.action_release` 연동으로 기존 전투 메커니즘과 100% 호환.
  - PC 환경 테스트용 상단 `📱 모바일패드` 토글 버튼 연동.
- `project.godot`:
  - `input_devices/pointing/emulate_touch_from_mouse = true`
  - `window/handheld/orientation = 5` (sensor_landscape)
  - `dash` 및 `move_down` 액션 등록 완료.
- `first_stage.gd`: 모든 스테이지 시작 시 `MobileControls` CanvasLayer(layer 20) 자동 인스턴스화 연동.
