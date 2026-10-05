# Stage 1 성능 측정 방법론 교정 및 검증 보고서 (Performance Validation Report)

- **문서 버전**: Pass 001-R2.1
- **대상 작업**: TASK-AR-013 Stage 1 Graphics Pass 001-R2.1 성능 검증 및 최종 승인 게이트
- **작성일**: 2026-10-05
- **담당**: Antigravity / JPStudio Graphics Quality Director + Client QA
- **모바일 검증 상태**: **`ANDROID PERFORMANCE NOT VERIFIED`** (PC 정밀 계측 기반, Android 실기 측정 전까지 보류)

---

## 1. 계측 환경 사양 (Test Environment Specification)

모든 벤치마크는 동일한 하드웨어, 소프트웨어, 해상도 조건에서 통제되어 실행되었습니다.

| 항목 | 상세 규격 |
| :--- | :--- |
| **Engine Version** | Godot Engine v4.7.2-stable.official.ed1daf0bf |
| **Renderer** | GL Compatibility (OpenGL 3.3.0 NVIDIA 610.47) |
| **Operating System** | Windows 11 Home (10.0.26200) |
| **CPU** | AMD Ryzen 9 8945HX with Radeon Graphics (16 Cores / 32 Threads) |
| **GPU** | NVIDIA GeForce RTX 5060 Laptop GPU (VRAM 8GB) |
| **Resolution** | 1280 × 720 Landscape (`canvas_items`, `expand`) |
| **VSync 상태** | **DISABLED** (런타임 `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)` 적용, `project.godot` 원본 보존) |
| **FPS Cap 상태** | **UNLIMITED** (`Engine.max_fps = 0`) |
| **측정 실행 방식** | 1) 독립 창 모드 (Always-on-top, 600 프레임/구간 실측)<br>2) 헤드리스 엔진 모드 (슬립 0us, 순수 CPU 스텝 계측) |
| **측정 프레임 수** | 구간별 최소 600 ~ 1,500 프레임 (워밍업 1.5초 분리) |

---

## 2. 기존 R2 성능 보고서 비정상 수치(98~165 ms) 원인 규명

### 2.1 기존 보고서의 모순 현상
기존 `ART_REVIEW/graphics-pass-001-r2/performance.md`에 기록되었던 지표:
- Stage 1 Start: FPS ≈ 60, Process Time ≈ 16.135 ms, Physics Time ≈ 165.355 ms
- First Combat: FPS ≈ 60, Process Time ≈ 98.771 ms
- Boss Combat: FPS ≈ 60, Process Time ≈ 126.740 ms

60 FPS 환경(프레임 타임 약 16.6 ms)에서 Process 또는 Physics 시간이 98~165 ms에 달하는 것은 단일 프레임 주기와 수학적으로 양립할 수 없습니다.

### 2.2 Godot 4.7.2 엔진 소스 코드 분석 (`main/main.cpp`)
Godot 엔진 코어의 성능 모니터 집계 구현을 추적한 결과:

```cpp
// godot/main/main.cpp
static uint64_t process_max = 0;
static uint64_t physics_process_max = 0;

// 매 프레임:
process_ticks = OS::get_singleton()->get_ticks_usec() - process_begin;
process_max = MAX(process_ticks, process_max);

// 1초(1,000,000us) 누적 윈도우 만료 시:
if (frame > 1000000) {
    performance->set_process_time(USEC_TO_SEC(process_max));
    performance->set_physics_process_time(USEC_TO_SEC(physics_process_max));
    process_max = 0;
    physics_process_max = 0;
    frame %= 1000000;
}
```

이 구조로부터 확인된 사실:
1. **값의 단위**: `USEC_TO_SEC`로 초 단위 저장되므로 `* 1000.0` 변환 자체는 단위상 올바릅니다.
2. **모니터의 실제 의미**: `Performance.TIME_PROCESS`는 현재 프레임의 소요 시간도 아니고, 평균 소요 시간도 아닙니다. **직전 1초 동안 발생한 모든 프레임 중 '단일 프레임 최대값(Peak)'을 보존하는 레지스터**이며, 1초에 단 1회만 갱신됩니다.
3. **측정 코드의 방법론적 오류**:
   - `stage1_performance_benchmark.gd`는 `_setup_stage()` 직후 워밍업 없이 즉시 측정을 시작했습니다.
   - 씬 인스턴스화, 셰이더 컴파일, 텍스처 업로드로 인해 첫 1~2프레임에 약 100~160 ms의 로딩 피크 스파이크가 발생했습니다.
   - `process_max` 및 `physics_process_max`는 이 로딩 스파이크를 1초 동안 유지합니다.
   - 측정 스크립트는 150~240 프레임 동안 매 프레임 고정된 100~165 ms 피크 값을 읽어와 산술 평균을 냈습니다 (`avg_proc /= float(process_times.size())`).
   - 그 결과, 실제 실행 프레임 타임은 4~6 ms였음에도 불구하고 **"평균 프로세스 타임이 98~165 ms"라는 거짓 수치가 산출**된 것입니다.

