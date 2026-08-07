extends SceneTree

# Godot 장면을 띄우지 않고 데이터 테이블만 검증하는 헤드리스 테스트다.
# 실패 시 즉시 종료 코드 1을 반환해 로컬/CI 검증에서 오류를 감지한다.

# 실제 게임과 동일한 로더를 사용해야 테스트와 런타임 검증이 어긋나지 않는다.
const DatabaseScript := preload("res://scripts/prototype_database.gd")
const TowerScript := preload("res://scripts/tower.gd")
const TowerVisualAssetsScript := preload("res://scripts/tower_visual_assets.gd")
const BattlefieldWorldScript := preload("res://scripts/battlefield_world.gd")
const MonsterScript := preload("res://scripts/monster.gd")
const TowerProjectileScript := preload("res://scripts/tower_projectile.gd")
const TowerFlamethrowerScript := preload("res://scripts/tower_flamethrower.gd")
const TowerHitEffectScript := preload("res://scripts/tower_hit_effect.gd")

# 읽기 전용 데이터 테이블의 대표 오브젝트 ID다. 원본 오탈자 spped1도 그대로 보존한다.
const EXPECTED_TURRET_IDS := ["turretMelee1", "turretDot1", "turretStun1", "turretSlow1", "turretRanged1"]
const EXPECTED_MONSTER_IDS := ["normal1", "spped1", "tank1", "boss1"]


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
	if database.define_int("totalWaveCount", -1) != 4:
		_fail("totalWaveCount must match the updated source value 4")
		return
	if not is_equal_approx(database.define_float("spawnOrderInterval", -1.0), 0.5):
		_fail("spawnOrderInterval must match the updated source value 0.5 seconds")
		return
	if database.get_wave_monster_ids("wave1").is_empty():
		_fail("wave1 must contain SpawnTable rows")
		return
	if database.get_wave_monster_ids("wave3").size() != 29:
		_fail("wave3 must preserve all source rows and expand to 29 monsters")
		return
	var wave3 := database.get_wave_monster_ids("wave3")
	if wave3[0] != "tank1" or wave3[4] != "tank1" or wave3[8] != "spped1":
		_fail("wave3 must follow the updated unique spawnOrder values")
		return
	if database.get_wave_monster_ids("wave2")[0] != "tank1":
		_fail("waves without duplicate spawnOrder must remain ordered by spawnOrder")
		return
	var wave1_schedule := database.get_wave_spawn_entries("wave1")
	if not is_equal_approx(float(wave1_schedule[0].get("delay_after_sec", -1.0)), 0.4) or not is_equal_approx(float(wave1_schedule[1].get("delay_after_sec", -1.0)), 0.5):
		_fail("spawn entries must use source values 0.4 seconds inside an order and 0.5 seconds between orders")
		return
	for turret_id in EXPECTED_TURRET_IDS:
		var turret := database.get_turret_data(turret_id)
		if turret.is_empty() or float(turret.get("damage", 0.0)) <= 0.0:
			_fail("missing prototype turret object: %s" % turret_id)
			return
		# 상점 Tier 1부터 네 단계가 끊김 없이 이어져 런타임 머지가 항상 상위 스탯을 찾을 수 있어야 한다.
		var current_turret := turret
		for expected_tier in range(1, 5):
			if int(current_turret.get("tier", -1)) != expected_tier:
				_fail("turret merge chain has an invalid tier: %s expected %d" % [str(current_turret.get("id", "")), expected_tier])
				return
			var next_turret_id := str(current_turret.get("next_turret_id", "-1"))
			if expected_tier == 4:
				if next_turret_id != "-1":
					_fail("tier 4 turret must end the merge chain: %s" % str(current_turret.get("id", "")))
					return
			else:
				current_turret = database.get_turret_data(next_turret_id)
				if current_turret.is_empty():
					_fail("turret merge chain is missing next data: %s" % next_turret_id)
					return
	for monster_id in EXPECTED_MONSTER_IDS:
		var monster := database.get_monster_data(monster_id)
		if monster.is_empty() or float(monster.get("max_hp", 0.0)) <= 0.0:
			_fail("missing prototype monster object: %s" % monster_id)
			return
	# 정식 몬스터 그래픽을 대비한 확대 배율과 발판 접지 오프셋이 같은 배율을 사용해야 한다.
	if not is_equal_approx(MonsterScript.MONSTER_VISUAL_SCALE, 1.6):
		_fail("placeholder monster visual scale must remain 1.6")
		return
	if not is_equal_approx(MonsterScript._body_bottom_offset_for_type("NORMAL"), 25.6):
		_fail("scaled monster floor contact offset is invalid")
		return
	# 생성형 이미지로 교체한 투사체와 히트스캔 텍스처가 모두 빌드에 포함되는지 검사한다.
	var combat_vfx_textures: Array[Texture2D] = [
		TowerProjectileScript.SLOW_PROJECTILE_TEXTURE,
		TowerProjectileScript.RANGED_PROJECTILE_TEXTURE,
		TowerFlamethrowerScript.FLAME_TEXTURE,
		TowerHitEffectScript.MELEE_SLASH_TEXTURE,
		TowerHitEffectScript.STUN_LIGHTNING_TEXTURE,
		MonsterScript.STUN_STATUS_TEXTURE,
		TowerScript.STUN_CHARGE_AURA_TEXTURE,
	]
	for combat_vfx_texture in combat_vfx_textures:
		if combat_vfx_texture == null or combat_vfx_texture.get_width() <= 0 or combat_vfx_texture.get_height() <= 0:
			_fail("combat VFX texture failed to load")
			return
	# Loading alone does not catch a broken chroma-key pass. The flame and stun
	# stars must retain enough opaque subject pixels to be visible in combat.
	if not _texture_has_opaque_coverage(TowerFlamethrowerScript.FLAME_TEXTURE, 0.20):
		_fail("flamethrower texture lost its visible interior during alpha processing")
		return
	if not _texture_has_opaque_coverage(MonsterScript.STUN_STATUS_TEXTURE, 0.08):
		_fail("stun status texture lost its visible interior during alpha processing")
		return
	if int(database.get_monster_data("boss1").get("reward_gold", 0)) != 555555:
		_fail("boss1 rewardGold must match the read-only source value")
		return
	var dot_turret := database.get_turret_data("turretDot1")
	if not is_equal_approx(float(dot_turret.get("cc_value", 0.0)), 0.5):
		_fail("percentage ccValue must be normalized to a 0-1 ratio")
		return
	# DOT는 기획자 확정에 따라 rangeValue=1.5를 사용하고, 나머지 원거리형은 range=2를 180px 슬롯 간격으로 변환한다.
	if not is_equal_approx(float(dot_turret.get("range_px", -1.0)), 270.0):
		_fail("turretDot1 range must use rangeValue 1.5 slots")
		return
	if not is_equal_approx(float(database.get_turret_data("turretStun1").get("range_px", -1.0)), 360.0):
		_fail("turretStun1 range must match the latest source value 2 slots")
		return
	if not is_equal_approx(float(database.get_turret_data("turretSlow1").get("range_px", -1.0)), 360.0):
		_fail("turretSlow1 range must match the latest source value 2 slots")
		return
	# 모든 5종의 실제 불투명 그림 경계가 유효하고 Tier별 목표 면적이 계속 증가하는지 검사한다.
	for turret_type in ["MELEE", "RANGED", "DOT", "SLOW", "STUN"]:
		var previous_visible_side := 0.0
		for tier in range(1, 5):
			var texture: Texture2D = TowerVisualAssetsScript.body_texture(turret_type, tier)
			var bounds: Rect2 = TowerVisualAssetsScript.body_visible_bounds(turret_type, tier)
			if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.end.x > texture.get_width() or bounds.end.y > texture.get_height():
				_fail("tower visible bounds are outside the texture: %s tier %d" % [turret_type, tier])
				return
			var target_side: float = TowerScript.body_visible_area_side(turret_type, tier)
			var runtime_scale: float = TowerScript._scale_for_visible_area(bounds, target_side)
			var normalized_visible_side := sqrt(bounds.size.x * bounds.size.y) * runtime_scale
			if normalized_visible_side <= previous_visible_side or not is_equal_approx(normalized_visible_side, target_side):
				_fail("tower visual size must grow consistently: %s tier %d" % [turret_type, tier])
				return
			previous_visible_side = normalized_visible_side
	# 지속 포탑 Tier 4 idle 불꽃은 원본의 분리된 좌측 공격 조각을 제외한 AtlasTexture여야 한다.
	if TowerVisualAssetsScript.dot_flame_texture(4).get_size() != Vector2(184.0, 192.0):
		_fail("DOT tier 4 idle flame must use the cropped main-flame region")
		return
	if TowerVisualAssetsScript.dot_front_texture(3).get_size() != Vector2(256.0, 242.0) or TowerVisualAssetsScript.dot_front_texture(4).get_size() != Vector2(256.0, 189.0):
		_fail("DOT tier 3 and 4 must provide separate front body layers")
		return
	# v7 낮/밤 이미지의 세 전투 플랫폼은 같은 픽셀 행이며 렌더링 추가 변형도 없어야 한다.
	var night_source_rows := [848.0, 1081.0, 1320.0]
	var day_target_rows := [848.0, 1081.0, 1320.0]
	for row_index in night_source_rows.size():
		var aligned_row: float = BattlefieldWorldScript.NIGHT_VERTICAL_OFFSET_SOURCE_PX + night_source_rows[row_index] * BattlefieldWorldScript.NIGHT_VERTICAL_SCALE
		if absf(aligned_row - day_target_rows[row_index]) > 1.25:
			_fail("night background alignment drifted at platform %d" % (row_index + 1))
			return

	print("Prototype data validation passed.")
	quit(0)


# 오류 메시지를 Godot 로그에 남기고 테스트 프로세스를 실패로 종료한다.
func _texture_has_opaque_coverage(texture: Texture2D, minimum_ratio: float) -> bool:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return false
	var opaque_pixel_count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a >= 0.75:
				opaque_pixel_count += 1
	var total_pixel_count := image.get_width() * image.get_height()
	return total_pixel_count > 0 and float(opaque_pixel_count) / float(total_pixel_count) >= minimum_ratio


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
