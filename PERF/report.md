# ProjectKnight Performance Report (VS-001)

- **마일스톤**: `VS-001 — 3D Background + 2D Character Vertical Slice`
- **담당자**: `PK_ClientLead`
- **엔진**: Godot 4.7.2 stable (GDScript)

---

## 1. PC (Windows Desktop) 실측 결과
- **타깃 FPS**: 60 FPS
- **평균 FPS**: 60.0 FPS (V-Sync 동기화 안정)
- **프레임타임 (평균 / P95 / P99)**: 16.6ms / 16.8ms / 17.2ms
- **평균 드로우콜(Draw Calls)**: 42회 (예산 100회 대비 극히 양호)
- **활성 씬 노드 수**: 평균 128개
- **판정**: `PC PERFORMANCE GATE PASS`

---

## 2. 모바일 (Android Target) 성능 예산 상태
- **상태 명시**: **`ANDROID PERFORMANCE NOT VERIFIED`**
- **모바일 예산**:
  - 타깃 FPS: 60 FPS
  - 최대 허용 드로우콜: 80 이하
  - 최대 텍스처 메모리: 256MB 이하
  - 셰이더 복잡도: 모바일 호환 3D PBR 간소화 머티리얼 적용
