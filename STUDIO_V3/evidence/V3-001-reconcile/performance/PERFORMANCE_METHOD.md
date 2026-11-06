# V3-001 — Performance Methodology & Reconciliation Report

**Task ID:** `V3-001-EVIDENCE-RECONCILE`  
**Target:** Reconciliation of V3-001 Performance Telemetry & Workload Attributability  
**Audited Raw Dataset:** `STUDIO_V3/evidence/V3-001/performance/raw_frames.csv` (14,404 rows, 100% preserved)  
**Original Summary JSON:** `STUDIO_V3/evidence/V3-001/performance/performance.json`  
**Reconciled Analysis JSON:** `STUDIO_V3/evidence/V3-001-reconcile/performance/analysis_output.json`  
**Benchmark Harness Source:** `STUDIO_V3/evidence/V3-001-reconcile/performance/benchmark_source/benchmark_stage1_windowed.gd`  
**Date:** 2026-11-07  

---

## 1. Executive Summary & Core Discrepancy Resolution

In the initial audit report of `V3-001`, an apparent 4× contradiction existed between the summary report and the raw CSV dataset:
- **Summary Report:** Stated Mean FPS: `60.03 FPS`, 1% Low FPS: `59.46 FPS`.
- **Raw CSV Data:** The `fps` column recorded `239.0` to `240.0 FPS` across all walking, normal combat, and boss combat sectors, with a median of `240.0 FPS`.
- **Raw Sample Delta:** The `dt_ms` column recorded an elapsed delta of approximately `16.666 ms` per sample.

### Root Cause Analysis

By recovering and examining the authentic benchmark script [`benchmark_stage1_windowed.gd`](benchmark_source/benchmark_stage1_windowed.gd) (SHA256: `6ef89c7bf6d7df2adac1de9c136356bfe921e6f13c7eee8b61bf7246cee85516`), the mechanism is completely identified:

1. **Sampling Hook Location (`_physics_process`):**
   ```gdscript
   func _physics_process(delta: float) -> bool:
       var now := Time.get_ticks_usec()
       var dt_ms := float(now - prev_frame_ticks) / 1000.0
       prev_frame_ticks = now
       ...
       var sample := {
           "dt_ms": dt_ms,
           "proc_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
           "phys_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
           "fps": Performance.get_monitor(Performance.TIME_FPS),
           ...
       }
   ```
2. **Fixed Physics Rate:** In Godot 4.x, `physics/common/physics_ticks_per_second` defaults to `60`. Consequently, `_physics_process()` is dispatched by the engine at a fixed cadence of $60.0\text{ Hz}$ ($\Delta t \approx 16.666\text{ ms}$).
3. **Calculation Confusion in Initial Summary:**
   The metrics labeled `mean_fps: 60.03` and `low_1pct_fps: 59.46` were computed in `_calc_stats()` as $1000.0 / \text{mean\_dt}$ and $1000.0 / \text{p99\_dt}$. Therefore, these figures represented the **Physics Tick Sampling Rate (Hz)**, NOT the graphics rendering framerate!
4. **Actual Graphics Framerate:**
   The actual graphics render framerate was recorded by `Performance.get_monitor(Performance.TIME_FPS)` into the `fps` column. Because the benchmark ran on an NVIDIA GeForce RTX 5060 Laptop GPU connected to a 240 Hz panel without VSync throttling below monitor refresh, Godot's render loop executed at **~239.5 FPS** (median 240.0 FPS).
5. **Frame Process Headroom:**
   Godot's `TIME_PROCESS` averaged **4.30 ms** per frame. At 240 FPS ($1000 / 240 \approx 4.16\text{ ms}$), the render loop was fully active and operating near display refresh capacity. Under the target 60 FPS mobile/PC budget ($16.67\text{ ms}$), this leaves over **11.5 ms of process headroom**.

---

## 2. Telemetry Classification & Reconciled Metrics

| Metric Dimension | Initial Label | Reconciled Definition | Measured Value | Qualification Status |
| :--- | :--- | :--- | :--- | :--- |
| **Engine Render Framerate** | 240 FPS (in CSV) | Graphic render loop frames per second (`TIME_FPS`) | **239.54 FPS mean, 240.0 FPS median** | **VERIFIED (PC Windowed)** |
| **Physics Sampling Cadence** | 60.03 FPS (in JSON) | Sampling tick frequency ($1000 / \Delta t_{\text{phys}}$) | **60.03 Hz mean, 59.46 Hz 1% low** | **VERIFIED (Physics Ticks)** |
| **Sample Interval ($\Delta t$)** | Frame Time (16.7 ms) | Elapsed time between consecutive physics samples | **16.666 ms mean, 16.698 ms median** | **VERIFIED (60 Hz Dispatch)** |
| **Process Frame Time** | Process Time (4.4 ms) | CPU/GPU frame processing duration (`TIME_PROCESS`) | **4.30 ms median, 4.43 ms mean** | **VERIFIED (Generous Margin)** |
| **Physics Step Time** | Physics Time (0.6 ms) | Physics tick processing duration (`TIME_PHYSICS`) | **0.63 ms mean, 0.54 ms median** | **VERIFIED** |
| **Draw Calls** | 225 calls | Total draw calls per frame (`RENDER_TOTAL_DRAW_CALLS`) | **225 calls mean** | **VERIFIED (Flat Across Sectors)** |
| **Scene Tree Nodes** | 155 nodes | Active scene tree nodes (`OBJECT_NODE_COUNT`) | **155 nodes mean** | **VERIFIED (Flat Across Sectors)** |
| **Static Memory** | 81.56 MB | Engine static memory allocation (`MEMORY_STATIC`) | **76.0 MB (Idle) $\rightarrow$ 87.1 MB (Boss)** | **VERIFIED** |
| **Render Frame Capture Type** | Per-render-frame | Data sampling method | **Periodic 60 Hz Physics Sampling** | **CORRECTED** |
| **Android Performance** | NOT_TESTED | Mobile target performance status | **NOT_TESTED** | **MAINTAINED** |

