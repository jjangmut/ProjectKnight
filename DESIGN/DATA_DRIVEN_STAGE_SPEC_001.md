# 데이터 드리븐 스테이지 및 몬스터 아키텍처 명세서

- 문서 ID: `DESIGN/DATA_DRIVEN_STAGE_SPEC_001.md`
- 작성자: Planning Lead / Client Lead 공통
- 승인 기준: `WORK/DEC-008.md`
- 대상: 스테이지 하드코딩 제거 및 JSON 데이터 기반 로더 설계

---

## 1. 개요 및 목적

기존 `first_stage.gd`는 월드 폭, 게이트 위치, 적 스폰 수량, 체크포인트 좌표를 GDScript 내부 수식(`stride`, `for index` 등)으로 하드코딩하여 관리했다.
이는 새로운 몬스터 추가, 레벨 배치 수정, 밸런스 튜닝 시 매번 코드를 수정해야 하는 치명적인 병목을 유발한다.

버티컬 슬라이스에서는 **"기획자가 데이터(JSON)를 수정하면 코드를 건드리지 않고 게임에 즉각 반영되는"** 데이터 드리븐 구조를 확립한다.

---

## 2. 데이터 디렉터리 구조

```text
CLIENT/Game/data/
├── monsters.json               # 모든 몬스터의 기본 속성 및 AI 밸런스 시트
├── player_combat.json          # 플레이어 콤보, 가드 카운터 수치
└── stages/
    ├── stage_01.json           # 1지역 성문 외곽 (폭, 배경, 인카운터, 체크포인트)
    ├── stage_02.json           # 2지역 야수숲
    ├── stage_03.json           # 3지역 무너진 성벽
    ├── stage_04.json           # 4지역 돌의 성소
    └── stage_05.json           # 5지역 침묵의 성채
```

---

## 3. 데이터 스키마 정의

### 3.1. 몬스터 데이터 (`monsters.json`)

```json
{
  "monster_id": {
    "name": "표시 명칭",
    "scene_path": "res://scenes/enemy/몬스터.tscn",
    "max_hp": 2,
    "move_speed": 120.0,
    "detection_range": 320.0,
    "attack_range": 60.0,
    "attack_windup": 0.65,
    "attack_active": 0.15,
    "attack_cooldown": 0.80,
    "is_blockable": true,
    "warning_vfx": "none | orange_cross | red_flash",
    "telegraph_type": "windup_pose | ground_shake | eye_flash",
    "hit_stun_duration": 0.25
  }
}
```

### 3.2. 스테이지 데이터 (`stages/stage_XX.json`)

```json
{
  "stage_id": 1,
  "theme": "castle_outskirts",
  "world_width": 11000.0,
  "ground_height": 660.0,
  "background_layers": [
    { "layer": "sky", "texture": "res://assets/backgrounds/s01_sky.png", "scroll_speed": 0.05 },
    { "layer": "distant_castle", "texture": "res://assets/backgrounds/s01_castle.png", "scroll_speed": 0.2 },
    { "layer": "middle_ruins", "texture": "res://assets/backgrounds/s01_ruins.png", "scroll_speed": 0.5 }
  ],
  "encounters": [
    {
      "index": 1,
      "entry_x": 400.0,
      "gate_x": 1600.0,
      "waves": [
        { "enemies": [{ "type": "melee_soldier", "offset_x": 200.0 }] },
        { "enemies": [{ "type": "melee_soldier", "offset_x": 150.0 }, { "type": "melee_soldier", "offset_x": 300.0 }] }
      ]
    }
  ],
  "checkpoints": [
    { "index": 1, "x": 1780.0, "y": 580.0, "required_encounter_prefix": 2 }
  ],
  "optional_routes": [
    {
      "id": "opt_01",
      "start_x": 2200.0,
      "end_x": 3100.0,
      "rises": [60, 120, 180, 180, 120, 60],
      "reward": "hp_plus_one",
      "enemies": [{ "type": "melee_soldier", "x_offset": 0.0 }]
    }
  ],
  "goal_x": 10700.0
}
```

---

## 4. 클라이언트 StageLoader와의 역할 분담

1. **Planning Lead**: `monsters.json`과 `stages/stage_XX.json`의 수치 및 레벨 배치 데이터를 직접 편집/커밋.
2. **Client StageLoader (`stage_loader.gd`)**:
   - JSON 파싱 시 스키마 유효성 검사.
   - 데이터에 정의된 좌표에 StaticBody(지형, 게이트), Area2D(체크포인트, 골), CharacterBody2D(적 몬스터)를 동적 인스턴스화.
   - 기존의 견고한 체크포인트 씬 복원 메커니즘(`resume_snapshot`)을 그대로 유지.
