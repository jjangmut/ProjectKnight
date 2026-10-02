# [QA-AUDIT-001] Stage 1~5 실기 QA 준비 및 정적 위험 분석

- 작성일: 2026-10-02
- 기준 브랜치: `integration` @ `4e05e1c2`
- 작업 브랜치: `chatgpt/playtest-audit-001`
- 목적: 실제 Stage 1~5 플레이 완주 QA 전에 코드/테스트를 정적으로 점검하여 실기에서 우선 확인할 위험 구간과 자동화 공백을 정리한다.
- 검증 한계: ChatGPT GitHub 환경에서 Godot 실행 및 Android 기기 테스트는 수행하지 않음.

## 1. 이번 점검에서 즉시 수정한 항목

### QA-RISK-001 — 스테이지 전환 시 `dash` / `move_down` 입력 잔류 가능성
`campaign.gd::_start_stage()`는 기존에 `move_left`, `move_right`, `attack`, `jump`, `guard`만 강제 release했다.

모바일 조작은 `dash`와 `move_down`도 지속 입력 상태를 만들 수 있으므로, 스테이지 전환/체크포인트 재시작 시 이전 손가락 입력이 다음 스테이지에 남을 위험이 있었다.

조치:
- `campaign.gd`의 전환 입력 해제 목록에 `move_down`, `dash` 추가.
- `campaign_transition_test.gd`에 두 입력을 강제로 누른 뒤 `_start_stage()`가 모두 해제하는지 확인하는 회귀 검증 추가.

상태: **코드 수정 완료 / 로컬 Godot 실행 미검증**

## 2. 자동 QA 커버리지 공백

### QA-RISK-002 — `campaign_full_qa.gd`가 전체 5스테이지 실플레이를 대표하지 않음
현재 `campaign_full_qa.gd`는 주로:
- Stage 3/4/5 일부 능선 통과
- Stage 3/5 상층 루트 진입
- 동시 사망/Goal 판정
- Stage 4 골렘 점프 회피

를 검증한다.

따라서 이름과 달리 다음은 충분히 검증하지 않는다.
- Stage 1/2의 전체 이동/전투 흐름
- 5대 보스 각각의 실제 처치 가능성
- 보스 페이즈 전환 후 플레이어 생존 경로
- Stage 1→5 연속 세션의 Save/Reward/Relic 누적
- 모바일 입력으로 캠페인 전체 완주

실기 QA에서 이 항목들을 별도 체크해야 한다.

### QA-RISK-003 — 상용성 점수 테스트가 실제 품질 증거처럼 보일 수 있음
`studio_manager_playtest_analysis.gd`의 “Commercial Readiness Score”는 코드 안에 9.x 점수가 하드코딩되어 있으며, 평균이 9.0 이상인지 다시 검사한다.

이 값은 사용자 플레이테스트, 성능 측정, 스토어 데이터 또는 객관적 벤치마크에서 계산된 값이 아니다.

따라서:
- 해당 테스트는 **기능/메트릭 데모용**으로만 취급한다.
- “상용성 9.x/10”, “AAA INDIE VIABILITY”를 출시 판단 근거로 사용하지 않는다.
- 이후 QA에서는 실측 FPS, 충돌 실패율, 입력 실패, 보스 사망 원인, 완주율 같은 측정 가능한 값으로 대체한다.

### QA-RISK-004 — 경제 테스트의 104 Shards는 실제 드랍 계산이 아님
동일 테스트에서 Stage별 파편 `[12,16,20,24,32]`를 직접 배열로 넣어 총 104를 만든다.

실제 적/보스 드랍과 캠페인 보상 코드로부터 산출한 값이 아니므로 경제 밸런스 검증으로 취급하면 안 된다.

실기/후속 자동화에서 실제 Stage별 획득량을 기록해야 한다.

## 3. 모바일 실기 우선 확인 항목

### QA-RISK-005 — 가상 조이스틱의 실제 손가락 경계
`MobileControls`는 좌측 65%를 조이스틱 터치 영역으로 사용하고 우측에 3버튼 액션 클러스터를 배치한다.

1280×720 기준 배치는 논리적으로 분리되어 있으나 다음은 실제 기기에서 확인해야 한다.
- 화면비가 긴 기기에서 좌/우 엄지 이동 거리
- 조이스틱 `follow_finger` 이동 중 액션 영역 침범 여부
- 공격+점프 대각선+대시 동시 입력
- 손가락을 화면 밖으로 뺐을 때 입력 해제
- 앱 포커스 전환 후 눌림 상태 잔류

### QA-RISK-006 — 모바일 UI가 PC에서도 항상 활성
`_check_environment_visibility()`의 현재 코드는:

`is_mobile_active = is_mobile or has_touch or true`

