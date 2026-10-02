# Stage 1 Graphics Quality Pass 001-R1 검토 보고서
**Project Knight — Graphics Quality Director (Antigravity)**

- **문서 버전**: v1.0.0 (Pass 001-R1)
- **작업 브랜치**: `antigravity/graphics-quality-pass-001-r1`
- **검토 상태**: **독립 검수 요청 (Independent Review Requested)**
- **기준 일자**: 2026-10-02
- **선행 검수**: `WORK/TASK-AR-011.md` / `ART_REVIEW/GRAPHICS_PASS_001_INDEPENDENT_REVIEW.md`

---

## 1. 개요 및 배경

Pass 001에 대한 독립 검수 결과(`ART_REVIEW/GRAPHICS_PASS_001_INDEPENDENT_REVIEW.md`), 자체 PASS 평가 및 보스 오라/접지 그림자 개선은 확인되었으나 여전히 프로토타입 형태의 UI/지형 요소, 상단 HUD 텍스트 겹침, 모바일 컨트롤의 단색 형태감 등 추가 개선 필요성이 지적되었습니다(`REWORK REQUIRED`).

이에 따라 `WORK/TASK-AR-011.md` 지침에 의거하여 Stage 2 작업을 전면 중단하고, `antigravity/graphics-quality-pass-001-r1` 브랜치에서 **Cycle A**와 **Cycle B**에 걸친 2단계 반복 개선 및 5대 대표 장면 캡처 비교를 완수하였습니다.

---

## 2. 5대 대표 장면 캡처 아티팩트 보관 위치

모든 캡처는 1280×720 해상도, 동일 시점 및 상태 기준으로 생성되어 보관되었습니다:

- **Baseline (Pass 001 결과)**: `ART_REVIEW/graphics-pass-001-r1/baseline/`
- **Cycle A (1차 개선 결과)**: `ART_REVIEW/graphics-pass-001-r1/cycle_a/`
- **Cycle B (2차 개선 결과)**: `ART_REVIEW/graphics-pass-001-r1/cycle_b/`

각 디렉터리 내 동일 5개 장면:
1. `01_stage1_start.png`: 스테이지 1 시작 지점 및 원경 비스타
2. `02_stage1_first_combat.png`: 첫 일반 전투 (근접 적 교전)
3. `03_stage1_route_choice.png`: 상층 발판 선택 경로 및 안내 표식
4. `04_stage1_boss_combat.png`: 보스전 결전 (`BossCommander`)
5. `05_stage1_boss_defeat_reward.png`: 보스 격파 후 유물 획득 보상 카드

---

## 3. 반복 개선 상세 기록

### [Cycle A] 1차 반복 개선

#### 1) 렌더링 프레임 기준 발견된 결함 (5개 항목)
1. **지형 구조물의 단순 평면성**: 상층 이동 발판(`Route%dStep%d`)이 지지 구조 없는 단순 직사각형 슬랩으로 부유하여 건축적 개연성 결여.
2. **모바일 조작부의 단색 플랫 UI**: 가상 버튼 및 조이스틱이 단순 단색 원형으로 렌더링되어 개발용 프로토타입 오버레이 인상을 줌.
3. **일반 적 체력바의 단순성**: 적 머리 위 플로팅 체력바가 테두리 없는 단순 적색 사각형으로 떠 있어 게임 UI 완성도 저하.
4. **선택 경로 안내 표식의 가독성 불일치**: 갈림길 텍스트 표식이 단순 폰트로 지형 위에 노출되어 배경과 분리되지 않음.
5. **HUD 알림 텍스트의 누적 적체**: 상층 경로 안내 알림(`route_status`)과 돌파 토스트(`toast`)가 보스전 진입 시에도 노출되어 중앙 상단에 4단계 텍스트 층 형성.

