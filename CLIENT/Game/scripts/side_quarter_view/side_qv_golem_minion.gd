extends "res://scripts/side_quarter_view/side_qv_enemy.gd"
class_name SideQVGolemMinion
## 사이드 쿼터뷰 헤비 골렘 미니언 (Heavy Golem Minion)
## - 스프라이트: res://assets/enemy_frames/golem_v1.png (3x2 frames)
## - 묵직한 거구 (신장 ~2.0m), 높은 내구도 (HP 8) 및 강력한 암석 강타
## - Option C: Z=0.0 평면 엄격 고정 및 수평 1차원 이동/피격

const GolemMinionTexture = preload("res://assets/enemy_frames/golem_v1.png")


func _ready() -> void:
	max_hp = 8
	current_hp = 8
	move_speed = 2.6
	attack_damage = 2
	attack_cooldown = 1.6
	velocity.z = 0.0
	global_position.z = 0.0
	super._ready()


func _build_components() -> void:
	super._build_components()
	# Override components for Heavy Golem
	sprite_3d.texture = GolemMinionTexture
	sprite_3d.hframes = 3
	sprite_3d.vframes = 2
	sprite_3d.frame = 0
	sprite_3d.pixel_size = 0.0039 # 512px * 0.0039 = ~2.0m height
	sprite_3d.position.y = 1.0

	# Heavy Collision Capsule
	for child in get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			var cap := child.shape as CapsuleShape3D
			cap.radius = 0.55
			cap.height = 2.0
			child.position.y = 1.0

	# Heavy Attack Area
	if attack_area_3d != null:
		for child in attack_area_3d.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				var box := child.shape as BoxShape3D
				box.size = Vector3(2.0, 1.8, 1.8)
				child.position = Vector3(0.0, 1.0, 0.0)


func _prevent_player_pushing() -> void:
	if target_player != null and is_instance_valid(target_player):
		var diff_x := target_player.global_position.x - global_position.x
		var dist_x := absf(diff_x)
		var min_dist: float = 0.55 + 0.35 + 0.08 # Heavy golem radius (0.55) + player (0.35)
		if dist_x < min_dist and dist_x > 0.001:
			var dir_x := signf(diff_x)
			if (velocity.x * dir_x) > 0.0:
				velocity.x = 0.0