이므로 환경과 관계없이 모바일 패드가 기본 활성화된다.

개발/검증 편의를 위한 의도라면 유지 가능하지만, PC 빌드/영상 촬영에서는 HUD 노출이 의도한 것인지 결정해야 한다.

## 4. 보스 실기 우선 확인 항목

최근 보스가 크게 확대되었으므로 자동 테스트의 scale 조건 통과만으로는 충분하지 않다.

각 보스에서 다음을 확인한다.

1. 카메라 안에 실루엣과 전조가 동시에 보이는가
2. 플레이어가 보스 몸체/TopPlatform에 끼이지 않는가
3. 대형화된 Sprite와 실제 Collision/Attack Range가 시각적으로 일치하는가
4. 보스 뒤/아래에서 피격 판정이 부자연스럽지 않은가
5. Phase 전환 Hit Stop 후 AI가 정상 복귀하는가
6. 사망 시 Arena/Goal/Reward 진행이 한 번만 발생하는가

특히 우선 순위:
- Stage 3 `CrossbowCommander`: 투사체 궤적/충돌/가독성
- Stage 4 `AncientGolemGuardian`: 대형 몸체 + 낙석 + 상단 플랫폼
- Stage 5 `AbyssalArbiter`: 3페이즈, Blink, Blade Ring, Final Judgment

## 5. Stage 1~5 실기 체크리스트

각 Stage를 **새 저장 데이터**와 **누적 캠페인 데이터** 두 방식으로 검증한다.

### 공통
- [ ] 스테이지 진입 시 입력 잔류 없음
- [ ] 시작 HP/유물/특성 상태 정상
- [ ] 필수 경로 진행 가능, 소프트락 없음
- [ ] 선택 상층 루트 진입/이탈 가능
- [ ] 몬스터가 상층/하층에서 멈추지 않음
- [ ] 체크포인트 사망 후 정상 재개
- [ ] Goal 도달 전 필수 전투 우회 불가
- [ ] 보스 전조가 공격 판정과 일치
- [ ] 보스 처치 후 보상 1회 지급
- [ ] Stage Clear 패널에서 터치 입력 정상
- [ ] 다음 Stage 진입 시 dash/down 포함 모든 이전 입력 해제
- [ ] 프레임 드롭/카메라 떨림/과도한 HDR로 플레이 판독 방해 없음

### Stage 1
- [ ] 기본 전투 학습 곡선
- [ ] BossCommander 가드/충격파 가독성
- [ ] 첫 유물 획득과 장착/패시브 반영

### Stage 2
- [ ] 야수 돌진 회피 공간
- [ ] BeastChieftain 점프/돌진 전조
- [ ] Stage 1 유물 누적 상태 유지

### Stage 3
- [ ] 고저차 + 사수 조합에서 불합리한 피격 없음
- [ ] CrossbowCommander 탄환 실제 충돌 신뢰성
- [ ] 투사체가 화면 밖/벽 통과 후 잔존하지 않음

### Stage 4
- [ ] 골렘 지면강타를 일반 점프로 회피 가능
- [ ] 낙석 위치 예고가 읽힘
- [ ] 대형 보스 TopPlatform과 플레이어 충돌 안정

### Stage 5
- [ ] 기존 적 조합이 과도한 동시 공격을 만들지 않음
- [ ] AbyssalArbiter Phase 1→2→3 전환 정상
- [ ] Blink 직후 즉사성 겹침 없음
- [ ] Final Judgment 전조/회피 수단 명확
- [ ] 최종 보상/캠페인 완료/재시작 정상

## 6. 실측 기록 항목

다음 플레이부터 각 Stage별로 아래 값을 남긴다.

- 클리어 시간
- 사망 횟수
- 체크포인트 재시작 횟수
- 보스 도전 횟수
- 보스별 피격 원인 Top 3
- 입력 누락/잔류 횟수
- 소프트락/충돌 이상 횟수
- 평균/최저 FPS(Android)
- 발열/프레임 저하 발생 시점
- 획득 Soul Shards 실제 수량
- 플레이 후 즉시 수정이 필요하다고 느낀 항목

## 7. 다음 실행 작업

Codex/Antigravity에서 다음 순서로 검증한다.

1. `campaign_transition_test.gd` — 이번 입력 잔류 수정 회귀 검증
2. `mobile_controls_smoke.gd`
3. `campaign_full_qa.gd`
4. `game_and_graphic_quality_smoke.gd`
5. PC 실플레이 Stage 1→5 완주
6. Android 실기 Stage 1→5 또는 최소 Stage 1/3/5 집중 검증

첫 로컬 검증에서 실패가 발생하면 신규 기능 추가보다 해당 실패를 우선 수정한다.