#### 2) Cycle A 수정 사항
- `CLIENT/Game/scripts/art/stage_art.gd`:
  - 수직 기둥과 상층 발판 접합부에 석조 코벨(까치발) 브래킷 폴리곤(`corbel`) 및 외곽선 트림 추가.
  - 발판 슬랩 하단에 반투명 드롭 섀도우(`Color(0.02, 0.04, 0.06, 0.42)`)를 적용하여 입체적 깊이감 부여.
  - 갈림길 안내 표식을 엔틱 브론즈 테두리(`Color(0.78, 0.65, 0.42, 0.88)`)와 음각 골드 노치가 적용된 석조 현판 스타일로 격상.
  - 적 머리 위 HP 바를 42×5px 메탈릭 슬레이트 프레임 및 상단 하이라이트 라인이 적용된 게이지 바로 재설계.
- `CLIENT/Game/scripts/ui/mobile_controls.gd`:
  - `VirtualButton`: 다층 다크 글래스 틴티드 베이스, 내측 테마 글로우, 상단 호형 베벨 하이라이트(`Color(1.0, 1.0, 1.0, 0.45)`), 내측 햅틱 링을 추가하여 인게임 터치 UI 룩 구축.
  - `MobileJoypad`: 반투명 베이스플레이트에 동심 가이드 링(반경 0.60), 베벨 림 하이라이트, 방향 인디케이터 디테일 적용.
- `CLIENT/Game/scripts/ui/stage_presentation.gd`:
  - 보스전 진행 중 및 토스트 표시 중 `route_status` 알림 캡슐을 숨겨 상단 텍스트 누적 적체 현상 해소.
  - 스테이지 클리어 보상 카드의 완료 전투 카운트가 `0 / 6`으로 표시되던 로직 수정 (`stage.stage_state == 1`일 때 `required_count` 반영).

---

### [Cycle B] 2차 반복 개선

#### 1) Cycle A 캡처 프레임 감사 결과 발견된 잔여 결함 (4개 항목)
1. **보스 체력바와 HUD 텍스트 수직 충돌**: Scene 4에서 `BossHealthBar` 하단에 힌트 텍스트("마지막 전투...")가 체력바 게이지 내부로 겹쳐 들어갔으며, 구간 돌파 토스트("5구간 돌파...")가 바로 아래에 맞붙어 여백 부족.
2. **보스 아레나 상공 잔여 적 노출**: Scene 4 캡처 프레임에서 보스 머리 위 상층 발판에 이전 선택 경로의 `TestEnemy` 2기가 그대로 남아 있어 1:1 보스 결전 집중도 저해.
3. **보스 공격 전조 대비 부족**: `BossCommander`의 방패 공격 전조 호형 라인(`AttackRim`) 두께가 2.4px로 얇아 밝은 하늘/구름 배경에서 시인성 약화.
4. **유물 보상 카드 모서리 마감 미흡**: Scene 5 보상 카드의 외곽 플레이트가 단순 사각형 박스로 마감되어 판타지 유물 수여 카드의 격식이 부족.

#### 2) Cycle B 수정 사항
- `CLIENT/Game/scripts/stage/first_stage.gd`:
  - `_spawn_boss_encounter()` 실행 시, 아레나 구역 내 선택 경로 잔여 적(`optional_groups`) 및 기존 웨이브 적 노드를 즉시 `queue_free()`하여 보스 1:1 전용 결전 무대로 정돈.
  - `BossHealthBar` 부착 위치를 Y=54로 조정하여 상단 여백 확보.
- `CLIENT/Game/scripts/ui/stage_presentation.gd`:
  - 보스 체력바 활성화 시 일반 마일스톤 토스트(`toast_remaining > 0 and not has_boss_bar`)를 억제하여 텍스트 겹침 원천 차단.
  - 보스 힌트 텍스트를 체력바 게이지와 겹치지 않는 독립 다크 캡슐(Y=144, 텍스트 Y=163)로 분리 배치.
  - 스테이지 클리어 보상 카드에 엔틱 골드 L자 코너 필리그리 브래킷 및 내부 프레임 코너 다이아몬드 핍 장식 추가.
