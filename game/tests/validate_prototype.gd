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
const EXPECTED_MONSTER_BALANCE := {
	"normal1": [105, 4], "normal2": [2835, 4],
	"spped1": [315, 4], "spped2": [2126, 4],
	"tank1": [945, 4], "tank2": [5670, 4],
	"boss1": [3780, 50],
}


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
	if not is_equal_approx(database.define_float("waveTimeSec", -1.0), 80.0):
		_fail("waveTimeSec must match the updated source value 80 seconds")
		return
	if database.get_wave_monster_ids("wave1").is_empty():
		_fail("wave1 must contain SpawnTable rows")
		return
	if database.get_wave_monster_ids("wave1").size() != 100:
		_fail("wave1 must expand the latest source row to 100 monsters")
		return
	if database.get_wave_monster_ids("wave2").size() != 200 or database.get_wave_monster_ids("wave2")[0] != "spped1":
		_fail("wave2 must preserve the latest spped1 source row")
		return
	if database.get_wave_monster_ids("wave3").size() != 300 or database.get_wave_monster_ids("wave3")[0] != "tank1":
		_fail("wave3 must preserve the latest tank1 source row")
		return
	var wave4 := database.get_wave_monster_ids("wave4")
	if wave4.size() != 900 or wave4[0] != "normal2" or wave4[300] != "spped2" or wave4[600] != "tank2":
		_fail("wave4 must preserve equal spawnOrder rows in source order")
		return
	var wave1_schedule := database.get_wave_spawn_entries("wave1")
	if not is_equal_approx(float(wave1_schedule[0].get("delay_after_sec", -1.0)), 0.4) or not is_equal_approx(float(wave1_schedule[99].get("delay_after_sec", -1.0)), 0.4):
		_fail("spawn entries must use the source 0.4 second interval inside the only order")
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
	for monster_id in EXPECTED_MONSTER_BALANCE:
		var monster := database.get_monster_data(monster_id)
		var expected: Array = EXPECTED_MONSTER_BALANCE[monster_id]
		if not is_equal_approx(float(monster.get("max_hp", 0.0)), float(expected[0])) \
				or int(monster.get("reward_gold", 0)) != int(expected[1]):
			_fail("monster balance must match the latest read-only source: %s" % monster_id)
			return
	# 타입별 실제 스프라이트가 유효하고 종횡비 보존 배율·발판 접지 크기가 일치해야 한다.
	if not is_equal_approx(MonsterScript.MONSTER_VISUAL_SCALE, 1.6):
		_fail("monster transition scale must remain 1.6")
		return
	for monster_type in ["NORMAL", "SPEED", "TANK", "BOSS"]:
		var monster_texture: Texture2D = MonsterScript._texture_for_type(monster_type)
		var monster_bounds: Rect2 = MonsterScript._visible_bounds_for_type(monster_type)
		if monster_texture == null or monster_bounds.size.x <= 0.0 or monster_bounds.size.y <= 0.0 \
				or monster_bounds.end.x > monster_texture.get_width() or monster_bounds.end.y > monster_texture.get_height():
			_fail("monster visible bounds are outside the texture: %s" % monster_type)
			return
		var monster_texture_scale: float = MonsterScript._texture_scale_for_type(monster_type)
		var monster_visible_size: Vector2 = monster_bounds.size * monster_texture_scale
		if not is_equal_approx(monster_visible_size.y * 0.5, MonsterScript._body_bottom_offset_for_type(monster_type)):
			_fail("monster floor contact offset does not match visible height: %s" % monster_type)
			return
		if monster_type == "BOSS":
			if not is_equal_approx(monster_visible_size.y, MonsterScript.BOSS_VISIBLE_HEIGHT):
				_fail("boss visual height must remain below one combat-floor interval")
				return
		else:
			if not is_equal_approx(monster_texture_scale, MonsterScript.REGULAR_TEXTURE_SCALE):
				_fail("regular monster must preserve the shared source-pixel scale: %s" % monster_type)
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
	# Web에서는 동적 _draw 콜백을 막아도 공격 본체가 사라지지 않도록 독립 CanvasItem
	# 노드가 텍스처를 직접 소유해야 한다.
	var projectile_visual_probe := TowerProjectileScript.new() as PrototypeTowerProjectile
	get_root().add_child(projectile_visual_probe)
	projectile_visual_probe.source_type = "RANGED"
	projectile_visual_probe.call("_configure_visual_nodes")
	if projectile_visual_probe.projectile_sprite == null or projectile_visual_probe.trail_line == null \
			or projectile_visual_probe.projectile_sprite.texture != TowerProjectileScript.RANGED_PROJECTILE_TEXTURE:
		_fail("ranged projectile must use Web-safe Sprite2D and Line2D visuals")
		return
	projectile_visual_probe.free()
	var flame_visual_probe := TowerFlamethrowerScript.new() as PrototypeTowerFlamethrower
	get_root().add_child(flame_visual_probe)
	flame_visual_probe.call("_configure_flame_sprite")
	if flame_visual_probe.flame_sprite == null or flame_visual_probe.flame_sprite.texture != TowerFlamethrowerScript.FLAME_TEXTURE:
		_fail("flamethrower must use a Web-safe Sprite2D visual")
		return
	flame_visual_probe.target_distance_px = 270.0
	flame_visual_probe.elapsed_sec = 0.0
	flame_visual_probe.call("_update_flame_visual")
	var flame_bounds: Rect2 = TowerFlamethrowerScript.FLAME_VISIBLE_BOUNDS
	var flame_texture_half_size := flame_visual_probe.flame_sprite.texture.get_size() * 0.5
	var visible_center_y := flame_bounds.get_center().y
	var flame_source_point := flame_visual_probe.flame_sprite.position + (
		Vector2(flame_bounds.position.x, visible_center_y) - flame_texture_half_size
	) * flame_visual_probe.flame_sprite.scale
	var flame_target_point := flame_visual_probe.flame_sprite.position + (
		Vector2(flame_bounds.end.x, visible_center_y) - flame_texture_half_size
	) * flame_visual_probe.flame_sprite.scale
	var expected_flame_end := Vector2(270.0 + TowerFlamethrowerScript.TARGET_CENTER_OVERLAP_PX, 0.0)
	if not flame_source_point.is_equal_approx(Vector2.ZERO) or not flame_target_point.is_equal_approx(expected_flame_end):
		_fail("flamethrower opaque bounds must overlap beyond the target center")
		return
	if not (flame_source_point.x < 270.0 and flame_target_point.x > 270.0):
		_fail("flamethrower target center must remain inside the opaque horizontal span")
		return
	# 실제 전장처럼 부모가 0.5배 축소돼도 길이가 다시 절반으로 줄지 않아야 한다.
	var flame_parent_probe := Node2D.new()
	flame_parent_probe.position = Vector2(20.0, 30.0)
	flame_parent_probe.scale = Vector2(0.5, 0.5)
	get_root().add_child(flame_parent_probe)
	flame_visual_probe.reparent(flame_parent_probe, false)
	var flame_source_probe := Node2D.new()
	var flame_target_probe := Node2D.new()
	flame_parent_probe.add_child(flame_source_probe)
	flame_parent_probe.add_child(flame_target_probe)
	flame_source_probe.position = Vector2(40.0, 80.0)
	flame_target_probe.position = Vector2(310.0, 80.0)
	flame_visual_probe.source_tower = flame_source_probe
	flame_visual_probe.target = flame_target_probe
	flame_visual_probe.call("_update_transform_from_combatants")
	if not flame_visual_probe.position.is_equal_approx(flame_source_probe.position) \
			or not is_equal_approx(flame_visual_probe.target_distance_px, 270.0) \
			or not flame_visual_probe.to_global(Vector2(270.0, 0.0)).is_equal_approx(flame_target_probe.global_position):
		_fail("flamethrower endpoint must survive the scaled battlefield parent transform")
		return
	flame_parent_probe.free()
	for hit_type in ["MELEE", "STUN"]:
		var hit_visual_probe := TowerHitEffectScript.new() as PrototypeTowerHitEffect
		get_root().add_child(hit_visual_probe)
		hit_visual_probe.setup(hit_type, 1, 144.0)
		if hit_visual_probe.effect_sprite == null or hit_visual_probe.effect_sprite.texture == null:
			_fail("hitscan effect must use a Web-safe Sprite2D visual: %s" % hit_type)
			return
		if hit_type == "STUN":
			if hit_visual_probe.stun_cloud_sprite == null \
					or hit_visual_probe.stun_cloud_sprite.texture == null:
				_fail("stun hit effect must split the cloud from the grounded lightning")
				return
			var cloud_bottom := hit_visual_probe.stun_cloud_sprite.position.y \
				+ hit_visual_probe.stun_cloud_draw_size.y * 0.5
			var bolt_bottom := hit_visual_probe.effect_sprite.position.y \
				+ hit_visual_probe.base_draw_size.y * 0.5
			if cloud_bottom > -144.0 - TowerHitEffectScript.STUN_CLOUD_HEAD_GAP \
					or not is_equal_approx(bolt_bottom, 4.0):
				_fail("stun cloud must stay above the target head and lightning must touch the floor")
				return
		hit_visual_probe.free()
	# 대기·공격 시트는 런타임에 설치된 타입·Tier만 지연 로드해야 한다. 40장을 정적
	# preload하면 Web 메모리가 전투 시작 전부터 크게 늘어나 전체 캔버스가 멎을 수 있다.
	for turret_type in TowerVisualAssetsScript.IDLE_TEXTURE_PATHS:
		for idle_texture_path in TowerVisualAssetsScript.IDLE_TEXTURE_PATHS[turret_type]:
			if ResourceLoader.has_cached(str(idle_texture_path)):
				_fail("tower idle sheet must not preload before it is requested: %s" % str(idle_texture_path))
				return
	for turret_type in TowerVisualAssetsScript.ATTACK_TEXTURE_PATHS:
		for attack_texture_path in TowerVisualAssetsScript.ATTACK_TEXTURE_PATHS[turret_type]:
			if ResourceLoader.has_cached(str(attack_texture_path)):
				_fail("tower attack sheet must not preload before it is requested: %s" % str(attack_texture_path))
				return
	# 빠르게 발사되는 원거리 포탑의 트레일은 장시간 갱신해도 고정 길이를 넘지 않아야 한다.
	# 이 검사는 Web 메인 스레드를 영구 정지시킬 수 있는 반복 제거 회귀를 함께 방지한다.
	var projectile_trail_probe := TowerProjectileScript.new() as PrototypeTowerProjectile
	for point_index in 5000:
		projectile_trail_probe.global_position = Vector2(float(point_index) * 11.0, 0.0)
		projectile_trail_probe.call("_record_trail_point", true)
	if projectile_trail_probe.trail_global_points.size() != TowerProjectileScript.MAX_TRAIL_POINT_COUNT:
		_fail("projectile trail history must remain bounded during sustained fire")
		return
	var expected_oldest_x := float(5000 - TowerProjectileScript.MAX_TRAIL_POINT_COUNT) * 11.0
	if not is_equal_approx(projectile_trail_probe.trail_global_points[0].x, expected_oldest_x):
		_fail("projectile trail history did not discard the oldest point")
		return
	projectile_trail_probe.free()
	if int(database.get_monster_data("boss1").get("reward_gold", 0)) != 50:
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
	# 모든 대기·공격 시트는 임포트 후 256px 프레임을 제공하며 첫 프레임 경계가 유효해야 한다.
	for turret_type in ["MELEE", "RANGED", "DOT", "SLOW", "STUN"]:
		for tier in range(1, 5):
			var idle_texture: Texture2D = TowerVisualAssetsScript.idle_texture(turret_type, tier)
			var idle_bounds: Rect2 = TowerVisualAssetsScript.idle_first_frame_visible_bounds(turret_type, tier)
			if idle_texture.get_size() != Vector2(TowerVisualAssetsScript.IDLE_FRAME_SIZE.x * 2.0, TowerVisualAssetsScript.IDLE_FRAME_SIZE.y):
				_fail("tower idle sheet must import as a 512x256 2-frame sheet: %s tier %d" % [turret_type, tier])
				return
			if idle_bounds.size.x <= 0.0 or idle_bounds.size.y <= 0.0 or idle_bounds.end.x > TowerVisualAssetsScript.IDLE_FRAME_SIZE.x or idle_bounds.end.y > TowerVisualAssetsScript.IDLE_FRAME_SIZE.y:
				_fail("tower idle frame bounds are outside frame 1: %s tier %d" % [turret_type, tier])
				return
			var attack_texture: Texture2D = TowerVisualAssetsScript.attack_texture(turret_type, tier)
			var attack_bounds: Rect2 = TowerVisualAssetsScript.attack_first_frame_visible_bounds(turret_type, tier)
			if attack_texture.get_size() != TowerVisualAssetsScript.ATTACK_FRAME_SIZE * 2.0:
				_fail("tower attack sheet must import as a 512px 2x2 sheet: %s tier %d" % [turret_type, tier])
				return
			if attack_bounds.size.x <= 0.0 or attack_bounds.size.y <= 0.0 or attack_bounds.end.x > TowerVisualAssetsScript.ATTACK_FRAME_SIZE.x or attack_bounds.end.y > TowerVisualAssetsScript.ATTACK_FRAME_SIZE.y:
				_fail("tower attack frame bounds are outside frame 1: %s tier %d" % [turret_type, tier])
				return
	# RANGED Tier 2·3의 두 idle 프레임은 같은 Tier 실루엣이어야 한다. 두 시트의 오른쪽
	# 프레임이 서로 뒤바뀌어 공격 종료 때 다른 Tier로 보였던 회귀를 폭 차이로 차단한다.
	var idle_frame_size := Vector2i(TowerVisualAssetsScript.IDLE_FRAME_SIZE)
	for tier in [2, 3]:
		var ranged_idle_image := TowerVisualAssetsScript.idle_texture("RANGED", tier).get_image()
		var first_idle_bounds := _image_alpha_bounds(ranged_idle_image, Rect2i(Vector2i.ZERO, idle_frame_size))
		var second_idle_bounds := _image_alpha_bounds(ranged_idle_image, Rect2i(Vector2i(idle_frame_size.x, 0), idle_frame_size))
		if absi(first_idle_bounds.size.x - second_idle_bounds.size.x) > 4:
			_fail("ranged idle frames must not mix tiers: tier %d" % tier)
			return
	# Sprite2D의 행 우선 프레임 번호가 실제 재생에서도 좌상→우상→좌하→우하(0→1→2→3)
	# 순서를 유지하고, 끝나면 다시 대기 애니메이션을 표시해야 한다.
	var animation_probe := TowerScript.new() as PrototypeTower
	get_root().add_child(animation_probe)
	animation_probe.setup(database.get_turret_data("turretMelee1"), 0, false)
	animation_probe.attack_sprite.texture = TowerVisualAssetsScript.attack_texture("MELEE", 1)
	animation_probe.attack_sprite.hframes = TowerVisualAssetsScript.ATTACK_FRAME_COLUMNS
	animation_probe.attack_sprite.vframes = TowerVisualAssetsScript.ATTACK_FRAME_ROWS
	animation_probe.attack_visual_ready = true
	animation_probe.call("_play_attack_animation")
	var observed_attack_frames := [animation_probe.attack_sprite.frame]
	for _step in 3:
		animation_probe.call("_update_attack_animation", TowerScript.ATTACK_FRAME_DURATION_SEC + 0.001)
		observed_attack_frames.append(animation_probe.attack_sprite.frame)
	if observed_attack_frames != [0, 1, 2, 3]:
		_fail("tower attack frames must play top-left, top-right, bottom-left, bottom-right")
		return
	animation_probe.call("_update_attack_animation", TowerScript.ATTACK_FRAME_DURATION_SEC + 0.001)
	if animation_probe.attack_sprite.visible or not animation_probe.body_sprite.visible:
		_fail("tower must return to idle animation after attack frame 4")
		return
	animation_probe.free()
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


func _image_alpha_bounds(image: Image, region: Rect2i) -> Rect2i:
	var min_x := region.size.x
	var min_y := region.size.y
	var max_x := -1
	var max_y := -1
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a <= 0.01:
				continue
			min_x = mini(min_x, x - region.position.x)
			min_y = mini(min_y, y - region.position.y)
			max_x = maxi(max_x, x - region.position.x)
			max_y = maxi(max_y, y - region.position.y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
