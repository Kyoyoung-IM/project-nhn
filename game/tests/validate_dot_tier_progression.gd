extends SceneTree

# 지속 포탑 Tier 1~4의 화염구, 인접 전이, 100스택과 사망 폭발을 검증한다.
const TowerScript := preload("res://scripts/tower.gd")
const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")


func _init() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	if not _validate_tier_one_fireball():
		return
	if not _validate_tier_two_nonstacking_spread():
		return
	if not _validate_tier_three_hundred_stacks_and_tint():
		return
	if not _validate_tier_four_death_explosion():
		return
	print("DOT tier progression validation passed.")
	quit(0)


func _validate_tier_one_fireball() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 1)
	var target := _create_monster(arena, 180.0)
	tower._process(tower.attack_interval_sec)
	var fireballs := get_nodes_in_group("dot_fireball_projectiles")
	var fireball = fireballs[0] if not fireballs.is_empty() else null
	var waited_for_impact := fireball != null and is_equal_approx(target.hp, 100.0)
	if fireball != null:
		fireball._process(1.0)
	var passed: bool = waited_for_impact and target.hp < 100.0 and target.dot_stack_count == 1 \
		and get_nodes_in_group("tower_flamethrowers").is_empty()
	arena.free()
	if not passed:
		_fail("DOT Tier 1 must use the generated fireball and keep one DOT stack")
	return passed


func _validate_tier_two_nonstacking_spread() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 2)
	var primary := _create_monster(arena, 180.0)
	var adjacent := _create_monster(arena, 300.0)
	var distant := _create_monster(arena, 520.0)
	tower._process(tower.attack_interval_sec)
	var flamethrowers := get_nodes_in_group("tower_flamethrowers")
	var flamethrower = flamethrowers[0] if not flamethrowers.is_empty() else null
	if flamethrower != null:
		flamethrower._process(0.21)
	primary.receive_turret_hit(0.0, "DOT", 10.0, 0.5, 2)
	var passed := flamethrower != null and primary.dot_stack_count == 1 \
		and adjacent.dot_stack_count == 1 and distant.dot_stack_count == 0
	arena.free()
	if not passed:
		_fail("DOT Tier 2 must spread one non-stacking DOT to adjacent enemies")
	return passed


func _validate_tier_three_hundred_stacks_and_tint() -> bool:
	var arena := _create_arena()
	var target := _create_monster(arena, 180.0)
	for application_index in 105:
		target.receive_turret_hit(0.0, "DOT", 10.0, 0.5, 3)
	var passed := target.dot_stack_count == PrototypeMonster.DOT_MAX_STACK_COUNT \
		and is_equal_approx(target.dot_tick_damage, target.dot_damage_per_stack * 100.0) \
		and target.body_sprite.modulate.g < 0.3 and target.hit_sprite.modulate.g < 0.3
	arena.free()
	if not passed:
		_fail("DOT Tier 3 must cap at 100 stacks and tint the monster red by stack count")
	return passed


func _validate_tier_four_death_explosion() -> bool:
	var arena := _create_arena()
	var primary := _create_monster(arena, 180.0)
	var adjacent := _create_monster(arena, 300.0)
	var distant := _create_monster(arena, 520.0)
	primary.receive_turret_hit(20.0, "DOT", 10.0, 0.5, 4)
	primary.take_damage(primary.hp)
	var effects := get_nodes_in_group("dot_death_explosions")
	var effect = effects[0] if not effects.is_empty() else null
	var passed: bool = primary.move_state == PrototypeMonster.MoveState.DEAD \
		and is_equal_approx(adjacent.hp, 80.0) and is_equal_approx(distant.hp, 100.0) \
		and effect != null and effect.explosion_sprite.texture != null
	arena.free()
	if not passed:
		_fail("DOT Tier 4 death must damage adjacent enemies and show the generated explosion")
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
		"id": "turretDot%d" % tower_tier,
		"display_name": "지속 포탑",
		"type": "DOT",
		"next_turret_id": "-1",
		"tier": tower_tier,
		"damage": 20.0,
		"attack_interval_sec": 0.5,
		"range_px": 300.0,
		"cc_duration": 10.0,
		"cc_value": 0.5,
		"color_hex": "c47cff",
	}, 0, false)
	return tower


func _create_monster(arena: Node2D, x_position: float) -> PrototypeMonster:
	var monster := MONSTER_SCENE.instantiate() as PrototypeMonster
	arena.add_child(monster)
	var path := PackedVector2Array([
		Vector2(760.0, -500.0), Vector2(740.0, -500.0), Vector2(720.0, -500.0),
		Vector2(700.0, 0.0), Vector2(-300.0, 0.0),
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
	return monster


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