### 2.3 인위 부하 프로브 검증 (`perf_monitor_semantics_probe.gd`)
게임 로직을 배제하고 단일 인위 부하를 주입하는 프로브 테스트를 통해 이를 실험적으로 100% 입증했습니다.

| 실험 시나리오 | 주입 부하 | 실측 프레임 dt | `TIME_PROCESS` 모니터 값 | 비고 |
| :--- | :---: | :---: | :---: | :--- |
| **초기 1회 120ms 부하** | 120.0 ms (1회) | ~6.8 ms (일정) | **120.5 ms 유지** | 1초 윈도우 내내 120ms 피크 값 보존 |
| **유휴 상태 (3초)** | 0 ms | ~4.2 ms | 0.1 ~ 0.2 ms | 1초에 1회만 값 갱신 (distinct=3~4) |
| **중간 1회 100ms 스파이크** | 100.0 ms (1회) | ~4.2 ms (스파이크 후 복귀) | **100.1 ms 유지 (1.2초간)** | 이후 다음 1초 윈도우에서 0.06ms로 리셋 |
| **매 프레임 2ms 지속 부하** | 2.0 ms (매 프레임) | ~4.1 ms | 2.1 ~ 2.2 ms | 지속 부하 시에는 정상 피크 반영 |

**결론**: 기존 R2 성능 보고서의 98~165 ms 수치는 **엔진의 1초 피크 보존 모니터(`process_max`)를 매 프레임 평균 낸 벤치마크 코드 자체의 명백한 측정 결함**이었음을 공식 확인하였습니다.

---

## 3. 교정된 성능 측정 방법론 (Corrected Methodology)

TASK-AR-013에서는 기존 결함을 제거한 신규 벤치마크 스위트 [`stage1_perf_validation.gd`](file:///D:/JUNYPAPA_STUDIO/Worktrees/ProjectKnight/ART-STAGE-BATCH-001/CLIENT/Game/tests/stage1_perf_validation.gd)를 구축하여 적용했습니다.

1. **시그널 기반 정밀 구간 측정**:
   - `physics_iter_ms`: `physics_frame` 시그널부터 해당 반복의 물리 연산 실제 소요 시간.
   - `process_ms`: `process_frame` 시그널부터 `RenderingServer.frame_pre_draw` 직전까지 (노드 `_process()` 및 `_draw()` 큐잉 시간).
   - `render_ms`: `frame_pre_draw`부터 `frame_post_draw`까지 (OpenGL 드로우콜 제출 및 버퍼 스왑).
   - `frame_ms`: 프레임 간 전체 델타 타임 (`process_frame` 간격).
2. **워밍업 윈도우 분리**:
   - 씬 인스턴스화 후 1.5초간의 워밍업을 거쳐 셰이더 컴파일/초기 텍스처 업로드가 끝난 안정 상태(Steady State)에서만 본 측정을 개시.
3. **충분한 통계 표본 확보**:
   - 각 구간 최소 600 프레임 이상 샘플링 (권장 기준 준수).
   - Average, Min, 1% Low FPS 및 P95, P99, Max 프레임 타임 산출.
4. **런타임 VSync / FPS Cap 제어**:
   - 프로젝트 설정 파일 영구 수정 없이 스크립트 실행 중에만 `VSYNC_DISABLED` 및 `max_fps = 0` 적용.
5. **게임플레이 상태 보존**:
   - 게임 규칙, AI, 인카운터 로직은 일절 변경하지 않음.
   - 벤치마크 루프 도중 플레이어 사망에 따른 비동기 씬 리셋 방지 로직은 테스트 스크립트 내부에서만 격리 처리.
