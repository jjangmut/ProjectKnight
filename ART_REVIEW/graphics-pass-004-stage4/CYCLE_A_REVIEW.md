# [TASK-AR-017] Stage 4 (돌의 성소) Graphics Pass 004 — Cycle A 품질 검토 보고서

- **작업**: TASK-AR-017 Stage 4 Graphics Pass 004 — Cycle A Review
- **기준 브랜치**: `antigravity/graphics-quality-pass-003-stage3`
- **작업 브랜치**: `antigravity/graphics-quality-pass-004-stage4`
- **검토일**: 2026-10-06
- **상태**: **`IN_PROGRESS`**
- **모바일 상태**: **`ANDROID PERFORMANCE NOT VERIFIED`**

---

## 1. Cycle A 캡처 분석 결과

6개 대표 장면 캡처 완료 (`ART_REVIEW/graphics-pass-004-stage4/cycle_a/`):

1. **`01_stage4_entry.png` — 성소 진입로 전경 & 패럴랙스 심도**
   - **Layer 1 (심연 동굴광/천창)**: 상부에서 쏟아지는 천상 광선(`SanctuaryLightShafts`)과 시안-아이보리 코로나 광원 배치 완료.
   - **Layer 2 (원경 거석 기둥군)**: 원경에 거대 석조 린텔과 기둥 실루엣(`DistantSanctuaryMegaliths`)이 배치되어 광대한 신전 내부의 깊이감 형성.
   - **Layer 3 (성소 벽면 부조)**: `stage_four_v1.png`에 사암 색조(`Color(1.02, 0.96, 0.88, 0.95)`)와 중간 회랑 실루엣 중첩.
   - **Layer 4 (전경 코니스 프레이밍 & 신성한 안개)**: 상단 거대 거석 천장 보(`fg_beams`)와 하단 시안빛 신성한 포자 안개(`fog`)로 시네마틱 프레이밍 완성.
   - **Landmark 1 (거대한 룬 석문, x≈400)**: 좌우 쌍둥이 모놀리스(폭 60px), 상단 린텔(y=220), 쐐기돌(Keystone) 시안 룬 코어 발광. Lintel top이 y=220에 위치하여 상단 HUD 배너(screen y=90~150)와 70px 이상의 안전 거리를 확보해 HUD 가림 결함 0건 달성.

2. **`02_stage4_first_golem.png` — 첫 GroundSlamGolem 전투 & 지면 강타 전조 가독성**
   - **전조 가독성 (Telegraph Readability)**:
     - 지면 충격 위험 구역에 고대비 호박색/주황 지면 균열 림(`Color(2.6, 1.2, 0.35, 0.90)`), 중앙 밝은 코어 라인(`Color(3.2, 1.8, 0.5)`), 양 끝 ㄷ자형 코너 브래킷(`[`, `]`) 적용.
     - 충격 구역 내부 5개 룬 펄스 틱 및 불꽃 파편 상승 효과를 통해 플레이어에게 0.35초 윈드업 타이밍을 직관적으로 전달.
   - **색상 대비 절대 분리 (Strict Color Separation)**:
     - 위험 전조/공격 VFX: 고강도 호박색/오렌지(`Color(2.6, 1.2, 0.35)` ~ `Color(3.5, 2.5, 1.0)`).
     - 환경/석상 장식 룬: 차분한 쿨 시안(`Color(0.3, 1.8, 2.2)`).
     - 시각적 오인 가능성을 원천 차단하여 전투 가독성 극대화.

3. **`03_stage4_mid_sanctuary.png` — 거석 플랫폼 지지 구조 (Megalithic Grounding)**
   - **Castle Support 에셋 오용 완전 제거**: Stage 1의 얇은 성곽 까치발/목재 지지대를 전면 제거.
   - **거석 기둥(`monolith_pillars`) 및 파일런(`pylon_supports`) 도입**:
     - 광폭 플랫폼: 좌우 44px 두께의 거석 원주, 수평 조적 줄눈, 상단 코벨, 하단 52px 좌대(Plinth), 중앙 수직 시안 룬 홈 라인.
     - 단폭 플랫폼: 중앙 테이퍼드 거석 파일런, 상단 코벨, 하단 68px 광폭 좌대, 중앙 룬 코어.
   - 수 톤의 하중을 지탱하는 거석 건축물다운 물리적 안정감과 질량감 확립.

4. **`04_stage4_route_choice.png` — 성소 분기 표지석 & 상하 경로 식별**
   - **고유 텍스트 표기**:
     - 상층: `↑ 상층: 고대 성소 상층 회랑 · 회복 +1`
     - 하층: `→ 아래 길: 거석 의식 통로로 전진`
   - 표지판 하단 룬 금빛 노치 및 석조 음영 스타일 적용으로 배경과 뚜렷이 분리.

5. **`05_stage4_boss_combat.png` — Ancient Golem Guardian 보스 아레나 & 랜드마크 3**
   - **Landmark 3 (고대 수호자 성소, x≈10000)**: 거대 신전 포털 프레임, 시안 룬 서클 아크(반경 42px/24px), 좌우 거대 수호자 입상(Sentinel Statues), 의식 화로(Braziers).
   - **보스 아레나 무대감**: 3단 계단식 제단 다이스(`altar_steps`), 중앙 제단 룬 코어, 6개 거석 아레나 열주 기둥, 바닥 룬 라인 구축으로 최종 결전의 웅장함 연출.

6. **`06_stage4_boss_reward.png` — 클리어 및 유물 카드 보상**
   - 성소 배경과 대비되는 클리어 보상 UI 프레이밍 정상 확인.

---

## 2. Cycle B 보완 및 미세 튜닝 계획

1. **지형 상단 엣지 및 플랫폼 하이라이트 강화**:
   - 어두운 성소 배경에서 플레이어가 점프 착지할 플랫폼 상단 엣지의 2중 하이라이트 라인 채도 및 밝기를 미세 조정하여 모바일 소형 화면 시인성 강화.
2. **보스 아레나 제단 발판과 보스 발밑 접지 섀도우 정밀 조율**:
   - 보스 및 골렘 적군의 거대한 발밑 접지 섀도우가 거석 바닥면과 자연스럽게 블렌딩되도록 보완.
3. **10대 평가 항목 자체 점수 평가 및 60 FPS Gate 벤치마크 진행**.
