extends SceneTree

# 원거리 포탑 Tier 1~4의 단발, 3연발, 전방 관통 레이저와 이중 포구를 검증한다.
const TowerScript := preload("res://scripts/tower.gd")
const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")


func _init() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	if not _validate_tier_one_single_projectile():
		return
	if not _validate_tier_two_three_shot_burst():
		return
	if not _validate_tier_three_front_laser():
		return
	if not _validate_tier_four_dual_laser():
		return
	print("Ranged tier progression validation passed.")
	quit(0)


func _validate_tier_one_single_projectile() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 1)
	_create_monster(arena, 180.0, 0)
	tower._process(tower.attack_interval_sec)
	var passed := get_nodes_in_group("tower_projectiles").size() == 1 \
		and get_nodes_in_group("ranged_laser_effects").is_empty()
	arena.free()
	if not passed:
		_fail("RANGED Tier 1 must keep one existing projectile per attack")
	return passed


func _validate_tier_two_three_shot_burst() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 2)
	_create_monster(arena, 180.0, 0)
	tower._process(tower.attack_interval_sec)
	tower._process(TowerScript.RANGED_BURST_SHOT_INTERVAL_SEC)
	tower._process(TowerScript.RANGED_BURST_SHOT_INTERVAL_SEC)
	var passed := get_nodes_in_group("tower_projectiles").size() == 3 \
		and tower.ranged_burst_shots_remaining == 0
	arena.free()
	if not passed:
		_fail("RANGED Tier 2 must fire three existing projectiles in one burst")
	return passed


func _validate_tier_three_front_laser() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 3)
	var near_front := _create_monster(arena, 180.0, 0)
	var far_front := _create_monster(arena, 500.0, 0)
	var behind := _create_monster(arena, 50.0, 0)
	var other_floor := _create_monster(arena, 400.0, 1)
	tower._process(tower.attack_interval_sec)
	var effects := get_nodes_in_group("ranged_laser_effects")
	var effect = effects[0] if not effects.is_empty() else null
	var passed: bool = is_equal_approx(near_front.hp, 90.0) \
		and is_equal_approx(far_front.hp, 90.0) \
		and is_equal_approx(behind.hp, 100.0) \
		and is_equal_approx(other_floor.hp, 100.0) \
		and get_nodes_in_group("tower_projectiles").is_empty() \
		and effect != null and effect.beam_count == 1
	arena.free()
	if not passed:
		_fail("RANGED Tier 3 must hit every same-floor enemy in front with one laser")
	return passed


func _validate_tier_four_dual_laser() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 4)
	var first := _create_monster(arena, 180.0, 0)
	var second := _create_monster(arena, 500.0, 0)
	var behind := _create_monster(arena, 50.0, 0)
	tower._process(tower.attack_interval_sec)
	var effects := get_nodes_in_group("ranged_laser_effects")
	var effect = effects[0] if not effects.is_empty() else null
	var passed: bool = is_equal_approx(first.hp, 80.0) and is_equal_approx(second.hp, 80.0) \
		and is_equal_approx(behind.hp, 100.0) \
		and effect != null and effect.beam_count == 2 \
		and not effect.core_lines[0].points[0].is_equal_approx(effect.core_lines[1].points[0])
	arena.free()
	if not passed:
		_fail("RANGED Tier 4 must deal two hits from distinct main and auxiliary muzzles")
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
		"id": "turretRanged%d" % tower_tier,
		"display_name": "원거리 포탑",
		"type": "RANGED",
		"next_turret_id": "-1",
		"tier": tower_tier,
		"damage": 10.0,
		"attack_interval_sec": 0.5,
		"range_px": 120.0,
		"cc_duration": 0.0,
		"cc_value": 0.0,
		"color_hex": "ffe17a",
	}, 0, false)
	return tower


func _create_monster(arena: Node2D, x_position: float, combat_floor: int) -> PrototypeMonster:
	var monster := MONSTER_SCENE.instantiate() as PrototypeMonster
	arena.add_child(monster)
	var path := PackedVector2Array([
		Vector2(760.0, -500.0), Vector2(740.0, -500.0), Vector2(720.0, -500.0),
		Vector2(700.0, 0.0), Vector2(-300.0, 0.0),
		Vector2(700.0, 500.0), Vector2(-300.0, 500.0),
	])
	monster.setup({
		"id": "normal1",
		"display_name": "일반 몬스터",
		"type": "NORMAL",
		"max_hp": 100.0,
		"move_speed_px_sec": 100.0,
		"reward_gold": 1,
	}, path)
	monster.path_index = 3 if combat_floor == 0 else 5
	monster.move_state = PrototypeMonster.MoveState.WALKING
	monster.scale = Vector2.ONE * PrototypeMonster.MONSTER_VISUAL_SCALE
	monster.position = Vector2(x_position, monster.path_points[monster.path_index].y)
	return monster


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