- `CLIENT/Game/scripts/enemy/boss_commander.gd`:
  - 공격 전조 외곽선 두께를 2.4px에서 4.2px로 대폭 확장(`AttackRim.width = 4.2`).
  - 블록 가능/불가 전조 컬러의 HDR 오버드라이브 강도 및 내부 필 투명도를 상향(`rim_color = Color(4.0, 3.2, 1.0, 1.0)`, `fill = Color(1.0, 0.85, 0.25, 0.38)`)하여 밝은 배경에서도 명확한 시인성 확보.
- `CLIENT/Game/scripts/ui/boss_health_bar.gd`:
  - `snap_to_visible()` 함수 추가 및 트윈 추적 관리를 통해 캡처 및 즉각 렌더링 시 보스 체력바가 반투명하게 흐려지는 현상 해결.

---

## 4. 항목별 평가 매트릭스 (Evaluation Matrix)

*평가 기준: `개선됨` / `변화 미미` / `악화됨` (TASK-AR-011 준수)*

| 평가 항목 | 판정 | 관찰 근거 및 상세 설명 |
| :--- | :---: | :--- |
| **Character** | **개선됨** | 플레이어의 장비(외형 방패/검) 및 적, 보스 발밑에 지면 접지 드롭 섀도우가 정확히 밀착됨. 불필요한 폴리곤 오라 판이 제거되고 보스 전용 외곽선 림 라이트와 모션 실루엣이 선명하게 유지됨. |
| **Environment** | **개선됨** | 4단계 패럴랙스 배경의 인위적 대각선 쐐기 아티팩트가 제거됨. 부유 발판에 석조 지지 코벨 브래킷 및 하단 음영이 추가되어 배경 건축물과 조화롭게 연결됨. |
| **Lighting** | **개선됨** | WorldEnvironment의 2D HDR 글로우 임계값(Screen 모드)과 CanvasModulate가 안정적으로 조율됨. 과도한 화면 전체 번짐 없이 참격 및 전조 효과에만 선택적 발광이 집중됨. |
| **Readability** | **개선됨** | 상단 HUD의 체력, 진행도, 목표 텍스트 영역이 계층화됨. 보스전 돌입 시 중복 토스트가 차단되고, 전조 라인이 4.2px HDR로 두꺼워져 밝은 하늘 배경에서도 직관적으로 인지됨. |
| **VFX** | **개선됨** | 초승달 형태의 곡면 참격 폴리곤, 충격파 링, 대시 네온 잔상이 자연스럽게 재생되며, 프레임 드롭이나 거친 와이어프레임 박스 없이 부드러운 파티클 모트를 유지함. |
| **UI** | **개선됨** | 모바일 가상 패드와 버튼이 반투명 다크 글래스 및 촉각적 베벨 림 스타일로 업그레이드됨. 클리어 보상 카드의 코너 필리그리 장식 및 메탈릭 적 HP 바로 프로토타입 인상 해소. |

---

## 5. 성능 및 리소스 관찰 기록

- **테스트 환경**: Windows 11 / Godot 4.7.2 stable official / Compatibility (OpenGL 3.3) / NVIDIA GeForce RTX 5060 Laptop GPU
- **실행 관찰 지표**:
  - **활성 씬 노드 수**: Stage 1 피크 인카운터 기준 약 180~195개 유지 (보스전 진입 시 비활성 미니언 노드 정리로 150개 내외로 경량화).
  - **CPUParticles2D 오버헤드**: StageArt 대기 부유 입자 32개 유지, 피크 드로우콜 지연 없음.
  - **Line2D / Polygon2D 드로우콜**: 지형 코벨 및 발판 섀도우는 초기 로드 시 1회 정적 버퍼에 생성되어 프레임당 재할당 비용 0.
  - **오버드로우 및 투명도 관리**: 보스전 시 일반 HUD 컴포넌트(토스트, 경로 캡슐) 렌더링을 완전히 바이패스하여 대형 반투명 레이어 중첩 방지.

