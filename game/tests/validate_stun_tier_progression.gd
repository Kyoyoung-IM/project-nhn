extends SceneTree

# 기절 포탑 Tier 1~4의 단일·범위·라인 판정, 확률 경계와 전용 연출을 검증한다.
const TowerScript := preload("res://scripts/tower.gd")
const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const BLUE_TEXTURE := preload("res://assets/combat_vfx/stun_lane_lightning_blue_v1.png")
const PURPLE_TEXTURE := preload("res://assets/combat_vfx/stun_lane_lightning_purple_v1.png")


func _init() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	if not _validate_tier_one_single_target_and_white_cloud():
		return
	if not _validate_tier_two_area_stun_and_original_cloud():
		return
	if not _validate_tier_three_lane_attack_and_chance():
		return
	if not _validate_tier_four_lane_attack_and_chance():
		return
	print("Stun tier progression validation passed.")
	quit(0)


func _validate_tier_one_single_target_and_white_cloud() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 1)
	var first := _create_monster(arena, 40.0, 0)
	var second := _create_monster(arena, 80.0, 0)
	_fire_once(tower)
	var effects := get_nodes_in_group("tower_hit_effects")
	var effect := effects[0] as PrototypeTowerHitEffect if effects.size() == 1 else null
	var passed := int(first.hp < 100.0) + int(second.hp < 100.0) == 1 \
		and effect != null and effect.stun_cloud_sprite.material is ShaderMaterial \
		and tower.get_node_or_null("StunChargeSprite") == null
	arena.free()
	if not passed:
		_fail("STUN Tier 1 must keep one target, use a white-cloud material, and omit the body charge VFX")
	return passed


func _validate_tier_two_area_stun_and_original_cloud() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 2)
	var first := _create_monster(arena, 40.0, 0)
	var second := _create_monster(arena, 80.0, 0)
	var outside := _create_monster(arena, 260.0, 0)
	_fire_once(tower)
	var effects := get_nodes_in_group("tower_hit_effects")
	var clouds_keep_color := effects.size() == 2
	for node in effects:
		var effect := node as PrototypeTowerHitEffect
		clouds_keep_color = clouds_keep_color and effect != null and effect.stun_cloud_sprite.material == null
	var passed := is_equal_approx(first.hp, 90.0) and is_equal_approx(second.hp, 90.0) \
		and first.stun_remaining_sec > 0.0 and second.stun_remaining_sec > 0.0 \
		and is_equal_approx(outside.hp, 100.0) and clouds_keep_color
	arena.free()
	if not passed:
		_fail("STUN Tier 2 must stun every in-range enemy with the original cloud color")
	return passed


func _validate_tier_three_lane_attack_and_chance() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 3)
	var near_target := _create_monster(arena, 40.0, 0)
	var far_target := _create_monster(arena, 1200.0, 0)
	var other_floor := _create_monster(arena, 40.0, 1)
	_fire_once(tower)
	var lane_effect := _single_lane_effect()
	var passed := is_equal_approx(near_target.hp, 90.0) and is_equal_approx(far_target.hp, 90.0) \
		and is_equal_approx(other_floor.hp, 100.0) and lane_effect != null \
		and lane_effect.bolt_sprites.size() == lane_effect.BOLT_COUNT \
		and lane_effect.bolt_sprites[0].texture == BLUE_TEXTURE \
		and _lane_bolts_cover_randomized_segments(lane_effect) \
		and _lane_bolts_touch_ground(lane_effect) \
		and is_equal_approx(TowerScript.stun_chance_for_tier(3), 0.20) \
		and TowerScript.stun_roll_succeeds(0.20, 0.1999) \
		and not TowerScript.stun_roll_succeeds(0.20, 0.20)
	arena.free()
	if not passed:
		_fail("STUN Tier 3 must hit the whole floor and use an independent 20% blue-lightning roll")
	return passed


func _validate_tier_four_lane_attack_and_chance() -> bool:
	var arena := _create_arena()
	var tower := _create_tower(arena, 4)
	var near_target := _create_monster(arena, 40.0, 0)
	var far_target := _create_monster(arena, 1200.0, 0)
	_fire_once(tower)
	var lane_effect := _single_lane_effect()
	var passed := is_equal_approx(near_target.hp, 90.0) and is_equal_approx(far_target.hp, 90.0) \
		and lane_effect != null and lane_effect.bolt_sprites[0].texture == PURPLE_TEXTURE \
		and is_equal_approx(TowerScript.stun_chance_for_tier(4), 0.50) \
		and TowerScript.stun_roll_succeeds(0.50, 0.4999) \
		and not TowerScript.stun_roll_succeeds(0.50, 0.50)
	arena.free()
	if not passed:
		_fail("STUN Tier 4 must hit the whole floor and use an independent 50% purple-lightning roll")
	return passed


