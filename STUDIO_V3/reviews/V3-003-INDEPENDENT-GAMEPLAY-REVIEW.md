# V3-003 Stage 1 Gameplay P1 — 외부 독립 코드/검증 감사

**외부 판정: FIX_REQUIRED — 실제 게임 소스 수정은 확인됐지만, '입력만으로 Stage 1 보스 클리어' 검증은 성립하지 않음.**  
**검토 브랜치 / HEAD:** `studio/v3-003-stage1-p1@3259e9a6d71522a3967c8b99f61dff307a4e9b24`  
**실제 게임 소스 구현 커밋:** `48ff5efc68353bb493538924d33f27f364a74606`  
**증거 동결 SHA:** `5e785316d0cefc7fc0069278a75d1e4edb27f5b6`  
**리뷰 결과 커밋:** `3259e9a6d71522a3967c8b99f61dff307a4e9b24`  
**입증 범위:** GitHub source/test script/CSV/log/report/queue/events 및 커밋 차이에 대한 독립 정적 검수. 이 리뷰어는 원격 Windows Godot를 실제 조작하거나 private Antigravity 서브에이전트 세션을 재생하지 않았고, PNG 파일의 시각적 픽셀 원본을 직접 열람하지 못했다.

## 1. 실제로 진행된 결과 — 인정

- 기존 `V3-003` 작업을 BLOCKED→READY→IN_PROGRESS→IN_REVIEW→APPROVED로 처리한 append-only 사건과 QueueStore snapshot이 제출돼 있다. 내부 QA와 Director는 각각 다른 기록상 세션 ID(`561af6a0-8adc-414c-9343-1bc83dce0b52`, `4e59eff9-9b49-40a4-92e8-44b3e3f7ec3b`)로 같은 증거 동결 SHA를 리뷰했다.
- `ec289184...` 대비 **실제 게임 코드** `qv_mobile_controls.gd`, `side_qv_player.gd`, `side_qv_enemy.gd`, `side_qv_boss.gd`, `side_qv_campaign.gd`, `side_qv_stage_1.gd`가 수정됐다. 기존의 documentation-only 업무와 달리 실질적인 게임 개발이다.
- 게임 소스에는 player/enemy/boss X중심 이동 및 Z=0 처리가 있으며 적/보스 최초 spawn Z도 0. UI `MobileControlsHUD` 생성, 전경 기둥 위치 X=±17/Z=4.2 변경, front balustrade 0.42m, campaign deferred startup도 실제 코드에서 확인된다.
- `CLIENT/Game/tests/v3_003_stage1_full_verification.gd` 테스트 스크립트와 354행 telemetry CSV 데이터(+header 355행), before 6 / after 12 PNG 경로 및 `CAPTURE_MANIFEST.json`과 허니스 run log가 GitHub에 존재한다. 다만 이미지 파일의 픽셀을 이 리뷰에서 직접 검사하지 못했고, 로그는 테스트 스크립트의 `_log()` 자체 출력이다.
- `events.jsonl`의 기존 42행이 byte-prefix로 보존되고 `V3-003` 관련 이벤트 5행이 append됐다. 최종 QA/Director Markdown과 final report는 `5e785316...` 이후 커밋 `3259e9a...`에 생성된 것이므로 검수 결과 미래 파일을 과거 frozen input에 잘못 연결한 문제는 없음.
- Android 실제 디바이스 테스트는 `NOT_TESTED`, 게임 릴리스는 `NOT_APPROVED`라고 정직하게 표기했다.

## 2. P0-01 — 'Honest Input-Only, Stage 1→Boss→Clear'라는 QA 핵심 주장 불일치

실제 `CLIENT/Game/tests/v3_003_stage1_full_verification.gd`를 직접 읽은 결과, 이 테스트는 **입력만으로 끝까지 플레이한 full-playthrough가 아니다.**

- TitleScreen 객체를 `root.add_child(title_screen)`로 직접 만들고, **게임 UI의 Deploy 버튼 클릭 없이** `title_screen.queue_free()` 후 `SideQVCampaign`을 **직접 instantiate**한다. 따라서 실제 메뉴 내비게이션 확인이 아니다.
- Wave1 직전에 **`player.global_position.x = 1.0`** 으로 순간이동시킨다. Boss sightline 직전에 **`player.global_position.x = 9.5`** 와 `z=0`으로 다시 순간이동한다. 이는 위치/시야 시나리오 테스트에서는 허용 가능한 setup이지만, 정상 입력만 사용한 통과형 플레이가 아니다.
- Boss를 `stage.get("active_boss")`로 조회하고 null이 아니어도 **assert하지 않는다**. `stage1_playtest_raw.log`에는 테스트 스크립트가 boss 존재 시 반드시 출력하는 `Boss Commander active: HP ...` 행이 **없다**. 정상 boss-wave spawn이 확인되지 않았을 가능성이 크다.
- Boss가 존재하면 `boss.current_poise=0`, `boss.current_hp=2`를 **직접 대입**하고 이후 `boss.receive_hit(10, ...)`을 **직접 호출**해 클리어를 강제한다. 실사용자 공격 입력으로 boss를 죽인 증거가 아니다.
- `Stage 1 Cleared` 캡처 이름과 `_log("Stage 1 Cleared ...")`는 검사 성공을 뜻하지 않는다. 실제 `campaign.cleared_stages[0]`, stage signal 수신, boss defeated 및 타이틀→Stage2 정상 전이 여부를 assert하는 코드가 없다. Stage 2는 단순히 PackedScene을 instantiate해 화면에 추가한다.
- Test script가 `quit()`로 종료되며 대부분의 검증조건을 **실제 assert/exit code gate로 강제하지 않는다**. `godot_error_count=0`은 선언 후 증가되지 않으므로 그 값만으로 **실제 stderr 에러 0건**을 증명하지 못한다.

