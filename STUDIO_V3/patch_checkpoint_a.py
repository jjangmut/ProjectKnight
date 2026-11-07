"""Script to apply Checkpoint A: Option C fixed gameplay plane (Z = 0.0) across Player, Enemy, Boss, and Stage 1."""
from pathlib import Path

def patch_player():
    path = Path(r"D:\JUNYPAPA_STUDIO\Projects\ProjectKnight\CLIENT\Game\scripts\side_quarter_view\side_qv_player.gd")
    content = path.read_text(encoding="utf-8")
    
    # 1. Bounds: lock Z
    target_bounds = """\t\tif "arena_depth" in p:
\t\t\tvar d: float = float(p.get("arena_depth"))
\t\t\tstage_min_z = -d * 0.5 + 0.8
\t\t\tstage_max_z = d * 0.5 - 0.8"""
    replacement_bounds = """\t\t# Option C: Enforce strictly 2D gameplay plane at Z = 0.0
\t\tstage_min_z = 0.0
\t\tstage_max_z = 0.0"""
    assert target_bounds in content, "target_bounds not found in player.gd"
    content = content.replace(target_bounds, replacement_bounds)

    # 2. _clamp_arena_bounds: strictly clamp Z = 0.0, velocity.z = 0.0
    target_clamp = """func _clamp_arena_bounds() -> void:
\t_sync_stage_bounds()
\tglobal_position.x = clampf(global_position.x, stage_min_x, stage_max_x)
\tglobal_position.z = clampf(global_position.z, stage_min_z, stage_max_z)"""
    replacement_clamp = """func _clamp_arena_bounds() -> void:
\t_sync_stage_bounds()
\tglobal_position.x = clampf(global_position.x, stage_min_x, stage_max_x)
\t# Option C: Zero Z drift
\tglobal_position.z = 0.0
\tvelocity.z = 0.0"""
    assert target_clamp in content, "target_clamp not found in player.gd"
    content = content.replace(target_clamp, replacement_clamp)

    # 3. _process_movement: only X axis motion, Z motion eliminated
    target_move = """func _process_movement(delta: float) -> void:
\tvar input_vec := Vector3.ZERO
\tif Input.is_action_pressed("move_left"):
\t\tinput_vec.x -= 1.0
\tif Input.is_action_pressed("move_right"):
\t\tinput_vec.x += 1.0
\tif Input.is_action_pressed("move_up"):
\t\tinput_vec.z -= 1.0
\tif Input.is_action_pressed("move_down"):
\t\tinput_vec.z += 1.0

\t# Side Quarter-View Movement
\tif input_vec.x != 0.0:
\t\tfacing_dir_x = signf(input_vec.x)
\t\t# Flip attack and guard offsets
\t\tattack_area_3d.position.x = 1.0 * facing_dir_x
\t\tguard_barrier_3d.position.x = 0.6 * facing_dir_x
\t\tslash_visual_3d.position.x = 1.15 * facing_dir_x

\tif input_vec != Vector3.ZERO:
\t\tvar norm := input_vec.normalized()
\t\tvelocity.x = norm.x * move_speed_x
\t\tvelocity.z = norm.z * move_speed_z
\t\tmove_direction = norm
\t\t_set_state(State.MOVE)
\telse:
\t\tvelocity.x = move_toward(velocity.x, 0.0, 45.0 * delta)
\t\tvelocity.z = move_toward(velocity.z, 0.0, 45.0 * delta)
\t\tmove_direction = Vector3.ZERO
\t\t_set_state(State.IDLE)"""

    replacement_move = """func _process_movement(delta: float) -> void:
\tvar input_x := 0.0
\tif Input.is_action_pressed("move_left"):
\t\tinput_x -= 1.0
\tif Input.is_action_pressed("move_right"):
\t\tinput_x += 1.0

\t# Option C: Fixed 2D side-scroller movement on X/Y (Z strictly locked to 0)
\tif input_x != 0.0:
\t\tfacing_dir_x = signf(input_x)
\t\tattack_area_3d.position.x = 1.0 * facing_dir_x
\t\tguard_barrier_3d.position.x = 0.6 * facing_dir_x
\t\tslash_visual_3d.position.x = 1.15 * facing_dir_x
\t\tvelocity.x = input_x * move_speed_x
\t\tvelocity.z = 0.0
\t\tmove_direction = Vector3(facing_dir_x, 0.0, 0.0)
\t\t_set_state(State.MOVE)
\telse:
\t\tvelocity.x = move_toward(velocity.x, 0.0, 45.0 * delta)
\t\tvelocity.z = 0.0
\t\tmove_direction = Vector3.ZERO
\t\t_set_state(State.IDLE)"""
    assert target_move in content, "target_move not found in player.gd"
    content = content.replace(target_move, replacement_move)

    # 4. Action inputs: Dive slam check retains move_down without Z movement
    target_actions = """\telif (Input.is_action_just_pressed("attack") or attack_buffer_timer > 0.0) and attack_cooldown <= 0.0:
\t\tattack_buffer_timer = 0.0
\t\tif not is_on_floor() and (Input.is_action_pressed("move_down") or move_direction.z > 0.35):
\t\t\tstart_dive_slam()
\t\telse:
\t\t\tstart_attack()"""
    replacement_actions = """\telif (Input.is_action_just_pressed("attack") or attack_buffer_timer > 0.0) and attack_cooldown <= 0.0:
\t\tattack_buffer_timer = 0.0
\t\tif not is_on_floor() and (Input.is_action_pressed("move_down") or global_position.y >= 0.35 and Input.is_action_pressed("move_down")):
\t\t\tstart_dive_slam()
\t\telse:
\t\t\tstart_attack()"""
    assert target_actions in content, "target_actions not found in player.gd"
    content = content.replace(target_actions, replacement_actions)

    # 5. Dash: strictly along X
    target_dash = """\tvar dash_dir := move_direction if move_direction != Vector3.ZERO else Vector3(facing_dir_x, 0, 0)
\tvelocity.x = dash_dir.x * dash_speed
\tvelocity.z = dash_dir.z * dash_speed"""
    replacement_dash = """\tvar dash_dir := Vector3(facing_dir_x, 0.0, 0.0)
\tvelocity.x = dash_dir.x * dash_speed
\tvelocity.z = 0.0"""
    assert target_dash in content, "target_dash not found in player.gd"
    content = content.replace(target_dash, replacement_dash)

    # 6. _prevent_enemy_pushing: resolve along X
    target_push = """func _prevent_enemy_pushing() -> void:
\t# Avoid sliding into or pushing monsters; halt clean on contact boundary
\tvar enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
\tfor enemy in enemies:
\t\tif not is_instance_valid(enemy) or enemy == self or not (enemy is Node3D):
\t\t\tcontinue
\t\tvar enemy_3d := enemy as Node3D
\t\tvar diff: Vector3 = enemy_3d.global_position - global_position
\t\tdiff.y = 0.0
\t\tvar dist: float = diff.length()
\t\tvar enemy_radius: float = 0.60 if enemy_3d.is_in_group("bosses") else 0.40
\t\tvar min_dist: float = 0.35 + enemy_radius + 0.06
\t\tif dist < min_dist and dist > 0.001:
\t\t\tvar dir: Vector3 = diff / dist
\t\t\tvar vel_towards: float = velocity.dot(dir)
\t\t\tif vel_towards > 0.0:
\t\t\t\tvelocity -= dir * vel_towards"""
    replacement_push = """func _prevent_enemy_pushing() -> void:
\t# Avoid sliding into or pushing monsters; halt clean on contact boundary (Option C X-only)
\tvar enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
\tfor enemy in enemies:
\t\tif not is_instance_valid(enemy) or enemy == self or not (enemy is Node3D):
\t\t\tcontinue
\t\tvar enemy_3d := enemy as Node3D
\t\tvar diff_x: float = enemy_3d.global_position.x - global_position.x
\t\tvar dist_x: float = absf(diff_x)
\t\tvar enemy_radius: float = 0.60 if enemy_3d.is_in_group("bosses") else 0.40
\t\tvar min_dist: float = 0.35 + enemy_radius + 0.06
\t\tif dist_x < min_dist and dist_x > 0.001:
\t\t\tvar dir_x: float = signf(diff_x)
\t\t\tif velocity.x * dir_x > 0.0:
\t\t\t\tvelocity.x = 0.0
\tvelocity.z = 0.0"""
    assert target_push in content, "target_push not found in player.gd"
    content = content.replace(target_push, replacement_push)

    # 7. In _physics_process before move_and_slide(): enforce Z = 0
    target_phys_end = """\t# Prevent pushing into monsters: firm stop upon body contact without bouncing
\t_prevent_enemy_pushing()
\tmove_and_slide()
\t_clamp_arena_bounds()
\t_update_character_animation(delta)"""
    replacement_phys_end = """\t# Option C: Enforce strict Z=0 before and after move_and_slide
\tvelocity.z = 0.0
\tglobal_position.z = 0.0
\t_prevent_enemy_pushing()
\tmove_and_slide()
\tvelocity.z = 0.0
\tglobal_position.z = 0.0
\t_clamp_arena_bounds()
\t_update_character_animation(delta)"""
    assert target_phys_end in content, "target_phys_end not found in player.gd"
    content = content.replace(target_phys_end, replacement_phys_end)

    path.write_text(content, encoding="utf-8")
    print("Pitched side_qv_player.gd successfully.")

