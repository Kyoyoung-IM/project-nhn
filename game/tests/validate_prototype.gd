extends SceneTree

const REQUIRED_SECTIONS := ["meta", "monster", "tower", "economy", "wave"]


func _init() -> void:
	var file := FileAccess.open("res://data/prototype_combat.json", FileAccess.READ)
	if file == null:
		_fail("prototype_combat.json could not be opened")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("prototype_combat.json must contain an object")
		return

	var config := parsed as Dictionary
	for section in REQUIRED_SECTIONS:
		if not config.has(section) or typeof(config[section]) != TYPE_DICTIONARY:
			_fail("missing dictionary section: %s" % section)
			return

	if config["meta"].get("status") != "PLACEHOLDER":
		_fail("prototype combat values must be marked PLACEHOLDER")
		return
	if float(config["tower"].get("attack_interval_sec", 0.0)) <= 0.0:
		_fail("tower attack_interval_sec must be positive")
		return
	if float(config["tower"].get("max_hp", 0.0)) <= 0.0:
		_fail("tower max_hp must be positive")
		return
	if float(config["monster"].get("attack_damage", 0.0)) <= 0.0:
		_fail("monster attack_damage must be positive")
		return
	if int(config["economy"].get("shop_card_count", 0)) != 5:
		_fail("prototype shop must expose five cards")
		return
	if int(config["economy"].get("reroll_cost", -1)) < 0:
		_fail("reroll_cost must not be negative")
		return
	if int(config["wave"].get("monster_count", 0)) <= 0:
		_fail("wave monster_count must be positive")
		return

	print("Prototype data validation passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
