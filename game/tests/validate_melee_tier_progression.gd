extends SceneTree

# 근접 포탑 Tier 1~4의 단일 공격, 범위 공격, 역방향 넉백과 조건부 처형을 검증한다.
const TowerScript := preload("res://scripts/tower.gd")
const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")


func _init() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	if not _validate_tier_one_single_target():
		return
	if not _validate_tier_two_area_hitscan():
		return
	if not _validate_tier_three_knockback():
		return
	if not _validate_tier_four_execution():
		return
	print("Melee tier progression validation passed.")
	quit(0)


func _validate_tier_one_single_target() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 1)
	var first := _create_monster(arena, 40.0, 100.0)
	var second := _create_monster(arena, 80.0, 100.0)
	tower._process(tower.attack_interval_sec)
	var damaged_count := int(first.hp < 100.0) + int(second.hp < 100.0)
	var passed := damaged_count == 1 and get_nodes_in_group("tower_hit_effects").size() == 1
	arena.free()
	if not passed:
		_fail("MELEE Tier 1 must keep the existing single-target hitscan")
	return passed


func _validate_tier_two_area_hitscan() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 2)
	var first := _create_monster(arena, 40.0, 100.0)
	var second := _create_monster(arena, 80.0, 100.0)
	tower._process(tower.attack_interval_sec)
	var passed := is_equal_approx(first.hp, 90.0) and is_equal_approx(second.hp, 90.0) \
		and get_nodes_in_group("tower_hit_effects").size() == 2
	arena.free()
	if not passed:
		_fail("MELEE Tier 2 must hitscan every enemy in horizontal range")
	return passed


func _validate_tier_three_knockback() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 3)
	var first := _create_monster(arena, 40.0, 100.0)
	var second := _create_monster(arena, 80.0, 100.0)
	var first_x := first.position.x
	var second_x := second.position.x
	tower._process(tower.attack_interval_sec)
	var passed := is_equal_approx(first.position.x, first_x + TowerScript.MELEE_KNOCKBACK_DISTANCE_PX) \
		and is_equal_approx(second.position.x, second_x + TowerScript.MELEE_KNOCKBACK_DISTANCE_PX)
	arena.free()
	if not passed:
		_fail("MELEE Tier 3 must knock every surviving target opposite its movement direction")
	return passed


func _validate_tier_four_execution() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 4)
	var executable := _create_monster(arena, 40.0, 25.0)
	var survivor := _create_monster(arena, 80.0, 35.0)
	var normally_killed := _create_monster(arena, 110.0, 5.0)
	tower._process(tower.attack_interval_sec)
	var passed := executable.move_state == PrototypeMonster.MoveState.DEAD \
		and survivor.move_state != PrototypeMonster.MoveState.DEAD \
		and is_equal_approx(survivor.hp, 25.0) \
		and normally_killed.move_state == PrototypeMonster.MoveState.DEAD \
		and get_nodes_in_group("melee_execution_effects").size() == 1
	arena.free()
	if not passed:
		_fail("MELEE Tier 4 must execute only surviving targets at or below 20% HP")
	return passed


func _create_arena() -> Node2D:
	var arena := Node2D.new()
	root.add_child(arena)
	return arena


func _create_tower(arena: Node2D, tower_tier: int) -> PrototypeTower:
	var tower := TowerScript.new() as PrototypeTower
	arena.add_child(tower)
	tower.position = Vector2(100.0, 0.0)
	tower.setup({
		"id": "turretMelee%d" % tower_tier,
		"display_name": "근접 포탑",
		"type": "MELEE",
		"next_turret_id": "-1",
		"tier": tower_tier,
		"damage": 10.0,
		"attack_interval_sec": 0.5,
		"range_px": 120.0,
		"cc_duration": 0.0,
		"cc_value": 0.0,
		"color_hex": "ff9f68",
	}, 0, false)
	return tower


func _create_monster(arena: Node2D, x_position: float, current_hp: float) -> PrototypeMonster:
	var monster := MONSTER_SCENE.instantiate() as PrototypeMonster
	arena.add_child(monster)
	var path := PackedVector2Array([
		Vector2(320.0, 0.0), Vector2(300.0, 0.0), Vector2(280.0, 0.0),
		Vector2(220.0, 0.0), Vector2(-220.0, 0.0),
	])
	monster.setup({
		"id": "normal1",
		"display_name": "일반 몬스터",
		"type": "NORMAL",
		"max_hp": 100.0,
		"move_speed_px_sec": 100.0,
		"reward_gold": 1,
	}, path)
	monster.path_index = 3
	monster.move_state = PrototypeMonster.MoveState.WALKING
	monster.scale = Vector2.ONE * PrototypeMonster.MONSTER_VISUAL_SCALE
	monster.position = Vector2(x_position, monster.path_points[3].y)
	monster.hp = current_hp
	return monster


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