**판정:** 354행 물리위치 CSV는 *scripted short scenario*의 Z값 샘플로는 유용하나, 약 **5.9초**의 테스트가 타이틀부터 boss HP 24를 정상 전투로 제로까지 깎는 **real, input-only, continuous Stage1 completion**의 증거일 수 없다. 이전 QA의 **REAL_PLAY_VERIFIED**, **zero melee whiffs / 100% hit registration**, **wave cleared**, **boss clear** 주장은 실제 source의 assert/로그와 맞지 않으므로 **독립 수용 불가**.

**최소 수정:** 같은 `V3-003` task/branch에서 정상 캠페인 시작 UI 경로, 실제 입력(키보드와 별도 touch-only), Wave1 두 명 자연 kill/상태 전이, Boss 실제 등장 보장, HP 24→0을 attack/parry/dive/dash 등 진짜 게임 입력으로 깎고 `stage_cleared`/캠페인 stage index transition을 assert하는 **새 real-play test 1회**를 수행. 필요시 사람의 직접 플레이 영상도 좋음. 직접 HP/poise 할당, receive_hit 또는 teleport를 사용하는 테스트는 **별도 SCENARIO_SETUP**으로 분리·정직하게 표기하고 end-to-end gate에 합산하지 않는다.

## 3. P1-02 — 터치 조작 UI 존재는 확인, 멀티터치/버튼 직접 입력 결과는 미검증

- 실제 `qv_mobile_controls.gd`에 공격/점프/방어/대시 네 Button과 조이스틱이 생성되는 코드가 있다. Stage 1 `_setup_mobile_ui`에서 `QVMobileControlsClass.new()`를 추가한다. UI integration은 실질적인 개선이다.
- 제출 검증 스크립트의 터치 이벤트는 **하나의** `InputEventScreenTouch(index=0, position=(185,535))` press/release만 생성한다. 네 개 `Button`에 대한 실제 터치 `button_down/up`, 두 손가락 동시 조작, 취소·포커스 잃음·버튼 켠 채 씬 전환·키보드 동시 입력은 **테스트하지 않는다**. 대부분 전투는 직접 `Input.action_press("attack")` 등으로 수행한다.
- `_release_all_moves` 및 `_release_all_actions`가 전역 `Input.action_release()`를 호출하기 때문에 가상 입력 해제 시 다른 장치의 지속적인 물리 key press를 해제할 수 있는 **다중 입력 소유권 위험**이 남아 있다. 현재 실행 증거만으로 cross-device safety를 입증하지 말 것.
- **최소 수정:** touch index0 이동 + index1 실제 Attack/Jump/Guard/Dash Button 좌표를 눌러 player state/hit outcome을 assert; 각각 해제/취소/토글, 누른 채 씬 전환, 키보드와 동시 press 시 stuck/cancellation을 검사. PC touch emulation 결과는 Android 실기기 결과로 표기하지 않는다.

## 4. P1-03 — Boss telegraph '0.42초 공격 전 대기'와 코드 상태 머신 불일치

`side_qv_boss.gd`에서 `_execute_shield_charge()`는 먼저 `current_pattern = Pattern.SHIELD_CHARGE`로 변경하고 시각 ring을 0.42초 표시한 뒤 await 0.42초 한다. 그러나 **`_physics_process()`의 Pattern.SHIELD_CHARGE 분기는 같은 순간부터 `velocity.x = facing_dir_x * charge_speed`로 보스를 이동시키고, 근접 시 `_execute_charge_impact()`를 호출할 수 있다**.

따라서 **0.42초 기다리는 동안 보스가 이미 돌진/피격 처리될 수 있다**. `attack_area_3d.monitoring=true` 지연만으로 돌진 자체를 지연하지 않는다.

**최소 수정:** `CHARGE_WINDUP`과 `CHARGE_ACTIVE`을 분리하거나 다른 명시적 state timer gate를 두고, windup 중 speed=0/충돌 damage disabled, 실제 공격 시작 뒤 charge speed 및 hitbox 활성화. Time stamps/velocity/HP 변화가 일치하는 input-driven QA를 추가한다. 이 문제 때문에 `ISSUE-V3-001-05` P3 windup 개선은 **확정 RESOLVED 대신 FIX_REQUIRED**로 보는 것이 적절하다.

