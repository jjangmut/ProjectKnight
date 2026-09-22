class_name StageLoader
extends RefCounted
## StageLoader: Parses JSON stage & monster balance sheets and instantiates entities dynamically.

const MONSTERS_DATA_PATH := "res://data/monsters.json"
const PLAYER_COMBAT_DATA_PATH := "res://data/player_combat.json"
const STAGES_DATA_DIR := "res://data/stages/"

static var _cached_monsters: Dictionary = {}
static var _cached_player_combat: Dictionary = {}


## Loads and parses a JSON file from the project.
static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("StageLoader: JSON file not found at %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("StageLoader: Failed to open %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("StageLoader: JSON parse error in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	var data = json.get_data()
	if not data is Dictionary:
		push_error("StageLoader: Expected Dictionary root in %s" % path)
		return {}
	return data as Dictionary


## Returns the full monsters database.
static func get_monsters_data() -> Dictionary:
	if _cached_monsters.is_empty():
		var raw := load_json(MONSTERS_DATA_PATH)
		if raw.has("monsters") and raw["monsters"] is Dictionary:
			_cached_monsters = raw["monsters"]
	return _cached_monsters


## Returns a single monster specification by id.
static func get_monster_spec(monster_id: String) -> Dictionary:
	var db := get_monsters_data()
	if db.has(monster_id) and db[monster_id] is Dictionary:
		return db[monster_id]
	push_warning("StageLoader: Monster ID '%s' not found in database, using fallback" % monster_id)
	return {}


## Returns player combat data.
static func get_player_combat_data() -> Dictionary:
	if _cached_player_combat.is_empty():
		_cached_player_combat = load_json(PLAYER_COMBAT_DATA_PATH)
	return _cached_player_combat


## Returns stage specification by stage number.
static func get_stage_data(stage_number: int) -> Dictionary:
	var filename := "stage_%02d.json" % stage_number
	var path := STAGES_DATA_DIR + filename
	return load_json(path)


## Instantiates and configures a monster based on monster_id from the database.
static func instantiate_monster(monster_id: String) -> CharacterBody2D:
	var spec := get_monster_spec(monster_id)
	var scene_path: String = spec.get("scene_path", "res://scenes/enemy/TestEnemy.tscn")
	var scene := load(scene_path) as PackedScene
	if not scene:
		push_error("StageLoader: Failed to load scene %s for monster %s" % [scene_path, monster_id])
		return null
	var actor := scene.instantiate() as CharacterBody2D
	if not actor:
		push_error("StageLoader: Instantiated node is not CharacterBody2D")
		return null

	# Inject data-driven properties
	if spec.has("max_hp") and "max_hp" in actor:
		actor.max_hp = int(spec["max_hp"])
		actor.current_hp = actor.max_hp
	if spec.has("move_speed") and "move_speed" in actor:
		actor.move_speed = float(spec["move_speed"])
	if spec.has("detection_range") and "detection_range" in actor:
		actor.detection_range = float(spec["detection_range"])
	if spec.has("attack_range") and "attack_range" in actor:
		actor.attack_range = float(spec["attack_range"])
	if spec.has("attack_windup") and "attack_windup" in actor:
		actor.attack_windup = float(spec["attack_windup"])
	if spec.has("attack_active") and "attack_active" in actor:
		actor.attack_active = float(spec["attack_active"])
	if spec.has("attack_cooldown") and "attack_cooldown" in actor:
		actor.attack_cooldown = float(spec["attack_cooldown"])
	if spec.has("is_blockable"):
		actor.set_meta("data_blockable", bool(spec["is_blockable"]))
	if spec.has("warning_vfx"):
		actor.set_meta("warning_vfx", str(spec["warning_vfx"]))
	if spec.has("telegraph_type"):
		actor.set_meta("telegraph_type", str(spec["telegraph_type"]))

	actor.set_meta("monster_id", monster_id)
	actor.add_to_group("enemy")
	return actor
