extends Resource
class_name CombatActionDefinition
## ProjectKnight V3-026: Combat Action Definition Resource
## Immutable specification of attack timing, hitbox geometry, and sensory feedback.

@export var action_id: String = "attack_1"
@export var attacker_kind: String = "hero" # hero, grunt, shield_knight, boss
@export var total_duration: float = 0.32
@export var windup_duration: float = 0.08
@export var active_duration: float = 0.10
@export var recovery_duration: float = 0.14
@export var contact_time: float = 0.09 # Exact timestamp when blade strikes target

# Hitbox & Collision Geometry
@export var damage: int = 2
@export var hitbox_reach_x: float = 1.65 # Forward reach in meters
@export var hitbox_depth_z: float = 0.65 # Half-depth lane tolerance (+-Z)
@export var hitbox_height_y: float = 1.80
@export var hitbox_offset: Vector3 = Vector3(0.85, 0.85, 0.0)
@export var knockback_force: float = 3.5

# Hitstop & Sensory Profiles
@export var hitstop_attacker_sec: float = 0.040 # 40ms local freeze
@export var hitstop_victim_sec: float = 0.065 # 65ms local freeze
@export var camera_trauma: float = 0.15 # Modest directional impulse
@export var camera_impulse_dir: Vector3 = Vector3(1.0, 0.0, 0.0)

# Cancel & Buffer Timing
@export var cancel_window_start: float = 0.19 # Allowed to cancel into next combo/guard
@export var combo_buffer_start: float = 0.12 # Allowed to buffer next attack input

# Visual & Animation Mapping
@export var sprite_texture: Texture2D = null
@export var hframes: int = 2
@export var vframes: int = 2
@export var total_frames: int = 4
@export var windup_frames: Array[int] = [0]
@export var active_frames: Array[int] = [1, 2]
@export var recovery_frames: Array[int] = [3]

# Audio Hooks
@export var swing_sfx: String = "player_slash_1"
@export var hit_sfx: String = "enemy_hit_impact"
@export var block_sfx: String = "guard_block"
@export var counter_sfx: String = "enemy_hit_counter"


func get_active_start_time() -> float:
	return windup_duration


func get_active_end_time() -> float:
	return windup_duration + active_duration


func is_in_windup(time: float) -> bool:
	return time < windup_duration


func is_in_active(time: float) -> bool:
	return time >= windup_duration and time < (windup_duration + active_duration)


func is_in_recovery(time: float) -> bool:
	return time >= (windup_duration + active_duration)


func is_cancelable(time: float) -> bool:
	return time >= cancel_window_start


func get_frame_for_time(time: float) -> int:
	if is_in_windup(time):
		if windup_frames.is_empty():
			return 0
		var prog := clampf(time / maxf(0.001, windup_duration), 0.0, 0.999)
		return windup_frames[int(prog * windup_frames.size())]
	elif is_in_active(time):
		if active_frames.is_empty():
			return 0
		var elapsed_active := time - windup_duration
		var prog := clampf(elapsed_active / maxf(0.001, active_duration), 0.0, 0.999)
		return active_frames[int(prog * active_frames.size())]
	else:
		if recovery_frames.is_empty():
			return 0
		var elapsed_recovery := time - (windup_duration + active_duration)
		var prog := clampf(elapsed_recovery / maxf(0.001, recovery_duration), 0.0, 0.999)
		return recovery_frames[int(prog * recovery_frames.size())]