def patch_enemy():
    path = Path(r"D:\JUNYPAPA_STUDIO\Projects\ProjectKnight\CLIENT\Game\scripts\side_quarter_view\side_qv_enemy.gd")
    content = path.read_text(encoding="utf-8")

    target_pursuit = """\tvar combat_standoff_distance := 1.25 # Standoff distance: clean stop without pushing
\tif dist > combat_standoff_distance:
\t\t# Pursue player in 3D isometric plane
\t\tvelocity.x = dir.x * move_speed
\t\tvelocity.z = dir.z * (move_speed * 0.7)
\t\t_prevent_player_pushing()
\telse:
\t\t# Firm stop in front of player (no pushing, no bouncing)
\t\tvelocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
\t\tvelocity.z = move_toward(velocity.z, 0.0, 35.0 * delta)
\t\tif current_cooldown <= 0.0:
\t\t\t_execute_attack()

\tmove_and_slide()"""

    replacement_pursuit = """\tvar combat_standoff_distance := 1.25 # Standoff distance: clean stop without pushing
\tvar diff_x := target_player.global_position.x - global_position.x
\tvar dist_x := absf(diff_x)
\tvar dir_x := signf(diff_x) if dist_x > 0.01 else -1.0
\tif dist_x > combat_standoff_distance:
\t\t# Option C: Pursue player purely along horizontal X on Z=0 plane
\t\tvelocity.x = dir_x * move_speed
\t\tvelocity.z = 0.0
\t\t_prevent_player_pushing()
\telse:
\t\t# Firm stop in front of player (no pushing, no bouncing)
\t\tvelocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
\t\tvelocity.z = 0.0
\t\tif current_cooldown <= 0.0:
\t\t\t_execute_attack()

\tvelocity.z = 0.0
\tglobal_position.z = 0.0
\tmove_and_slide()
\tvelocity.z = 0.0
\tglobal_position.z = 0.0"""
    assert target_pursuit in content, "target_pursuit not found in enemy.gd"
    content = content.replace(target_pursuit, replacement_pursuit)

    path.write_text(content, encoding="utf-8")
    print("Patched side_qv_enemy.gd successfully.")

