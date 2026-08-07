extends SceneTree

# 실제 적 스프라이트의 리소스 경계, 균일 배율과 발판 접지를 데이터 검증과 분리해 확인한다.
const MonsterScript := preload("res://scripts/monster.gd")
const MONSTER_SCENE := preload("res://scenes/entities/monster.tscn")
const COMBAT_FLOOR_INTERVAL := 525.0


func _init() -> void:
	for monster_type in ["NORMAL", "SPEED", "TANK", "BOSS"]:
		var texture: Texture2D = MonsterScript._texture_for_type(monster_type)
		var bounds: Rect2 = MonsterScript._visible_bounds_for_type(monster_type)
		if texture == null or bounds.size.x <= 0.0 or bounds.size.y <= 0.0 \
				or bounds.end.x > texture.get_width() or bounds.end.y > texture.get_height():
			_fail("invalid monster texture bounds: %s" % monster_type)
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
		elif not is_equal_approx(sqrt(visible_size.x * visible_size.y), MonsterScript.REGULAR_VISIBLE_AREA_SIDE):
			_fail("regular monster must match the tier 1 tower visual area: %s" % monster_type)
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
		monster.free()

	print("Monster visual validation passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
