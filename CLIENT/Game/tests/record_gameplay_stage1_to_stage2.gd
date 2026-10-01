extends SceneTree
## Automated Choreographed Playthrough Script for Video Recording: Stage 1 to Stage 2
## Records high-octane gameplay, boss fights, relic reward cards, and visual equipment.

const CampaignScene = preload("res://scenes/stage/Campaign.tscn")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const BossCommanderClass = preload("res://scripts/enemy/boss_commander.gd")
const BeastChieftainClass = preload("res://scripts/enemy/beast_chieftain.gd")

enum State {
	S1_INTRO,
	S1_ENCOUNTER_1,
	S1_ENCOUNTER_2,
	S1_BOSS_APPROACH,
	S1_BOSS_SPAWN,
	S1_BOSS_FIGHT_BEAM,
	S1_BOSS_FIGHT_PARRY,
	S1_BOSS_FIGHT_SLAM,
	S1_BOSS_FIGHT_FINISH,
	S1_CLEAR_CARD,
	S2_TRANSITION,
	S2_BEAST_ENCOUNTER,
	S2_BOSS_SPAWN,
	S2_BOSS_FIGHT,
	S2_CLEAR_CARD,
	FINISH
}

var current_state: State = State.S1_INTRO
var state_time: float = 0.0
var total_elapsed: float = 0.0

var campaign: Node = null
var stage: Node2D = null
var player: CharacterBody2D = null
var boss_actor: CharacterBody2D = null


func _init() -> void:
	print(">>> [RECORDER] Initializing Stage 1 -> Stage 2 Playthrough Director...")
	SaveManagerClass.clear_save()
	call_deferred("_start_recording")


func _start_recording() -> void:
	campaign = CampaignScene.instantiate()
	root.add_child(campaign)
	current_scene = campaign
	await process_frame
	await process_frame

	stage = campaign.stage
	player = stage.player
	player.position = Vector2(250.0, 580.0)
	print(">>> [RECORDER] Campaign initialized on Stage 1. Starting Choreography!")