def patch_boss():
    path = Path(r"D:\JUNYPAPA_STUDIO\Projects\ProjectKnight\CLIENT\Game\scripts\side_quarter_view\side_qv_boss.gd")
    content = path.read_text(encoding="utf-8")

    # In CHASE: purely on X
    target_chase = """\t\t\t\tvar spd := move_speed * (1.35 if current_phase == 2 else 1.0)
\t\t\t\tvar boss_combat_distance := 1.85 # Reach of heavy boss blade; halt to avoid pushing
\t\t\t\tif dist > boss_combat_distance:
\t\t\t\t\tvelocity.x = facing_dir_x * spd
\t\t\t\t\tvelocity.z = diff.normalized().z * (spd * 0.7)
\t\t\t\t\t_prevent_player_pushing()
\t\t\t\telse:
\t\t\t\t\tvelocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
\t\t\t\t\tvelocity.z = move_toward(velocity.z, 0.0, 35.0 * delta)"""

    replacement_chase = """\t\t\t\tvar spd := move_speed * (1.35 if current_phase == 2 else 1.0)
\t\t\t\tvar boss_combat_distance := 1.85 # Reach of heavy boss blade; halt to avoid pushing
\t\t\t\tvar dist_x: float = absf(diff.x)
\t\t\t\tif dist_x > boss_combat_distance:
\t\t\t\t\t# Option C: Chase strictly along horizontal X axis on Z=0
\t\t\t\t\tvelocity.x = facing_dir_x * spd
\t\t\t\t\tvelocity.z = 0.0
\t\t\t\t\t_prevent_player_pushing()
\t\t\t\telse:
\t\t\t\t\tvelocity.x = move_toward(velocity.x, 0.0, 35.0 * delta)
\t\t\t\t\tvelocity.z = 0.0"""
    assert target_chase in content, "target_chase not found in boss.gd"
    content = content.replace(target_chase, replacement_chase)

    # In _physics_process end: enforce Z=0
    target_phys_end = """\tmove_and_slide()
\t_update_boss_animation(delta)"""
    replacement_phys_end = """\tvelocity.z = 0.0
\tglobal_position.z = 0.0
\tmove_and_slide()
\tvelocity.z = 0.0
\tglobal_position.z = 0.0
\t_update_boss_animation(delta)"""
    assert target_phys_end in content, "target_phys_end not found in boss.gd"
    content = content.replace(target_phys_end, replacement_phys_end)

    path.write_text(content, encoding="utf-8")
    print("Patched side_qv_boss.gd successfully.")

