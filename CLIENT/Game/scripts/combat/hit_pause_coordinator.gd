extends Node
class_name HitPauseCoordinator
## ProjectKnight V3-026: Scoped HitPause Coordinator
## Manages localized hitstop per actor without freezing the global Engine.time_scale.

static var _instance: HitPauseCoordinator = null

# Map of Node -> remaining freeze time in seconds
var _paused_actors: Dictionary = {}


static func get_instance() -> HitPauseCoordinator:
	if _instance == null or not is_instance_valid(_instance):
		_instance = HitPauseCoordinator.new()
		_instance.name = "HitPauseCoordinator"
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			tree.root.call_deferred("add_child", _instance)
	return _instance


func _init() -> void:
	_instance = self


func _enter_tree() -> void:
	if _instance == null:
		_instance = self


func _physics_process(delta: float) -> void:
	if _paused_actors.is_empty():
		return

	var finished_nodes: Array = []
	for node in _paused_actors.keys():
		if not is_instance_valid(node):
			finished_nodes.append(node)
			continue

		var rem: float = _paused_actors[node] - delta
		if rem <= 0.0:
			finished_nodes.append(node)
			_unpause_actor(node)
		else:
			_paused_actors[node] = rem


	for node in finished_nodes:
		_paused_actors.erase(node)


## Apply localized hitstop to attacker and victim
func apply_hit_pause(attacker: Node, victim: Node, attacker_sec: float = 0.040, victim_sec: float = 0.065) -> void:
	if attacker != null and is_instance_valid(attacker):
		_paused_actors[attacker] = maxf(_paused_actors.get(attacker, 0.0), attacker_sec)
		_pause_actor(attacker, attacker_sec)

	if victim != null and is_instance_valid(victim):
		_paused_actors[victim] = maxf(_paused_actors.get(victim, 0.0), victim_sec)
		_pause_actor(victim, victim_sec)


func is_actor_paused(actor: Node) -> bool:
	return _paused_actors.has(actor)


func _pause_actor(actor: Node, duration: float = 0.05) -> void:
	if "is_hit_paused" in actor:
		actor.is_hit_paused = true
	if "hit_pause_timer" in actor:
		actor.hit_pause_timer = maxf(actor.hit_pause_timer, duration)
	# Minor kinetic pause on velocity
	if actor is CharacterBody3D:
		var cb := actor as CharacterBody3D
		if not actor.has_meta("pre_pause_vel"):
			actor.set_meta("pre_pause_vel", cb.velocity)


func _unpause_actor(actor: Node) -> void:
	if not is_instance_valid(actor):
		return
	if "is_hit_paused" in actor:
		actor.is_hit_paused = false
	if "hit_pause_timer" in actor:
		actor.hit_pause_timer = 0.0
	if actor.has_meta("pre_pause_vel"):
		actor.remove_meta("pre_pause_vel")
