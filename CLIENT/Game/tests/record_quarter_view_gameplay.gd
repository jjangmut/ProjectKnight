extends SceneTree
## 쿼터뷰 2.5D 실전 플레이 쇼케이스 녹화기 (Quarter-View Gameplay Recorder)
## - 8방향 2.5D 대각선 기동 & Z축 점프/동적 그림자
## - 360도 3단 콤보 & 크레센트 검기 방출
## - 보스 방패 돌진에 맞선 0.14초 저스트 패링 & 3배 카운터 어택
## - 360도 지진 충격파 링을 점프로 뛰어넘는 공중 강하 피니셔

const QuarterViewArenaScene = preload("res://scenes/quarter_view/QuarterViewArena.tscn")
const QVSwordBeamClass = preload("res://scripts/quarter_view/qv_sword_beam.gd")

enum State {
	INTRO,
	Z_JUMP_SHOWCASE,
	COMBAT_MINIONS,
	BOSS_SPAWN,
	PARRY_BOSS_CHARGE,
	COUNTER_COMBO,
	EVADE_QUAKE_RING,
	BOSS_FINISHER,
	FINISH
}

var current_state: State = State.INTRO
var state_time: float = 0.0
var total_elapsed: float = 0.0

var stage: Node2D = null
var player: CharacterBody2D = null
var boss: CharacterBody2D = null


func _init() -> void:
	print(">>> [QV RECORDER] Initializing Quarter-View Gameplay Recorder...")
	create_timer(14.0).timeout.connect(func(): quit(0))
	call_deferred("_start_recording")


func _start_recording() -> void:
	stage = QuarterViewArenaScene.instantiate()
	root.add_child(stage)
	current_scene = stage

	await process_frame
	await process_frame

	player = stage.player
	player.global_position = Vector2(-280.0, 140.0)

	print(">>> [QV RECORDER] Arena ready. Starting cinematic choreography!")


func _physics_process(delta: float) -> bool:
	if stage == null or player == null or not is_instance_valid(player):
		return false

	state_time += delta
	total_elapsed += delta

	if total_elapsed >= 11.5:
		quit(0)
		return true

	match current_state:
		State.INTRO:
			# Player runs diagonally into center of arena
			Input.action_press("move_right")
			Input.action_press("move_up")
			if state_time >= 1.0:
				Input.action_release("move_right")
				Input.action_release("move_up")
				_set_state(State.Z_JUMP_SHOWCASE)

		State.Z_JUMP_SHOWCASE:
			# Showcase Z-axis jump and drop shadow separation
			if state_time < 0.1:
				player.start_jump()
			elif state_time >= 0.8:
				_set_state(State.COMBAT_MINIONS)

		State.COMBAT_MINIONS:
			# Rapid 3-hit combo against minion + 360 sword beam
			player.facing_direction = Vector2(1.0, -0.4).normalized()
			if state_time < 0.15:
				player.start_attack()
			elif state_time >= 0.25 and state_time < 0.35:
				player.start_attack()
			elif state_time >= 0.45 and state_time < 0.55:
				player.start_attack() # Combo 3 -> Sword Beam!
			elif state_time >= 0.85:
				# Clear minions
				for e in stage.enemies.duplicate():
					if e != stage.active_boss and is_instance_valid(e):
						e._die()
				_set_state(State.BOSS_SPAWN)

		State.BOSS_SPAWN:
			# Boss wave trigger & Standoff
			if is_instance_valid(stage.active_boss):
				boss = stage.active_boss
				boss.global_position = player.global_position + Vector2(160.0, -60.0)
			if state_time >= 1.2:
				_set_state(State.PARRY_BOSS_CHARGE)

		State.PARRY_BOSS_CHARGE:
			# Boss charges -> Player Just Parries!
			if is_instance_valid(boss):
				if state_time < 0.1:
					boss._execute_shield_charge()
				elif state_time >= 0.3 and state_time < 0.7:
					player.facing_direction = (boss.global_position - player.global_position).normalized()
					player.start_guard()
			if state_time >= 0.8:
				player.release_guard()
				_set_state(State.COUNTER_COMBO)

		State.COUNTER_COMBO:
			# 3x Counter strike on stunned boss
			player.start_attack()
			if is_instance_valid(boss):
				boss.receive_hit(6, player.facing_direction)
			if state_time >= 0.8:
				_set_state(State.EVADE_QUAKE_RING)

		State.EVADE_QUAKE_RING:
			# Boss casts Quake Ring -> Player leaps over it with Z-jump!
			if state_time < 0.1:
				if is_instance_valid(boss):
					boss._execute_quake_ring()
			elif state_time >= 0.25 and state_time < 0.35:
				player.start_jump()
			elif state_time >= 0.5 and state_time < 0.65:
				player.start_attack() # Mid-air slam finisher
			if state_time >= 1.0:
				_set_state(State.BOSS_FINISHER)

		State.BOSS_FINISHER:
			# Final 360-degree Crescent Beam lethal strike
			player.facing_direction = (boss.global_position - player.global_position).normalized() if is_instance_valid(boss) else Vector2.RIGHT
			player.combo_step = 2
			player.start_attack()
			if is_instance_valid(boss):
				boss.receive_hit(12, player.facing_direction)
			if state_time >= 1.5:
				_set_state(State.FINISH)

		State.FINISH:
			print(">>> [QV RECORDER] Quarter-View choreography finished! Time: %.2fs" % total_elapsed)
			quit(0)

	return false


func _set_state(new_st: State) -> void:
	current_state = new_st
	state_time = 0.0
	print(">>> [QV RECORDER] State -> %s (at %.2fs)" % [State.keys()[new_st], total_elapsed])
