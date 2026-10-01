---
name: game-quality-director
description: >-
  Project Knight의 그래픽 퀄리티(WorldEnvironment 2D Glow, 앰비언스 CanvasModulate, 다층 파티클, 보스 전용 VFX)와
  게임 퀄리티(공중-지상 콤보 버퍼링, 저스트 패링 타격감, 유물 패시브 스탯 연동, 카메라 셰이크 & 히트스탑 조율)를
  AAA 인디 액션 플랫폼 게임 수준으로 유지하고 지속적으로 고도화하는 전문 디렉터 스킬입니다.
---

# Game Quality Director: Visual & Combat Polish Standard

이 스킬은 **Project Knight**의 그래픽과 게임플레이 완성도를 콘솔/스팀 명작 인디 액션(예: Hollow Knight, Dead Cells, Ender Lilies) 수준으로 끌어올리기 위한 기술 지침과 제작 프로세스를 정의합니다.

---

## 1. Visual Quality Pillars (그래픽 퀄리티 표준)

### 1) 2D Glow & WorldEnvironment
- 2D 씬에서도 단순 플랫한 폴리곤이 아닌 빛나는 에너지와 아우라를 표현하기 위해 `WorldEnvironment`를 필수 배치합니다.
- **Environment 설정**:
  - `glow_enabled = true`
  - `glow_levels/1 = 1.0`, `glow_levels/2 = 1.0`, `glow_levels/4 = 0.5`
  - `glow_blend_mode = GLOW_BLEND_MODE_SCREEN` 또는 `SOFTLIGHT`
  - `glow_hdr_threshold = 1.0`, `glow_hdr_scale = 1.5`
- 광선, 검기, 패링 스파크, 보스 아우라는 RGB 값을 1.2~2.5 이상의 HDR 오버드라이브 컬러를 사용하여 자연스러운 빛 번짐(Glow Bloom) 효과를 창출합니다.

### 2) Atmosphere & Ambient Lighting (CanvasModulate)
- 스테이지별 고유 테마를 전달하는 은은한 색조 보정:
  - **Stage 1 (Castle Outskirts)**: 여명의 차분한 미드나잇 블루 & 골드 (`Color(0.88, 0.92, 1.0, 1.0)`)
  - **Stage 2 (Wild Beast Forest)**: 울창하고 신비로운 딥 에메랄드 (`Color(0.85, 0.98, 0.88, 1.0)`)
  - **Stage 3 (Ruined Ramparts)**: 붉은 노을과 잿빛 황혼 (`Color(1.0, 0.88, 0.82, 1.0)`)
  - **Stage 4 (Stone Sanctuary)**: 고대 유적의 신성한 청록빛 틸 (`Color(0.82, 0.95, 0.98, 1.0)`)
  - **Stage 5 (Abyssal Citadel)**: 심연의 어두운 나이트 바이올렛 (`Color(0.78, 0.72, 0.92, 1.0)`)

### 3) Atmospheric Floating Particles (환경 부유 파티클)
- 공기 중에 떠다니는 먼지 가루, 바람에 날리는 잔불(Embers), 마력 포자(Spores)를 카메라 주변에 부드럽게 흩날려 정적인 배경의 느낌을 완전히 탈피합니다.

### 4) Boss Visual Identity Parity (보스 비주얼 격차 해소)
- 모든 보스(1~5스테이지)는 다음 4종 비주얼 키트를 공통 장착합니다:
  - **고유 림라이트 아우라**: 보스 외형을 감싸는 전용 배후 광배.
  - **고유 스킬 다층 참격/발사체 VFX**: 외곽 발광선 + 내부 백열 코어 라인 + 잔상 궤적.
  - **바닥 지면 충격파**: 좌/우 확산 충격파 및 파쇄 파티클.
  - **헤드라이딩 탑 플랫폼**: 플레이어가 보스 머리 위로 점프하여 밟거나 내려찍기 가능.

---

## 2. Gameplay Quality Pillars (게임 퀄리티 표준)

### 1) Input Buffering & Combo Chaining (조작감 유예)
- **공중 공격 -> 착지 지상 연계**: 공중 공격 중 착지할 때 0.12초의 공격 선입력 버퍼를 두어, 착지하자마자 콤보 1타가 즉시 부드럽게 이어져야 합니다.
- **점프/회피 선입력**: 0.14초 점프 버퍼와 0.12초 코요테 타임을 항시 유지합니다.

### 2) Boss Relic Real Passive Buffs (유물 스탯 인게임화)
- 유물은 단순 수집품이 아닌, 플레이 스타일을 진화시키는 패시브 버프여야 합니다:
  - **요새의 방패 (Stage 1)**: 가드 시 넉백 50% 흡수 및 가드 후딜레이 25% 감소
  - **그림자 망토 (Stage 2)**: 대시 쿨다운 -0.07초 및 대시 이동속도 +15%
  - **바람의 화살통 (Stage 3)**: 검기 사거리 +100px 및 관통 횟수 +1
  - **타이탄 견갑 (Stage 4)**: 공중 찍기(Down Thrust) 충격파 반경 +40% 및 지면 파쇄
  - **심연의 관 (Stage 5)**: 저스트 패링 시 크리티컬 카운터 4 데미지 (기본 2, 패링 3, 관 4)

### 3) Projectile World Interaction (발사체 지형 상호작용)
- 검기([sword_beam.gd](file:///D:/JUNYPAPA_STUDIO/Worktrees/ProjectKnight/ART-STAGE-BATCH-001/CLIENT/Game/scripts/player/sword_beam.gd)) 및 적 투사체는 지형과 충돌 시 벽을 뚫지 않고 스파크 파티클을 방출하며 자연스럽게 파괴되어야 합니다.

---

## 3. Verification Protocol (품질 검증 원칙)

1. 모든 그래픽 및 게임플레이 변경은 Godot 콘솔 엔진 헤드리스 스위트로 100% 통과 검증을 마쳐야 합니다:
   `& "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" --headless -s tests/<quality_smoke_script>.gd`
2. 프레임 드랍(60fps 미달)이나 메모리 누수(ObjectDB leak)가 없어야 합니다.
