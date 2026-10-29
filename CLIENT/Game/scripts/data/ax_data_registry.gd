class_name AXDataRegistry
extends RefCounted
## AXDataRegistry:
## Project Knight 마스터 기획 데이터(AX Data)를 로드·검증·검색·바인딩하는 중앙 데이터 레지스트리.

const AX_DATA_JSON_PATH := "res://data/ax_data/project_knight_ax_data.json"

static var _cached_data: Dictionary = {}


static func load_ax_data(force_reload: bool = false) -> Dictionary:
	if not force_reload and not _cached_data.is_empty():
		return _cached_data

	if not FileAccess.file_exists(AX_DATA_JSON_PATH):
		push_error("[AXDataRegistry] AX Data file missing at: %s" % AX_DATA_JSON_PATH)
		return {}

	var file := FileAccess.open(AX_DATA_JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("[AXDataRegistry] Failed to open AX Data file: %s" % AX_DATA_JSON_PATH)
		return {}

	var raw_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(raw_text)
	if err != OK:
		push_error("[AXDataRegistry] JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {}

	if not (json.data is Dictionary):
		push_error("[AXDataRegistry] Root JSON element must be a Dictionary.")
		return {}

	_cached_data = json.data as Dictionary
	return _cached_data


static func get_meta_info() -> Dictionary:
	return load_ax_data().get("meta", {})


static func get_player_data() -> Dictionary:
	return load_ax_data().get("player", {})


static func get_combat_rules() -> Dictionary:
	return load_ax_data().get("combat_rules", {})


static func get_stages() -> Array:
	return load_ax_data().get("stages", [])


static func get_stage_by_num(stage_num: int) -> Dictionary:
	for s in get_stages():
		if int(s.get("stage_num", 0)) == stage_num:
			return s
	return {}


static func get_enemies() -> Array:
	return load_ax_data().get("enemies", [])


static func get_enemy_by_id(enemy_id: String) -> Dictionary:
	for e in get_enemies():
		if str(e.get("id", "")) == enemy_id:
			return e
	return {}


static func get_bosses() -> Array:
	return load_ax_data().get("bosses", [])


static func get_boss_by_id(boss_id: String) -> Dictionary:
	for b in get_bosses():
		if str(b.get("id", "")) == boss_id:
			return b
	return {}


static func get_boss_by_stage(stage_num: int) -> Dictionary:
	for b in get_bosses():
		if int(b.get("stage_num", 0)) == stage_num:
			return b
	return {}


static func get_sanctuary_data() -> Dictionary:
	return load_ax_data().get("sanctuary_upgrades", {})


static func get_shop_items() -> Array:
	return get_sanctuary_data().get("shop_items", [])


static func get_stage_relics() -> Array:
	return get_sanctuary_data().get("stage_relics", [])


static func get_summary_metrics() -> Dictionary:
	var stages := get_stages()
	var enemies := get_enemies()
	var bosses := get_bosses()
	var total_patterns := 0
	for b in bosses:
		var pats: Array = b.get("patterns", [])
		total_patterns += pats.size()
	var player_anims: Array = get_player_data().get("animations", [])
	var shop_items := get_shop_items()
	var relics := get_stage_relics()

	return {
		"ax_schema_version": str(get_meta_info().get("ax_schema_version", "2.0.0")),
		"stage_count": stages.size(),
		"enemy_type_count": enemies.size(),
		"boss_count": bosses.size(),
		"boss_pattern_count": total_patterns,
		"player_anim_count": player_anims.size(),
		"shop_item_count": shop_items.size(),
		"relic_count": relics.size()
	}


static func search_entries(keyword: String) -> Array[Dictionary]:
	var q := keyword.strip_edges().to_lower()
	var results: Array[Dictionary] = []
	if q.is_empty():
		return results

	# Search player
	var p := get_player_data()
	var p_text := JSON.stringify(p).to_lower()
	if p_text.contains(q):
		results.append({
			"category": "플레이어 (Player)",
			"id": str(p.get("id", "player_paladin")),
			"title": "%s (%s)" % [str(p.get("name_ko", "")), str(p.get("name_en", ""))],
			"summary": "HP %d · 이동속도 %.1f · 3단 성검 콤보(피해 %d) · 저스트 패링 %.2fs" % [
				int(p.get("base_stats", {}).get("max_hp", 8)),
				float(p.get("base_stats", {}).get("move_speed_x", 7.5)),
				int(p.get("combat", {}).get("base_attack_damage", 2)),
				float(p.get("defense_parry", {}).get("just_parry_window", 0.14))
			]
		})

	# Search stages
	for s in get_stages():
		if JSON.stringify(s).to_lower().contains(q):
			results.append({
				"category": "스테이지 (Stage %d)" % int(s.get("stage_num", 0)),
				"id": str(s.get("id", "")),
				"title": "%s — %s" % [str(s.get("name_ko", "")), str(s.get("theme", ""))],
				"summary": "아레나 %sm×%sm · 보스: %s · 웨이브 클리어 회복 +%d HP" % [
					str(s.get("arena_size_m", [38, 12])[0]),
					str(s.get("arena_size_m", [38, 12])[1]),
					str(s.get("boss_name_ko", "")),
					int(s.get("wave_clear_heal", 2))
				]
			})

	# Search enemies
	for e in get_enemies():
		if JSON.stringify(e).to_lower().contains(q):
			results.append({
				"category": "일반/엘리트 몬스터 (Stage %d)" % int(e.get("stage_num", 0)),
				"id": str(e.get("id", "")),
				"title": "%s (%s)" % [str(e.get("name_ko", "")), str(e.get("role", ""))],
				"summary": "HP %d · 속도 %.1f · 공격력 %d · 특징: %s" % [
					int(e.get("hp", 4)),
					float(e.get("move_speed", 3.5)),
					int(e.get("attack_damage", 1)),
					str(e.get("special_mechanic", ""))
				]
			})

	# Search bosses & patterns
	for b in get_bosses():
		if JSON.stringify(b).to_lower().contains(q):
			var pat_names := PackedStringArray()
			for pat in b.get("patterns", []):
				pat_names.append(str(pat.get("name_ko", "")))
			results.append({
				"category": "보스 (Stage %d Boss)" % int(b.get("stage_num", 0)),
				"id": str(b.get("id", "")),
				"title": "%s — %s" % [str(b.get("name_ko", "")), str(b.get("title_ko", ""))],
				"summary": "HP %d · 속도 %.1f(2페이즈 %.1f) · 패턴: %s" % [
					int(b.get("hp", 24)),
					float(b.get("move_speed_p1", 3.8)),
					float(b.get("move_speed_p2", 4.8)),
					", ".join(pat_names)
				]
			})

	# Search shop & relics
	for item in get_shop_items():
		if JSON.stringify(item).to_lower().contains(q):
			results.append({
				"category": "성소 강화 상점 (Sanctuary Shop)",
				"id": str(item.get("id", "")),
				"title": str(item.get("name_ko", "")),
				"summary": "비용 %d 파편 · 최대 %d단계 · %s" % [
					int(item.get("cost_shards", 0)),
					int(item.get("max_level", 1)),
					str(item.get("effect_desc", ""))
				]
			})

	for rel in get_stage_relics():
		if JSON.stringify(rel).to_lower().contains(q):
			results.append({
				"category": "보스 유물 (Stage %d Relic)" % int(rel.get("stage_num", 0)),
				"id": str(rel.get("id", "")),
				"title": "[%s] %s" % [str(rel.get("rarity", "")), str(rel.get("name_ko", ""))],
				"summary": "%s — %s" % [str(rel.get("title_ko", "")), str(rel.get("effect_desc", ""))]
			})

	return results


static func validate_schema() -> Dictionary:
	var data := load_ax_data(true)
	var errors: Array[String] = []

	if data.is_empty():
		errors.append("Root AX Data dictionary is empty.")
		return { "valid": false, "errors": errors }

	for req_key in ["meta", "player", "combat_rules", "stages", "enemies", "bosses", "sanctuary_upgrades"]:
		if not data.has(req_key):
			errors.append("Missing required top-level key: %s" % req_key)

	if get_stages().size() != 5:
		errors.append("Expected 5 stages, found %d" % get_stages().size())
	if get_enemies().size() != 5:
		errors.append("Expected 5 enemy archetypes, found %d" % get_enemies().size())
	if get_bosses().size() != 5:
		errors.append("Expected 5 bosses, found %d" % get_bosses().size())

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"summary": get_summary_metrics()
	}
