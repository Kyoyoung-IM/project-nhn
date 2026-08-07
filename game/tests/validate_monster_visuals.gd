extends SceneTree

# 실제 적 스프라이트의 리소스 경계, 균일 배율과 발판 접지를 데이터 검증과 분리해 확인한다.
const MonsterScript := preload("res://scripts/monster.gd")
const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const COMBAT_FLOOR_INTERVAL := 525.0


func _init() -> void:
	for monster_type in ["NORMAL", "SPEED", "TANK", "BOSS"]:
		var texture: Texture2D = MonsterScript._texture_for_type(monster_type)
		var bounds: Rect2 = MonsterScript._visible_bounds_for_type(monster_type)
		var hit_texture: Texture2D = MonsterScript._hit_texture_for_type(monster_type)
		var hit_bounds: Rect2 = MonsterScript._hit_visible_bounds_for_type(monster_type)
		var death_texture: Texture2D = MonsterScript._death_texture_for_type(monster_type)
		if texture == null or bounds.size.x <= 0.0 or bounds.size.y <= 0.0 \
				or bounds.end.x > texture.get_width() or bounds.end.y > texture.get_height():
			_fail("invalid monster texture bounds: %s" % monster_type)
			return
		if hit_texture == null or hit_bounds.size.x <= 0.0 or hit_bounds.size.y <= 0.0 \
				or hit_bounds.end.x > hit_texture.get_width() or hit_bounds.end.y > hit_texture.get_height():
			_fail("invalid monster hit texture bounds: %s" % monster_type)
			return
		if death_texture == null \
				or death_texture.get_width() != int(MonsterScript.DEATH_FRAME_SIZE.x) \
				or death_texture.get_height() != int(MonsterScript.DEATH_FRAME_SIZE.y) * MonsterScript.DEATH_FRAME_COUNT:
			_fail("invalid monster death sprite sheet: %s" % monster_type)
			return
		var uniform_scale: float = MonsterScript._texture_scale_for_type(monster_type)
		var visible_size := bounds.size * uniform_scale
		if not is_equal_approx(visible_size.x / bounds.size.x, visible_size.y / bounds.size.y):
			_fail("monster aspect ratio changed: %s" % monster_type)
			return
		if not is_equal_approx(visible_size.y * 0.5, MonsterScript._body_bottom_offset_for_type(monster_type)):
			_fail("monster floor offset does not match its visible height: %s" % monster_type)
			return
		if monster_type == "BOSS":
			if not is_equal_approx(visible_size.y, MonsterScript.BOSS_VISIBLE_HEIGHT) or visible_size.y >= COMBAT_FLOOR_INTERVAL:
				_fail("boss must remain slightly shorter than one combat floor")
				return
		elif not is_equal_approx(uniform_scale, MonsterScript.REGULAR_TEXTURE_SCALE):
			_fail("regular monster must preserve the shared source-pixel scale: %s" % monster_type)
			return

		var monster := MONSTER_SCENE.instantiate() as PrototypeMonster
		var floor_contact := Vector2(900.0, 1857.0)
		monster.setup(
			{
				"id": monster_type.to_lower(),
				"display_name": monster_type,
				"type": monster_type,
				"max_hp": 10.0,
				"move_speed_px_sec": 100.0,
				"reward_gold": 1,
			},
			PackedVector2Array([floor_contact, floor_contact + Vector2(-100.0, 0.0)])
		)
		if monster.body_sprite == null or monster.body_sprite.texture != texture \
				or not is_equal_approx(monster.body_sprite.scale.x, monster.body_sprite.scale.y):
			monster.free()
			_fail("monster body must use one uniformly scaled Sprite2D: %s" % monster_type)
			return
		if not is_equal_approx(monster.position.y + monster.body_bottom_offset_y, floor_contact.y):
			monster.free()
			_fail("monster was not grounded after setup: %s" % monster_type)
			return
		var expected_bar_top := (-monster.body_bottom_offset_y - MonsterScript.HEALTH_BAR_HEAD_GAP) \
			/ MonsterScript.MONSTER_VISUAL_SCALE
		var actual_bar_height := monster.health_bar.size.y * monster.health_bar.scale.y \
			* MonsterScript.MONSTER_VISUAL_SCALE
		if not is_equal_approx(monster.health_bar.position.y, expected_bar_top) \
				or not is_equal_approx(actual_bar_height, MonsterScript.HEALTH_BAR_HEIGHT):
			var health_bar_error := (
				"monster health bar must remain thin and above the visible head: %s position=%s/%s height=%s/%s"
				% [monster_type, monster.health_bar.position.y, expected_bar_top, actual_bar_height, MonsterScript.HEALTH_BAR_HEIGHT]
			)
			monster.free()
			_fail(health_bar_error)
			return
		if monster.hit_sprite == null or monster.hit_sprite.texture != hit_texture \
				or monster.hit_sprite.visible \
				or not is_equal_approx(monster.hit_sprite.scale.x, monster.hit_sprite.scale.y):
			monster.free()
			_fail("monster hit visual must start hidden and use one uniformly scaled Sprite2D: %s" % monster_type)
			return
		if monster.death_sprite == null or monster.death_sprite.texture != death_texture \
				or monster.death_sprite.visible \
				or not monster.death_sprite.region_enabled \
				or not is_equal_approx(monster.death_sprite.scale.x, monster.death_sprite.scale.y):
			monster.free()
			_fail("monster death visual must start hidden and use one uniformly scaled sprite sheet: %s" % monster_type)
			return
		var death_local_bottom := monster.death_sprite.position.y \
			+ (MonsterScript._death_floor_y_for_type(monster_type) - MonsterScript.DEATH_FRAME_SIZE.y * 0.5) \
			* monster.death_sprite.scale.y
		if not is_equal_approx(death_local_bottom * MonsterScript.MONSTER_VISUAL_SCALE, monster.body_bottom_offset_y):
			monster.free()
			_fail("monster death visual was not grounded: %s" % monster_type)
			return
		var hit_local_bottom := monster.hit_sprite.position.y \
				+ (hit_bounds.end.y - hit_texture.get_height() * 0.5) * monster.hit_sprite.scale.y
		if not is_equal_approx(hit_local_bottom * MonsterScript.MONSTER_VISUAL_SCALE, monster.body_bottom_offset_y):
			monster.free()
			_fail("monster hit visual was not grounded: %s" % monster_type)
			return

		monster.receive_turret_hit(1.0, "RANGED", 0.0, 0.0)
		if monster.body_sprite.visible or not monster.hit_sprite.visible \
				or not is_equal_approx(monster.hit_visual_remaining_sec, MonsterScript.HIT_VISUAL_DURATION_SEC):
			monster.free()
			_fail("direct hit did not start the monster hit visual: %s" % monster_type)
			return
		monster.receive_turret_hit(1.0, "RANGED", 0.0, 0.0)
		if not is_equal_approx(
				monster.hit_visual_remaining_sec,
				MonsterScript.HIT_VISUAL_DURATION_SEC + MonsterScript.HIT_VISUAL_STACK_SEC
		):
			monster.free()
			_fail("repeated direct hit did not extend the monster hit visual: %s" % monster_type)
			return
		monster._process_hit_visual(MonsterScript.HIT_VISUAL_DURATION_SEC + MonsterScript.HIT_VISUAL_STACK_SEC)
		monster.receive_turret_hit(1.0, "DOT", 2.0, 0.5)
		monster._process_hit_visual(MonsterScript.HIT_VISUAL_DURATION_SEC)
		monster._process_status_effects(1.0)
		if not monster.body_sprite.visible or monster.hit_sprite.visible or monster.hit_visual_remaining_sec > 0.0:
			monster.free()
			_fail("damage-over-time must not show the monster hit visual: %s" % monster_type)
			return

		var defeated_signal_count := [0]
		monster.defeated.connect(func(_defeated_monster: PrototypeMonster) -> void: defeated_signal_count[0] += 1)
		monster.take_damage(monster.hp)
		if monster.move_state != PrototypeMonster.MoveState.DEAD \
				or defeated_signal_count[0] != 1 \
				or monster.body_sprite.visible \
				or monster.hit_sprite.visible \
				or not monster.death_sprite.visible \
				or monster.is_queued_for_deletion():
			monster.free()
			_fail("fatal damage did not start the delayed death animation: %s" % monster_type)
			return
		monster._process_death_animation(MonsterScript.DEATH_FRAME_DURATION_SEC * 3.1)
		if not is_equal_approx(
			monster.death_sprite.region_rect.position.y,
			MonsterScript.DEATH_FRAME_SIZE.y * 3.0
		):
			monster.free()
			_fail("monster death animation did not advance frames: %s" % monster_type)
			return
		monster._process_death_animation(MonsterScript.DEATH_ANIMATION_DURATION_SEC)
		if not monster.is_queued_for_deletion():
			monster.free()
			_fail("monster was not removed after the death animation: %s" % monster_type)
			return

	print("Monster visual validation passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
