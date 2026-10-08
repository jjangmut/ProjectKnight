extends SceneTree
## Dynamic Character Visual Evolution & Equipment Morph Cinematic Showcase Recorder
## Showcases:
## 1. Stage 0: Baseline Knight with simple steel shortsword
## 2. Stage 1: Holy Broadsword & Aegis Bastion Sigil guard barrier
## 3. Stage 2: Windrunner Emerald Cloak & Gale Dash afterimages
## 4. Stage 3: Arcane Crystal Greatsword & Arcane Cyan Sword Beam
## 5. Stage 4: Titan Ancient Rock Pauldrons & Ground Slam Seismic Shockwave
## 6. Stage 5: Abyssal Horned Helmet Crown, Blazing Eye Flames & Void Crit 4 Slash
## 7. Stage Reward Card with new Equipment Evolution descriptions

const CampaignScene = preload("res://scenes/stage/Campaign.tscn")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const SwordBeamScene = preload("res://scripts/player/sword_beam.gd")

enum Phase {
	STAGE_0_BASELINE,
	STAGE_1_HOLY_AEGIS,
	STAGE_2_WINDRUNNER,
	STAGE_3_CRYSTAL_BLADE,
	STAGE_4_TITAN_SHOCKWAVE,
	STAGE_5_ABYSSAL_CROWN,
	STAGE_REWARD_CARD,
	FINISH
}

var current_phase: Phase = Phase.STAGE_0_BASELINE
var phase_time: float = 0.0
var total_time: float = 0.0

var campaign: Node = null
var stage: Node2D = null
var player: CharacterBody2D = null
var equip: Node2D = null
var presentation_ui: Control = null

func _init() -> void:
	print(">>> [EVOLUTION SHOWCASE] Initializing Evolution Cinematic Showcase...")
	SaveManagerClass.clear_save()
	# 15s Watchdog timer
	create_timer(15.0).timeout.connect(func():
		printerr("[WATCHDOG TIMEOUT] Recorder reached 15s limit, closing.")
		quit(0)
	)
	call_deferred("_start_showcase")


func _start_showcase() -> void:
	campaign = CampaignScene.instantiate()
	root.add_child(campaign)
	current_scene = campaign

	await process_frame
	await process_frame

	stage = campaign.stage
	player = stage.player
	equip = player.get_node_or_null("EquipmentVisuals")
	presentation_ui = stage.get_node_or_null("HUD/Presentation")

	# Position player on flat ground with good camera framing
	player.global_position = Vector2(400.0, 580.0)
	player.velocity = Vector2.ZERO

	# Disable mobile controls to highlight character visuals
	var mobile_controls = stage.get_node_or_null("HUD/MobileControls")
	if mobile_controls != null:
		mobile_controls.visible = false

	print(">>> [EVOLUTION SHOWCASE] Setup ready. Starting sequence...")


func _process(delta: float) -> bool:
	if player == null or not is_instance_valid(player):
		return false

	phase_time += delta
	total_time += delta

	match current_phase:
		Phase.STAGE_0_BASELINE:
			# Baseline appearance (idle & run)
			if phase_time < 0.4:
				player.velocity.x = 0.0
			elif phase_time < 0.8:
				player.velocity.x = 180.0
			elif phase_time >= 1.0:
				player.velocity.x = 0.0
				_set_phase(Phase.STAGE_1_HOLY_AEGIS)

		Phase.STAGE_1_HOLY_AEGIS:
			# Stage 1: Holy Broadsword & Aegis Bastion Sigil guard barrier
			if phase_time < 0.05:
				SaveManagerClass.mark_stage_cleared(1)
				player.refresh_equipment()
				player.velocity.x = 0.0
			elif phase_time < 0.5:
				# Show equipped holy broadsword
				player.velocity.x = 0.0
			elif phase_time < 1.1:
				# Raise guard -> Aegis barrier expands and rotates
				player.is_guarding = true
			elif phase_time >= 1.2:
				player.is_guarding = false
				_set_phase(Phase.STAGE_2_WINDRUNNER)

		Phase.STAGE_2_WINDRUNNER:
			# Stage 2: Windrunner Emerald Cloak & Dash Gale
			if phase_time < 0.05:
				SaveManagerClass.mark_stage_cleared(2)
				player.refresh_equipment()
			elif phase_time < 0.3:
				player.velocity.x = 220.0
			elif phase_time < 0.8:
				# Dash with Emerald gale trail
				if not player.is_dashing:
					player.dash()
			elif phase_time >= 1.1:
				_set_phase(Phase.STAGE_3_CRYSTAL_BLADE)

		Phase.STAGE_3_CRYSTAL_BLADE:
			# Stage 3: Arcane Crystal Greatsword & Cyan Sword Beam
			if phase_time < 0.05:
				SaveManagerClass.mark_stage_cleared(3)
				player.refresh_equipment()
				player.global_position = Vector2(400.0, 580.0)
				player.velocity = Vector2.ZERO
			elif phase_time < 0.4:
				player.velocity.x = 0.0
			elif phase_time < 0.9:
				# Fire Arcane Crystal Sword Beam
				if phase_time < 0.5:
					var beam := SwordBeamScene.new()
					beam.position = player.global_position + Vector2(36.0, -8.0)
					beam.direction = 1.0
					beam.is_crystal_beam = true
					beam.max_distance = 600.0
					stage.add_child(beam)
			elif phase_time >= 1.2:
				_set_phase(Phase.STAGE_4_TITAN_SHOCKWAVE)

		Phase.STAGE_4_TITAN_SHOCKWAVE:
			# Stage 4: Ancient Titan Pauldrons & Ground Slam Seismic Shockwave
			if phase_time < 0.05:
				SaveManagerClass.mark_stage_cleared(4)
				player.refresh_equipment()
				player.global_position = Vector2(400.0, 460.0) # Mid-air
				player.velocity = Vector2(0, 380.0)
			elif phase_time < 0.5:
				# Falling towards ground
				pass
			elif phase_time >= 1.1:
				_set_phase(Phase.STAGE_5_ABYSSAL_CROWN)

		Phase.STAGE_5_ABYSSAL_CROWN:
			# Stage 5: Abyssal Horned Crown & Visor Eye Flame & Void Crit Slash
			if phase_time < 0.05:
				SaveManagerClass.mark_stage_cleared(5)
				player.refresh_equipment()
				player.global_position = Vector2(400.0, 580.0)
				player.velocity = Vector2.ZERO
			elif phase_time < 0.5:
				# Show crown and blazing crimson visor eyes
				pass
			elif phase_time < 1.0:
				# Trigger parry counter with void slash
				if phase_time < 0.6:
					player.is_perfect_parry = true
					player._start_counter_attack()
			elif phase_time >= 1.2:
				_set_phase(Phase.STAGE_REWARD_CARD)

		Phase.STAGE_REWARD_CARD:
			# Show Stage Clear Reward Card with equipment transformation text
			if phase_time < 0.05:
				stage.stage_state = 1 # CLEARED
				stage.stage_number = 5 # Show final stage reward card
				if presentation_ui != null:
					presentation_ui.queue_redraw()
			elif phase_time >= 1.5:
				_set_phase(Phase.FINISH)

		Phase.FINISH:
			print(">>> [EVOLUTION SHOWCASE] All phases complete! Exiting...")
			quit(0)
			return true

	return false


func _set_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	phase_time = 0.0
	print(">>> [EVOLUTION SHOWCASE] Phase -> %s (elapsed: %.2fs)" % [Phase.keys()[new_phase], total_time])