---

## 3. Sector Workload & Stress Attributability Analysis

The 14,404 samples were divided into four 60-second sectors (3,601 samples each):
1. **Sector 1 — `idle` (0.0s – 60.0s):**
   - Player remains at starting position $X=-8.0, Z=0.0$.
   - Captures startup scene loading and texture binding.
   - Exactly 2 frame spikes $> 33.33\text{ ms}$ occurred during initial asset load ($52.56\text{ ms}$ max); zero spikes occurred thereafter.
2. **Sector 2 — `walking` (60.0s – 120.0s):**
   - Bot cycles inputs: `move_right` (2.5s), `move_up` (0.5s), `move_left` (2.5s), `move_down` (0.5s).
   - Memory increased from 76.0 MB to 79.7 MB as animation frames streamed into cache.
3. **Sector 3 — `normal_combat` (120.0s – 180.0s):**
   - Bot moves right towards minions ($X=1.5$), cycles `attack` and `guard` inputs.
   - Memory increased from 79.7 MB to 83.4 MB.
4. **Sector 4 — `boss_combat` (180.0s – 240.0s):**
   - Script calls `_start_boss_wave()`, bot advances past $X=10.0$ and cycles attack/guard against Boss Commander.
   - Memory increased from 83.4 MB to 87.1 MB.

### Critical Evaluation of Differential Stress
- **Draw Calls:** Remained constant at **225** across all three active sectors (`walking`, `normal_combat`, `boss_combat`).
- **Node Count:** Remained constant at **155** across all active sectors.
- **Explanation:** In `SideQVStage1.tscn`, the 3D environment architecture (CSG geometry, materials, banners, lights, cameras, and UI canvas nodes) represents the vast majority of scene elements and is created at initial `_ready()`. Minions and the Boss Commander are lightweight `CharacterBody3D` nodes with single billboard sprites and standard colliders; their addition or removal does not significantly shift total draw calls under Godot's batching or node counts relative to the static 150+ node environment.
- **Formal Finding:** Although the bot inputs and game state transitions were genuinely executed, the benchmark did not establish distinct graphical stress differentials between walking and boss combat. Therefore, in strict compliance with the review protocol:
  - **`COMBAT_STRESS_DIFFERENTIAL_NOT_VERIFIED`**: Sector-specific stress differentiation is declared NOT VERIFIED.
  - **General Baseline:** The overall Stage 1 windowed performance baseline is solidly verified with ~240 FPS engine capacity and 4.3 ms process time on PC.

---

## 4. Execution Harness & Reproducibility Proof

The benchmark can be completely reproduced using the committed assets and Godot 4.7.2:

```powershell
# Command used to execute the 240-second windowed benchmark
& "D:\JUNYPAPA_STUDIO\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" `
    --path "D:\JUNYPAPA_STUDIO\Projects\ProjectKnight\CLIENT\Game" `
    --script "D:\JUNYPAPA_STUDIO\Projects\ProjectKnight\STUDIO_V3\evidence\V3-001-reconcile\performance\benchmark_source\benchmark_stage1_windowed.gd"
```

- **Harness Source:** [`benchmark_stage1_windowed.gd`](benchmark_source/benchmark_stage1_windowed.gd)
- **Analysis Tool:** [`analysis.py`](analysis.py)
- **Raw Telemetry Input:** [`raw_frames.csv`](../raw_frames.csv) (14,404 rows, SHA256: `e71aabfedd56fe772b7f8abcb4534b9fabd854e78f6c59f1962146d607615e2b`)
- **Analysis Results:** [`analysis_output.json`](analysis_output.json)

---

## 5. Conclusion & Verdict

1. The apparent 4× contradiction between 60.03 FPS and 240 FPS is completely resolved by distinguishing the **60 Hz physics sampling loop cadence** from the **240 FPS unconstrained GPU render framerate**.
2. Raw data in `raw_frames.csv` was preserved 100% without modification or tampering.
3. Sector-to-sector differential combat stress is honestly downgraded to **`COMBAT_STRESS_DIFFERENTIAL_NOT_VERIFIED`**.
4. The general Stage 1 PC windowed performance baseline is **VERIFIED (PASS)** with massive execution headroom.
5. Android performance remains explicitly **`NOT_TESTED`**.
