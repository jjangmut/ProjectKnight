# [SPEC] 모바일 버전 가상 컨트롤러 UI 및 Android APK 익스포트 사양서

- 문서 버전: v1.0
- 작성일: 2026-09-10
- 작성자: Client Engineer & QA Lead
- 상태: APPROVED (자율 완주)

---

## 1. 개요
Project Knight를 모바일(Android) 환경에서 완벽하게 플레이할 수 있도록, 화면 터치 기반 가상 컨트롤러(Virtual Touch Gamepad) HUD를 제작하고, 다중 터치(Multi-touch) 액션 에뮬레이션과 모바일 최적화 설정 및 Android APK 빌드 파이프라인을 구축함.

---

## 2. 가상 컨트롤러 UI 레이아웃 및 디자인 사양

### 2.1. 좌측 방향 조작계 (Left Virtual D-Pad)
- **위치**: 화면 좌측 하단 (`Vector2(50, 490)`, 크기 `260x200`)
- **버튼 구성**:
  - `Btn_move_left` (◀): 좌측 이동 (직경 80px, 청록 룬 틴트 `Color(0.2, 0.6, 0.9, 0.65)`)
  - `Btn_move_right` (▶): 우측 이동 (직경 80px, 청록 룬 틴트 `Color(0.2, 0.6, 0.9, 0.65)`)
  - `Btn_move_down` (▼): 하향 조작 (직경 70px, 복층 발판 하향 드롭다운 및 공중 하향 찌르기 발동)
- **비주얼 연출**:
  - 평상시: 반투명 다크 아크 서클 (Alpha 0.28) + 룬 링 외곽선 (Alpha 0.75)
  - 터치 시: 직경 8% 수축(`scale 0.92`) + 내부 화이트 버스트 펄스 (Alpha 0.55)

### 2.2. 우측 액션 클러스터 (Right Action Cluster)
- **위치**: 화면 우측 하단 (`Vector2(880, 440)`, 크기 `380x260`)
- **버튼 구성**:
  - `Btn_attack` (⚔ 공격): 가장 큰 주 공격 버튼 (직경 96px, 골드/주황 `Color(1.0, 0.65, 0.15, 0.75)`). 3단 콤보 및 카운터 공격 트리거.
  - `Btn_jump` (🦘 점프): 엄지 안쪽 편리한 위치 (직경 84px, 에메랄드 `Color(0.15, 0.85, 0.45, 0.75)`). 지상 점프 및 복층 도약.
  - `Btn_dash` (💨 대시): 회피 기동 버튼 (직경 76px, 시안/청록 `Color(0.1, 0.9, 0.9, 0.75)`). 지상/공중 그림자 대시 (I-Frame).
  - `Btn_guard` (🛡 방패): 상단 방패 버튼 (직경 78px, 사파이어 블루 `Color(0.3, 0.6, 1.0, 0.75)`). 지상 요새 가드 및 패링.

### 2.3. 멀티터치(Multi-touch) 및 입력 에뮬레이션
- `InputEventScreenTouch`의 터치 인덱스(Finger Index)별 독립 추적으로 동시 조작 완벽 지원 (예: 왼손 이동 유지 + 오른손 점프 + 공격 + 대시).
- 각 가상 버튼은 터치 시 `Input.action_press(action)`, 릴리즈 시 `Input.action_release(action)`를 호출하여 기존 플레이어의 물리, 콤보, 넉백, 대시 시스템과 100% 동일하게 호환.
- PC 테스트 지원: `project.godot`의 `input_devices/pointing/emulate_touch_from_mouse = true` 및 화면 상단 `📱 모바일패드` 토글 버튼 제공.

---

## 3. Android APK 익스포트 파이프라인
1. **SDK / JDK 환경 연동**:
   - Android SDK: `C:\Program Files (x86)\Android\android-sdk` (API 34/35, build-tools 35.0.0)
   - Java JDK: `C:\Program Files\Android\jdk\jdk-8.0.302.8-hotspot\jdk8u302-b08`
   - Debug Keystore: `C:\Users\jjang\.android\debug.keystore`
2. **Export Preset (`export_presets.cfg`)**:
   - 패키지명: `com.junypapa.projectknight`
   - 아키텍처: `arm64-v8a`, `armeabi-v7a`
   - 타겟 SDK: `34`, Min SDK: `24`
   - 오리엔테이션: 센서 가로모드 (Sensor Landscape)
3. **Godot Export Templates**:
   - `export_templates/4.7.2.stable/` 배치를 통한 APK 직접 빌드.