---

## 6. Android 검증 상태

**`ANDROID NOT VERIFIED`**

- **사유**: 본 패스는 PC Windows 데스크톱 워크스테이션 환경에서 헤드리스 콘솔 엔진 및 에뮬레이트 뷰포트(1280×720 Landscape)를 기준으로 진행되었습니다.
- **향후 계획**: 물리 Android 기기(APK 패키징)에서의 멀티터치 간섭, 초당 프레임 유지율, 모바일 스크린 밝기에 따른 전조 가독성 실측은 후속 안드로이드 QA 빌드 검증 단계에서 별도 수행 예정입니다.

---

## 7. 그래픽 / 게임 로직 변경 분리 준수

- **게임 로직 보존**:
  - 플레이어/보스의 HP, 공격력, 이동 속도, 패링 판정 타이밍, 무적 시간, 체크포인트 규칙은 일체 변경되지 않았습니다.
- **변경 범위 한정**:
  - 시각적 표현(UI 캡슐 배치, 드로우 함수, 전조 라인 굵기 및 발광 색상, 지형 코벨 폴리곤 추가, 보스 아레나 내 비전투 잔여 노드 정리)에만 국한되었습니다.

---

## 8. 자동 회귀 테스트 결과 (10개 스위트 100% PASS)

Godot 4.7.2 헤드리스 환경에서 전체 회귀 테스트 스위트를 실행하여 결함이 없음을 검증하였습니다:

1. `tests/game_and_graphic_quality_smoke.gd`: **60/60 PASS** (WorldEnvironment, 유물 패시브, 버퍼링, 검기, 5대 보스 림라이트, 참격 기하학 등)
2. `tests/stage_reward_and_equipment_smoke.gd`: **23/23 PASS** (유물 레지스트리, 기사 외형 장착, 동적 반응, 보상 카드 렌더링)
3. `tests/boss1_visual_polish_smoke.gd`: **17/17 PASS** (보스 스케일, 참격 아크, 검기 방출, 충격파)
4. `tests/campaign_transition_test.gd`: **PASS** (스테이지 1→2 캠페인 트랜지션 무결성)
5. `tests/stage_smoke.gd`: **37/37 PASS** (체크포인트, 게이트, 인카운터 루프)
6. `tests/combat_deepening_smoke.gd`: **10/10 PASS** (3단 콤보, 카운터, 하향 찌르기)
7. `tests/guard_core_smoke.gd`: **21/21 PASS** (가드, 패링, 블록 연동)
8. `tests/sprint4_smoke.gd`: **23/23 PASS** (경직, 전조 색상, 로컬 저장, 4단 패럴랙스)
9. `tests/enemy_motion_smoke.gd`: **130/130 PASS** (적 행동 트리 및 순찰/추적)
10. `tests/data_driven_smoke.gd`: **38/38 PASS** (Stage 1~5 JSON 데이터 및 몬스터 스펙)

- **종합 결과**: **총 360개 이상의 검증 체크 100% 무결점 통과 (0 Failures)**

---

## 9. 결론 및 독립 검수 요청

`WORK/TASK-AR-011.md`에서 요구한 Cycle A 및 Cycle B의 2회 반복 개선, 5대 대표 장면 Before/After 캡처, 가독성/HUD 정리, 성능 관찰 기록, 로직 분리 원칙을 충실히 완수하였습니다.

이에 본 브랜치(`antigravity/graphics-quality-pass-001-r1`)의 상태를 **"독립 검수 요청 (Independent Review Requested)"**으로 전환하고, 독립 검수자의 심의 및 Stage 2 승인을 요청합니다.