func _physics_process(delta: float) -> bool:
	if campaign == null:
		return false
	if is_instance_valid(campaign.stage):
		stage = campaign.stage
		player = stage.player
	if player != null and is_instance_valid(player):
		player.current_hp = 3
		player.is_dead = false

	state_time += delta
	total_elapsed += delta

	match current_state:
		State.S1_INTRO:
			# Player runs right into Stage 1
			Input.action_press("move_right")
			if state_time >= 1.5:
				Input.action_release("move_right")
				_set_state(State.S1_ENCOUNTER_1)

		State.S1_ENCOUNTER_1:
			# Confront melee guard: Combo 1 -> 2 -> 3 + SwordBeam
			if state_time < 0.2:
				Input.action_press("move_right")
			elif state_time < 0.35:
				Input.action_release("move_right")
				Input.action_press("attack")
			elif state_time < 0.60:
				Input.action_release("attack")
			elif state_time < 0.75:
				Input.action_press("attack") # Combo 2
			elif state_time < 1.00:
				Input.action_release("attack")
			elif state_time < 1.15:
				Input.action_press("attack") # Combo 3 (Finisher + SwordBeam!)
			elif state_time < 1.40:
				Input.action_release("attack")
				Input.action_press("jump") # Jump forward
				Input.action_press("move_right")
			elif state_time < 2.0:
				Input.action_release("jump")
			elif state_time >= 2.5:
				Input.action_release("move_right")
				_set_state(State.S1_ENCOUNTER_2)

		State.S1_ENCOUNTER_2:
			# Guard deflect vs arrow, counter attack, air jump strike
			if state_time < 0.3:
				Input.action_press("move_right")
			elif state_time < 1.1:
				Input.action_release("move_right")
				Input.action_press("guard") # Solid metal guard
			elif state_time < 1.4:
				Input.action_release("guard")
				Input.action_press("attack") # Counter attack
			elif state_time < 1.8:
				Input.action_release("attack")
				Input.action_press("jump")
				Input.action_press("move_right")
			elif state_time < 2.1:
				Input.action_press("attack") # Air attack strike
			elif state_time >= 2.6:
				Input.action_release("attack")
				Input.action_release("jump")
				Input.action_release("move_right")
				_set_state(State.S1_BOSS_APPROACH)

		State.S1_BOSS_APPROACH:
			# Fast sprint towards gate chamber
			Input.action_press("move_right")
			if state_time >= 1.6:
				Input.action_release("move_right")
				_set_state(State.S1_BOSS_SPAWN)

		State.S1_BOSS_SPAWN:
			# Direct spawn Boss Commander right in arena
			if state_time < 0.1 and boss_actor == null:
				for child in stage.get_children():
					if child.is_in_group("enemy") or child.is_in_group("enemy_projectile"):
						child.queue_free()
				boss_actor = BossCommanderClass.new()
				boss_actor.position = player.position + Vector2(280.0, 0.0)
				boss_actor.current_hp = 12
				stage.add_child(boss_actor)
				# Attach boss health bar
				var bar_scene = load("res://scenes/ui/BossHealthBar.tscn")
				if bar_scene != null:
					var bar = bar_scene.instantiate()
					stage.get_node("HUD").add_child(bar)
					bar.initialize_boss(boss_actor, "타락한 방패 기사단장", 12)
			elif state_time >= 1.2:
				_set_state(State.S1_BOSS_FIGHT_BEAM)

		State.S1_BOSS_FIGHT_BEAM:
			# Boss unleashes flying crimson sword beam! Player jumps over it
			if state_time < 0.1:
				if boss_actor != null and is_instance_valid(boss_actor) and boss_actor.has_method("_fire_boss_sword_beam"):
					boss_actor._fire_boss_sword_beam()
			elif state_time > 0.3 and state_time < 0.8:
				Input.action_press("jump") # Jump over beam
				Input.action_press("move_right")
			elif state_time >= 1.4:
				Input.action_release("jump")
				Input.action_release("move_right")
				_set_state(State.S1_BOSS_FIGHT_PARRY)

		State.S1_BOSS_FIGHT_PARRY:
			# Boss melee strike -> Player Perfect Parry (Golden spark) -> Critical Counter!
			if state_time < 0.6:
				Input.action_press("guard")
				player.is_guarding = true
				player._guard_elapsed = 0.05
			elif state_time < 0.9:
				player.is_perfect_parry = true
				player._counter_window_remaining = 0.60
				Input.action_release("guard")
				Input.action_press("attack") # Critical Counter (3 dmg!)
				if boss_actor != null and is_instance_valid(boss_actor):
					boss_actor.take_damage(3)
			elif state_time >= 1.4:
				Input.action_release("attack")
				_set_state(State.S1_BOSS_FIGHT_SLAM)

		State.S1_BOSS_FIGHT_SLAM:
			# Boss Leap Slam -> Player rides TopPlatform & Down Thrust
			if state_time < 0.3:
				Input.action_press("jump")
				Input.action_press("move_right")
			elif state_time < 0.7:
				if boss_actor != null and is_instance_valid(boss_actor):
					player.position.x = boss_actor.position.x
					player.position.y = boss_actor.position.y - 75.0
				player.is_down_thrusting = true
				if boss_actor != null and is_instance_valid(boss_actor):
					boss_actor.take_damage(3)
			elif state_time >= 1.3:
				Input.action_release("jump")
				Input.action_release("move_right")
				player.is_down_thrusting = false
				_set_state(State.S1_BOSS_FIGHT_FINISH)

		State.S1_BOSS_FIGHT_FINISH:
			# Deliver Combo 3 Finisher -> Boss Commander cleanly defeated!
			if state_time < 0.3:
				Input.action_press("attack")
			elif state_time < 0.6:
				Input.action_release("attack")
			elif state_time < 0.9:
				Input.action_press("attack")
				if boss_actor != null and is_instance_valid(boss_actor):
					boss_actor.is_invulnerable = false
					boss_actor.current_phase = 2
					boss_actor.current_hp = 0
					boss_actor.is_dead = true
					boss_actor._die()
					boss_actor.queue_free()
					boss_actor = null
			elif state_time >= 1.3:
				Input.action_release("attack")
				var bar = stage.get_node_or_null("HUD/BossHealthBar")
				if bar != null: bar.queue_free()
				if stage.get("mobile_controls") != null and is_instance_valid(stage.mobile_controls):
					stage.mobile_controls.visible = false
				stage._finish(stage.StageState.CLEARED)
				_set_state(State.S1_CLEAR_CARD)

		State.S1_CLEAR_CARD:
			# Stage Clear Reward Card appears! Bastion Shield unlocked!
			var bar = stage.get_node_or_null("HUD/BossHealthBar")
			if bar != null: bar.visible = false
			if stage.get("mobile_controls") != null and is_instance_valid(stage.mobile_controls):
				stage.mobile_controls.visible = false
			if campaign.panel != null and is_instance_valid(campaign.panel):
				campaign.panel.visible = false
			var pres = stage.get_node_or_null("HUD/Presentation")
			if pres != null:
				pres.visible = true
			if state_time >= 3.6:
				_set_state(State.S2_TRANSITION)

		State.S2_TRANSITION:
			# Advance to Stage 2 via Campaign
			if state_time < 0.1:
				if campaign.panel != null and is_instance_valid(campaign.panel):
					campaign.panel.visible = true
				campaign.choose_trait("basic")
			elif state_time >= 1.0:
				stage = campaign.stage
				player = stage.player
				player.position = Vector2(250.0, 580.0)
				boss_actor = null
				# Equip the Bastion Shield
				player.refresh_equipment()
				_set_state(State.S2_BEAST_ENCOUNTER)

		State.S2_BEAST_ENCOUNTER:
			# Wild Beast Forest: Shield Guard against Charging Beast + Shadow Dash
			if state_time < 0.8:
				Input.action_press("move_right")
			elif state_time < 1.6:
				Input.action_release("move_right")
				Input.action_press("guard") # Bastion Shield flaring forward!
			elif state_time < 2.0:
				Input.action_release("guard")
				player.dash() # Shadow Dash through beast!
			elif state_time < 2.6:
				Input.action_press("attack") # Combo slash from behind
			elif state_time >= 3.0:
				Input.action_release("attack")
				_set_state(State.S2_BOSS_SPAWN)

		State.S2_BOSS_SPAWN:
			# Spawn Beast Chieftain Boss right in arena
			if state_time < 0.1 and boss_actor == null:
				for child in stage.get_children():
					if child.is_in_group("enemy") or child.is_in_group("enemy_projectile"):
						child.queue_free()
				boss_actor = BeastChieftainClass.new()
				boss_actor.position = player.position + Vector2(280.0, 0.0)
				boss_actor.current_hp = 14
				stage.add_child(boss_actor)
				# Attach boss health bar
				var bar_scene = load("res://scenes/ui/BossHealthBar.tscn")
				if bar_scene != null:
					var bar = bar_scene.instantiate()
					stage.get_node("HUD").add_child(bar)
					bar.initialize_boss(boss_actor, "심연의 맹수 우두머리", 14)
			elif state_time >= 1.2:
				_set_state(State.S2_BOSS_FIGHT)

		State.S2_BOSS_FIGHT:
			# Fierce battle with Beast Chieftain: Shield Parries, Dash, Finisher
			if state_time < 0.6:
				Input.action_press("guard") # Guard with Bastion Shield
			elif state_time < 1.0:
				Input.action_release("guard")
				Input.action_press("attack") # Counter Strike
				if boss_actor != null and is_instance_valid(boss_actor):
					boss_actor.take_damage(4)
			elif state_time < 1.4:
				Input.action_release("attack")
				player.dash() # Evasive dash
			elif state_time < 1.8:
				Input.action_press("jump")
			elif state_time < 2.2:
				Input.action_press("attack") # Aerial down slash
			elif state_time < 2.6:
				Input.action_release("jump")
				Input.action_release("attack")
			elif state_time < 3.2:
				Input.action_press("attack") # 3-Hit Combo Finisher
				if boss_actor != null and is_instance_valid(boss_actor):
					boss_actor.is_invulnerable = false
					boss_actor.current_hp = 0
					boss_actor.is_dead = true
					boss_actor._die()
					boss_actor.queue_free()
					boss_actor = null
			elif state_time >= 3.6:
				Input.action_release("attack")
				var bar = stage.get_node_or_null("HUD/BossHealthBar")
				if bar != null: bar.queue_free()
				if stage.get("mobile_controls") != null and is_instance_valid(stage.mobile_controls):
					stage.mobile_controls.visible = false
				stage._finish(stage.StageState.CLEARED)
				_set_state(State.S2_CLEAR_CARD)

		State.S2_CLEAR_CARD:
			# Stage 2 Clear Reward Card appears! Shadow Cloak unlocked!
			if stage.get("mobile_controls") != null and is_instance_valid(stage.mobile_controls):
				stage.mobile_controls.visible = false
			if campaign.panel != null and is_instance_valid(campaign.panel):
				campaign.panel.visible = false
			var pres = stage.get_node_or_null("HUD/Presentation")
			if pres != null:
				pres.visible = true
			if state_time >= 4.0:
				_set_state(State.FINISH)

		State.FINISH:
			print(">>> [RECORDER] Completed Playthrough Recording successfully! (Total Time: %.2fs)" % total_elapsed)
			quit(0)

	return false


func _set_state(next_state: State) -> void:
	current_state = next_state
	state_time = 0.0
	print(">>> [STATE TRANSITION] Entered: %s (at %.2fs)" % [State.keys()[next_state], total_elapsed])
