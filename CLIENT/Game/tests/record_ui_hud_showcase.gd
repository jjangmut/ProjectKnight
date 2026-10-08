extends SceneTree
## UI & HUD 4-Step Cinematic Showcase Recorder
## Showcases:
## 1. Translucent Rune Glassmorphism Joypad & Action Cluster (Attack, Dash, Shield)
## 2. Gothic Knight Avatar Shield & Faceted 3-Gem Ruby Soul Crystals
## 3. Third Blade Dynamic Combo Counter (Hits, Scale Bounce, Gauge, Rank) & Just Parry Banner
## 4. Dungeon Hunter 2 Gothic Winged Boss Bar with Phase Dividers & Enraged Pulse

const CampaignScene = preload("res://scenes/stage/Campaign.tscn")
const SaveManagerClass = preload("res://scripts/system/save_manager.gd")
const BossCommanderClass = preload("res://scripts/enemy/boss_commander.gd")

enum Phase {
	INTRO,            # Show HUD & Translucent Mobile Controls
	COMBAT_COMBO,     # Attack enemies, stack Third Blade Combo counter
	JUST_PARRY,       # Trigger Just Parry Banner & Radial Shockwave
	BOSS_ENTRY,       # Spawn Boss & show Gothic Wing Boss Bar with Phase Dividers
	BOSS_DAMAGE,      # Hit boss, show Linger Amber damage trail
	BOSS_ENRAGE,      # Phase 2 Enraged activation & pulse
	FINISH
}

var current_phase: Phase = Phase.INTRO
var phase_time: float = 0.0
var total_time: float = 0.0

var campaign: Node = null
var stage: Node2D = null
var player: CharacterBody2D = null
var boss: CharacterBody2D = null
var presentation_ui: Control = null
var mobile_controls: CanvasLayer = null

func _init() -> void:
	print(">>> [UI SHOWCASE] Initializing UI/HUD 4-Step Showcase...")
	SaveManagerClass.clear_save()
	call_deferred("_start_showcase")


func _start_showcase() -> void:
	campaign = CampaignScene.instantiate()
	root.add_child(campaign)
	current_scene = campaign

	await process_frame
	await process_frame

	stage = campaign.stage
	player = stage.player
	presentation_ui = stage.get_node_or_null("HUD/Presentation")
	mobile_controls = stage.get_node_or_null("HUD/MobileControls")

	# Enable Mobile Controls explicitly for showcase visibility
	if mobile_controls != null:
		mobile_controls.visible = true
		if mobile_controls.has_node("VirtualJoypad"):
			mobile_controls.get_node("VirtualJoypad").visible = true
		if mobile_controls.has_node("ActionCluster"):
			mobile_controls.get_node("ActionCluster").visible = true

	# Set player position in stage 1 arena
	player.position = Vector2(9150.0, 580.0)
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam != null:
		cam.force_update_scroll()

	# Clear legacy labels
	if stage.status_label != null:
		stage.status_label.text = ""

	print(">>> [UI SHOWCASE] Ready. Starting choreographed presentation sequence.")


func _physics_process(delta: float) -> bool:
	if campaign == null or stage == null:
		return false
	if is_instance_valid(campaign.stage):
		stage = campaign.stage
		player = stage.player
	if player == null or not is_instance_valid(player):
		return false

	# Immortality
	player.current_hp = 3
	player.is_dead = false

	phase_time += delta
	total_time += delta

	# Hard timeout: 9.0s max
	if total_time >= 9.0:
		print(">>> [UI SHOWCASE] Showcase completed (%.2fs). Exiting." % total_time)
		quit(0)
		return true

	match current_phase:
		Phase.INTRO:
			# Display Mobile Controls and Knight Avatar Status
			if presentation_ui != null:
				presentation_ui.intro_remaining = 0.0
			if phase_time >= 1.0:
				_set_phase(Phase.COMBAT_COMBO)

		Phase.COMBAT_COMBO:
			# Feed hits to trigger Third Blade Combo Counter
			if phase_time < 0.6:
				if is_instance_valid(player) and player.has_signal("enemy_hit_registered"):
					player.enemy_hit_registered.emit(null, false, 1)
			elif phase_time < 1.2:
				if is_instance_valid(player) and player.has_signal("enemy_hit_registered"):
					player.enemy_hit_registered.emit(null, true, 2)
			else:
				_set_phase(Phase.JUST_PARRY)

		Phase.JUST_PARRY:
			# Trigger Just Parry Golden Banner & Shockwave ring
			if phase_time < 0.05:
				if is_instance_valid(player) and player.has_signal("perfect_parry_performed"):
					player.perfect_parry_performed.emit()
			if phase_time >= 1.2:
				_set_phase(Phase.BOSS_ENTRY)

		Phase.BOSS_ENTRY:
			# Spawn boss & activate Gothic Winged Boss Health Bar
			if phase_time < 0.05:
				stage._spawn_boss_encounter()
				if not stage.enemies.is_empty():
					boss = stage.enemies[0]
					boss.position = Vector2(9400.0, 580.0)
					boss.max_hp = 20
					boss.current_hp = 20
					boss.boss_hp_changed.emit(20, 20)
			if phase_time >= 1.2:
				_set_phase(Phase.BOSS_DAMAGE)

		Phase.BOSS_DAMAGE:
			# Boss takes heavy hit: Boss bar shows Ruby drain and lingering Amber trail
			if phase_time < 0.05:
				if is_instance_valid(boss):
					boss.current_hp = 10 # 50% HP
					boss.boss_hp_changed.emit(10, 20)
			if phase_time >= 1.2:
				_set_phase(Phase.BOSS_ENRAGE)

		Phase.BOSS_ENRAGE:
			# Phase 2 Enraged: Boss health bar glows red, enrage pulse active
			if phase_time < 0.05:
				if is_instance_valid(boss):
					boss.current_hp = 4 # 20% HP
					boss.boss_hp_changed.emit(4, 20)
					boss.boss_phase_changed.emit(2)
			if phase_time >= 1.5:
				_set_phase(Phase.FINISH)

		Phase.FINISH:
			quit(0)
			return true

	return false


func _set_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	phase_time = 0.0
	print(">>> [UI SHOWCASE] Phase -> %s (elapsed: %.2fs)" % [Phase.keys()[new_phase], total_time])
