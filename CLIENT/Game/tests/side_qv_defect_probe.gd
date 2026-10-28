extends SceneTree
## 결함 확정용 결정적 프로브 (Deterministic Defect Probes) - 입력만 사용, 판정 없이 관측치 출력

const Stage1Scene := preload("res://scenes/side_quarter_view/SideQVStage1.tscn")
const Stage3Scene := preload("res://scenes/side_quarter_view/SideQVStage3.tscn")


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): print("[WATCHDOG]"); quit(1))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _run() -> void:
	# ---------- P1: 근접 공격 판정 ----------
	var st = Stage1Scene.instantiate()
	root.add_child(st)
	await _frames(10)
	var pl = st.player
	for e in st.enemies.duplicate():
		e.set_physics_process(false) # 적 AI 정지 (움직이지도 공격하지도 않음)
	var target = st.enemies[0]
	target.global_position = pl.global_position + Vector3(1.0, 0, 0)
	target.max_hp = 999
	target.current_hp = 999
	await _frames(5)
	var hits := []
	for i in 6:
		var before: int = target.current_hp
		await _tap("attack")
		await _frames(18) # 0.3s
		hits.append(before - target.current_hp)
	print("[P1] 적 1.0m 정면, 공격 6회(0.3s 간격) 각 타격 피해: ", hits, "  (3번째/6번째 = 콤보 3단 검기)")

	# 거리 0.6m (붙어있을 때)
	target.global_position = pl.global_position + Vector3(0.6, 0, 0)
	await _frames(5)
	var hits2 := []
	for i in 3:
		var before2: int = target.current_hp
		await _tap("attack")
		await _frames(40)
		hits2.append(before2 - target.current_hp)
	print("[P1b] 적 0.6m 정면, 단타 3회(콤보 리셋 간격) 각 타격 피해: ", hits2)

	# ---------- P2: 피격 무적 시간 & 사망 처리 ----------
	var died_count := [0]
	pl.died.connect(func(): died_count[0] += 1)
	pl.current_hp = 5
	var hp_log := []
	for i in 8:
		pl.receive_incoming_attack(1, target, Vector3.RIGHT)
		hp_log.append(pl.current_hp)
		await physics_frame
	print("[P2] 8프레임 연속 피격(각 1 피해) 후 HP 추이: ", hp_log, " (i-frame 작동 시 [4,4,4,4,4,4,4,4])")
	# i-frame 종료 후 치명타 피격 4연속 전달하여 사망 처리 검증
	pl.invuln_timer = 0.0
	for i in 4:
		pl.receive_incoming_attack(5, target, Vector3.RIGHT)
		await physics_frame
	print("[P2_death] 치명타 4연속 피격 후 HP=%d | died 시그널 발생 횟수: %d (단 1회여야 함)" % [pl.current_hp, died_count[0]])
	var x0: float = pl.global_position.x
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	print("[P2b] HP=%d(사망) 상태에서 오른쪽 이동 0.5s → X 이동량 %.2fm (0이 아니면 시체가 조작됨)" % [pl.current_hp, pl.global_position.x - x0])
	print("[P2c] 사망 상태 스프라이트 텍스처: ", pl.sprite_3d.texture.resource_path.get_file())
	st.queue_free()
	await _frames(3)

	# ---------- P3: Stage 3 맵 경계 ----------
	var s3 = Stage3Scene.instantiate()
	root.add_child(s3)
	await _frames(10)
	var p3 = s3.player
	for e in s3.enemies.duplicate():
		e.set_physics_process(false)
	Input.action_press("move_left")
	await _frames(240)
	Input.action_release("move_left")
	print("[P3] Stage3 왼쪽으로 4초 이동 → 위치 (%.1f, %.1f, %.1f) | arena_width=%.0f" % [p3.global_position.x, p3.global_position.y, p3.global_position.z, s3.arena_width])
	Input.action_press("move_right")
	await _frames(480)
	Input.action_release("move_right")
	print("[P3b] Stage3 오른쪽으로 8초 이동 → 위치 (%.1f, %.1f, %.1f)" % [p3.global_position.x, p3.global_position.y, p3.global_position.z])
	Input.action_press("move_down")
	await _frames(240)
	Input.action_release("move_down")
	print("[P3c] Stage3 아래(앞)로 4초 이동 → 위치 (%.1f, %.1f, %.1f) | arena_depth=%.0f" % [p3.global_position.x, p3.global_position.y, p3.global_position.z, s3.arena_depth])

	# ---------- P4: 공격 애니메이션 프레임 ----------
	var frames_seen := {}
	Input.action_press("attack")
	await physics_frame
	Input.action_release("attack")
	for i in 20:
		frames_seen[p3.sprite_3d.frame] = true
		await physics_frame
	print("[P4] 공격 1회 동안 표시된 스프라이트 프레임 종류: ", frames_seen.keys(), " (애니메이션이면 여러 개여야 함)")
	quit(0)