func _fire_once(tower: PrototypeTower) -> void:
	tower._process(tower.attack_interval_sec)
	tower._process(TowerScript.STUN_CHARGE_DURATION_SEC)


func _single_lane_effect() -> PrototypeStunLaneLightningEffect:
	var effects := get_nodes_in_group("stun_lane_lightning_effects")
	return effects[0] as PrototypeStunLaneLightningEffect if effects.size() == 1 else null


func _lane_bolts_cover_randomized_segments(effect: PrototypeStunLaneLightningEffect) -> bool:
	var seeded_positions := effect._randomized_bolt_x_positions(13579)
	if seeded_positions != effect._randomized_bolt_x_positions(13579) \
			or seeded_positions == effect._randomized_bolt_x_positions(24680):
		return false
	var positions := PackedFloat32Array()
	for bolt in effect.bolt_sprites:
		positions.append(bolt.position.x)
	positions.sort()
	var usable_left := effect.LANE_LEFT_X + effect.BOLT_DRAW_SIZE.x * 0.5
	var usable_right := effect.LANE_RIGHT_X - effect.BOLT_DRAW_SIZE.x * 0.5
	var segment_width := (usable_right - usable_left) / float(effect.BOLT_COUNT)
	for segment_index in effect.BOLT_COUNT:
		var segment_start := usable_left + segment_width * float(segment_index)
		var inset := segment_width * effect.BOLT_SEGMENT_INSET_RATIO
		if positions[segment_index] < segment_start + inset \
				or positions[segment_index] > segment_start + segment_width - inset:
			return false
	return true


func _lane_bolts_touch_ground(effect: PrototypeStunLaneLightningEffect) -> bool:
	for bolt in effect.bolt_sprites:
		var visible_bottom_from_center := effect.bolt_visible_bounds.end.y - bolt.texture.get_height() * 0.5
		var visible_bottom_y := bolt.position.y + visible_bottom_from_center * bolt.scale.y
		if not is_equal_approx(visible_bottom_y, effect.lane_ground_y):
			return false
	return true


func _create_arena() -> Node2D:
	var arena := Node2D.new()
	root.add_child(arena)
	return arena


func _create_tower(arena: Node2D, tower_tier: int) -> PrototypeTower:
	var tower := TowerScript.new() as PrototypeTower
	arena.add_child(tower)
	tower.position = Vector2(100.0, 0.0)
	tower.setup({
		"id": "turretStun%d" % tower_tier,
		"display_name": "기절 포탑",
		"type": "STUN",
		"next_turret_id": "-1",
		"tier": tower_tier,
		"damage": 10.0,
		"attack_interval_sec": 0.5,
		"range_px": 120.0,
		"cc_duration": 1.0,
		"cc_value": 0.0,
		"color_hex": "8a7dff",
	}, 0, false)
	return tower


func _create_monster(arena: Node2D, x_position: float, floor_index: int) -> PrototypeMonster:
	var monster := MONSTER_SCENE.instantiate() as PrototypeMonster
	arena.add_child(monster)
	var path := PackedVector2Array([
		Vector2(320.0, -500.0), Vector2(300.0, -500.0), Vector2(280.0, -500.0),
		Vector2(220.0, 0.0), Vector2(-220.0, 0.0),
		Vector2(220.0, 500.0), Vector2(-220.0, 500.0),
		Vector2(220.0, 1000.0), Vector2(-220.0, 1000.0),
	])
	monster.setup({
		"id": "normal1",
		"display_name": "일반 몬스터",
		"type": "NORMAL",
		"max_hp": 100.0,
		"move_speed_px_sec": 100.0,
		"reward_gold": 1,
	}, path)
	monster.path_index = 3 + floor_index * 2
	monster.move_state = PrototypeMonster.MoveState.WALKING
	monster.scale = Vector2.ONE * PrototypeMonster.MONSTER_VISUAL_SCALE
	monster.position = Vector2(x_position, path[monster.path_index].y)
	return monster


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
