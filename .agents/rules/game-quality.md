# Game Quality & Graphic Polish Rules

## 1. Visual Quality Standard
- **Glow & Atmosphere**: 모든 2D 스테이지 씬은 `WorldEnvironment`의 HDR Glow 및 스테이지별 앰비언스 틴트(`CanvasModulate`)를 지원해야 합니다.
- **VFX Overdrive**: 검기, 패링 스파크, 보스 참격선 등 모든 발광 이펙트는 `Color(r, g, b, a)`에서 RGB 값이 1.0을 초과하는 HDR 컬러(예: `Color(1.5, 1.2, 0.4, 1.0)`)를 사용하여 풍부한 블룸(Bloom) 빛번짐을 형성합니다.
- **Environment Particles**: 정적인 배경을 방지하기 위해 공기 중 부유 파티클(Floating Embers/Motes)이 활성화되어야 합니다.

## 2. Combat & Game Feel Standard
- **Input Responsiveness**: 공중 공격 착지 직후 지상 공격 선입력 버퍼링(0.12s)을 제공하여 조작 끊김을 방지합니다.
- **Relic Gameplay Integration**: 해금된 보스 유물은 시각적 외형 장비뿐 아니라, 플레이어 인게임 스탯/메커니즘(방어 경감, 대시 강화, 검기 사거리, 하향찍기 충격파, 크리티컬 극대화)에 즉각 반영되어야 합니다.
- **Collision Integrity**: 검기 투사체는 지형과 충돌 시 벽을 통과하지 않고 타격 파편과 함께 소멸되어야 합니다.

## 3. Autonomous QA Standard
- 변경 사항은 반드시 Godot 엔진 헤드리스 스위트로 100% PASS 검증을 통과해야 합니다.
