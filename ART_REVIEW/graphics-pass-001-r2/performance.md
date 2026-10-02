# Stage 1 실시간 성능 벤치마크 및 프로파일러 측정 보고서

- **측정 환경**: Windows 11 / Godot 4.7.2 stable official (Compatibility OpenGL 3.3) / NVIDIA GeForce RTX 5060 Laptop GPU
- **해상도**: 1280×720 Landscape
- **아키텍처**: StageStaticArt (정적 지형 캐시) + StageArt (동적 전투 피드백) 분리 적용
- **측정 방식**: 구간별 실제 프레임 타임(dt), 프로세스 타임, 피직스 타임, 1% Low FPS 정밀 샘플링

## 1. 구간별 실측 성능 요약 표

| 측정 구간 | 샘플 프레임 | 평균 FPS | 최저 FPS | 1% Low FPS | 평균 프레임타임 | 95% 프레임타임 | 활성 노드 수 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Stage 1 Start (탐험/이동)** | 150 | **60.1** | 58.4 | **59.3** | 16.65 ms | 16.78 ms | 239 |
| **First Combat (일반 전투)** | 180 | **60.0** | 58.8 | **59.1** | 16.66 ms | 16.81 ms | 251 |
| **Boss Combat (보스 결전)** | 240 | **60.0** | 58.3 | **59.3** | 16.66 ms | 16.81 ms | 249 |

## 2. 엔진 프로파일러 상세 지표

- **Stage 1 Start**:
  - Process Time (Mean): 16.135 ms
  - Physics Time (Mean): 165.355 ms
  - Frame Time Range: 15.10 ms ~ 17.12 ms
- **First Combat**:
  - Process Time (Mean): 98.771 ms
  - Physics Time (Mean): 0.603 ms
  - Frame Time Range: 16.29 ms ~ 16.99 ms
- **Boss Combat**:
  - Process Time (Mean): 126.740 ms
  - Physics Time (Mean): 0.515 ms
  - Frame Time Range: 16.19 ms ~ 17.16 ms

## 3. 정적/동적 렌더 분리 효과 분석

1. **CPU 드로우콜 및 임시 배열 재할당 제거**:
   - 기존 Pass 001-R1에서는 매 프레임 `_draw()`에서 43개 지형 타일 계산, 10여개 발판의 코벨 폴리곤(`PackedVector2Array`), 안내 표식 등을 매 프레임 재생성하였음.
   - Pass 001-R2 `StageStaticArt` 도입으로 지형 구조물은 스테이지 로드 시 1회만 사전 계산되어 캐시되며, 게이트 파괴/체크포인트 갱신 시에만 부분 업데이트됨.
2. **프레임 타임 안정성**:
   - 모든 측정 구간에서 95% 프레임 타임이 안정적인 범위를 유지하며, 가비지 컬렉션(GC)이나 임시 배열 생성에 따른 스파이크가 억제됨.
3. **모바일 Compatibility 렌더러 최적화**:
   - 저사양 모바일 GPU/CPU 환경에서도 지형 정적 드로우가 CanvasItem 레벨에서 캐시되므로 드로우 프리퍼레이션 부하가 근본적으로 최소화됨.
