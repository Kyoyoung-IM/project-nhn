extends SceneTree

# Godot 장면을 띄우지 않고 데이터 테이블만 검증하는 헤드리스 테스트다.
# 실패 시 즉시 종료 코드 1을 반환해 로컬/CI 검증에서 오류를 감지한다.

# 실제 게임과 동일한 로더를 사용해야 테스트와 런타임 검증이 어긋나지 않는다.
const DatabaseScript := preload("res://scripts/prototype_database.gd")

# PDF 명세와 AGENTS에 정의된 필수 오브젝트 유형 목록이다.
const EXPECTED_TURRET_TYPES := ["MELEE", "DOT", "STUN", "SLOW", "RANGED"]
const EXPECTED_MONSTER_TYPES := ["NORMAL", "SPEED", "TANK", "BOSS"]


# 모든 테이블의 구문·참조를 검사하고 필수 프로토타입 오브젝트를 조회한다.
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


# 오류 메시지를 Godot 로그에 남기고 테스트 프로세스를 실패로 종료한다.
func _fail(message: String) -> void:
	push_error(message)
	quit(1)