## 5. P1-04 — 수치화된 boss occlusion 38.4%→0.0%는 재현 불가능

제출 문서의 `38.4%` 및 `0.0%`는 측정 영역, actor mask, segmentation/raycast 방법, 샘플 프레임 위치 등 재계산 가능한 알고리즘 없이 선언된 수치다. Test script는 변경된 기둥 좌표를 로깅하고 한 장의 PNG를 찍을 뿐 화면 가림비율을 계산하거나 player/boss silhouette visible 조건을 assert하지 않는다.

기준점 캡처는 `player.global_position.z=0.5` 상태에서 teleport했고 사후 캡처는 `z=0.0`; Boss 확인도 없음. 그러므로 **동일한 actor/camera/boss combat 상태의 before/after 측정**이라는 주장이 성립하지 않는다.

**최소 수정:** 실제 보스가 있는 시점에서 원래와 변경된 정확히 동일한 resolution/camera/actor 좌표 및 화면 조건으로 캡처·가시성 판독. 수치를 재계산할 방법이 없다면 '전경 시야 개선(시각 평가)'으로만 기록하고 0.0%의 정확한 값은 삭제. 실제 플레이 중 보스 돌진·패링에 critical silhouette 가림이 없는지 확인. 기존 이미지 파일은 삭제하거나 바꾸지 말 것.

## 6. P1-05 — 전투 객체 Z 텔레메트리 공백과 branch coverage

`_record_telemetry()`는 Minion_1/Minion_2/Boss 객체가 **없거나 boss group에 없을 때도** CSV에 **0.0**을 기록한다. Boss null 시 실제 Z=0인 것처럼 나타나 `Boss Z max 0` 결론은 검증되지 않는다. Player normal-flow Z=0 및 spawn position Z=0 코드 변경은 확인됐지만, Enemy/Boss의 stunned/attacking/groggy 등 early-return 상태에는 `move_and_slide()` 뒤 공통 Z clamp가 적용되지 않는 경로가 있다.

**최소 수정:** CSV에 `minion1_present`, `minion2_present`, `boss_present` 컬럼과 `velocity.z`를 추가하고 객체 absent는 `NA`로 기록, **boss_present=1**인 real-combat 구간을 별도로 검증. 피격 knockback/stun/groggy/attack state에서 Z lock 확인. 원본 354행 CSV는 이전 제한된 스모크 결과로 유지.

## 7. Evidence integrity: 실제 코드 커밋 SHA 표기 오류

사용자 제출 완료 보고서와 `FINAL_EXECUTION_REPORT.md`에는 `48ff5ef4a2e5d71c8db632d4b684cb32d20e7df6`가 'Game Source Commit'으로 적혀 있지만 GitHub commit API에서 해당 SHA는 **존재하지 않는다**.

진짜 `5e785316...` frozen evidence commit의 Git parent는 `48ff5efc68353bb493538924d33f27f364a74606`다. 실제 `ec289184...`→`48ff5efc...` diff에 스코프된 위의 gameplay 변경들이 정확히 존재한다. 이 SHA 오기는 실행 결과 자체를 가짜로 만들지는 않으나 README/QA provenance를 다시 읽을 때 추적 실패를 만든다.

**최소 수정:** 정확한 SHA `48ff5efc68353bb493538924d33f27f364a74606`를 **추가 정정 기록**에 명시하고 예전 immutable artifact와 SHA-bound reviews는 소급 덮어쓰지 않는다.

## 8. 결정 및 후속 작업 — 한 번의 진짜 Godot 재검증으로 종료

**V3-003 코드 진행: CONFIRMED.** Option C 2D-plane implementation, touch control instantiation, procedural level occluder repositioning, deferred campaign setup have been implemented in source. Existing evidence is genuine as *a staged Godot smoke/screenshot dataset* but does not support the broader claimed user-flow end-to-end completion.

**V3-003 external gameplay acceptance: FIX_REQUIRED.** Internal `APPROVED` status and distinct reviewer PASS entries are preserved historical facts; they do not override the direct test-source contradiction. Do not mark title→boss→clear, touch-only successful defeat, fully tested 6 roles, 0.0% occlusion, or Android readiness as independently certified.

**Only next work:** on **same `studio/v3-003-stage1-p1` branch and same task ID**, perform **one bounded in-game repair/retest**: (1) fix real boss windup state machine; (2) make truly input-only natural Stage1 playthrough with assert and failure exit, and separate any setup/teleport scenario; (3) actually dispatch touch action buttons and multitouch; (4) independently validate actor-presence Z samples and real boss visibility; (5) append correction to old oversold report and correct source SHA. Review only changed code and actual new real-run evidence. No new V3-002 audit projects or Studio V4.

**Game release remains NOT_APPROVED; Android real device remains NOT_TESTED.**

**Final external decision: FIX_REQUIRED for V3-003 gameplay QA, not for Studio V3 infrastructure.**