def patch_stage_1():
    path = Path(r"D:\JUNYPAPA_STUDIO\Projects\ProjectKnight\CLIENT\Game\scripts\side_quarter_view\stages\side_qv_stage_1.gd")
    content = path.read_text(encoding="utf-8")

    # Wave 1 spawn Z=0
    target_spawns = """func _spawn_wave_1_enemies() -> void:
\t# Requirement 3: 웨이브 1: SideQVEnemy 2마리 소환 (X = 2.0, 4.0, Z = -1.0, 1.0)
\t_spawn_enemy(Vector3(2.0, 0.1, -1.0), "Minion_1")
\t_spawn_enemy(Vector3(4.0, 0.1, 1.0), "Minion_2")"""
    replacement_spawns = """func _spawn_wave_1_enemies() -> void:
\t# Option C: Minions spawn strictly on Z = 0.0 gameplay plane
\t_spawn_enemy(Vector3(2.0, 0.1, 0.0), "Minion_1")
\t_spawn_enemy(Vector3(4.0, 0.1, 0.0), "Minion_2")"""
    # Note: check if comments differ in encoding
    if target_spawns in content:
        content = content.replace(target_spawns, replacement_spawns)
    else:
        # Fallback to replace the spawn lines directly
        target_lines = """\t_spawn_enemy(Vector3(2.0, 0.1, -1.0), "Minion_1")\n\t_spawn_enemy(Vector3(4.0, 0.1, 1.0), "Minion_2")"""
        replacement_lines = """\t_spawn_enemy(Vector3(2.0, 0.1, 0.0), "Minion_1")\n\t_spawn_enemy(Vector3(4.0, 0.1, 0.0), "Minion_2")"""
        assert target_lines in content, "target_lines not found in stage_1.gd"
        content = content.replace(target_lines, replacement_lines)

    path.write_text(content, encoding="utf-8")
    print("Patched side_qv_stage_1.gd spawns successfully.")

if __name__ == "__main__":
    patch_player()
    patch_enemy()
    patch_boss()
    patch_stage_1()
    print("Checkpoint A patch completed.")
