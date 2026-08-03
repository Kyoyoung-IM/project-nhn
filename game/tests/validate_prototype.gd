extends SceneTree

const DatabaseScript := preload("res://scripts/prototype_database.gd")
const EXPECTED_TURRET_TYPES := ["MELEE", "DOT", "STUN", "SLOW", "RANGED"]
const EXPECTED_MONSTER_TYPES := ["NORMAL", "SPEED", "TANK", "BOSS"]


func _init() -> void:
	var database := DatabaseScript.new() as PrototypeDatabase
	if database == null or not database.load_all():
		_fail("prototype database validation failed")
		return
	if database.define_int("failAllowedMonster", -1) != 0:
		_fail("failAllowedMonster must remain present as the unused placeholder field")
		return
	if database.define_float("prepareTimeSec", -1.0) < 0.0:
		_fail("prepareTimeSec must not be negative")
		return
	if database.define_int("rerollPlusCost", -1) < 0:
		_fail("rerollPlusCost must not be negative")
		return
	if database.get_wave_monster_ids("wave1").is_empty():
		_fail("wave1 must contain SpawnTable rows")
		return
	for turret_type in EXPECTED_TURRET_TYPES:
		var turret_id := "TURRET_%s_T1" % turret_type
		var turret := database.get_turret_data(turret_id)
		if turret.is_empty() or float(turret.get("max_hp", 0.0)) <= 0.0:
			_fail("missing prototype turret object: %s" % turret_id)
			return
	for monster_type in EXPECTED_MONSTER_TYPES:
		var monster_id := "MONSTER_%s_01" % monster_type
		var monster := database.get_monster_data(monster_id)
		if monster.is_empty() or float(monster.get("attack_damage", 0.0)) <= 0.0:
			_fail("missing prototype monster object: %s" % monster_id)
			return

	print("Prototype data validation passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
