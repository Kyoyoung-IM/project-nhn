class_name PrototypeTower
extends Node2D

# 한 개의 배치된 터렛 오브젝트를 담당한다.
# 데이터베이스에서 정규화된 설정을 받아 표적 선택, 공격과 타입별 연출을 처리한다.
# 이 분기에서 터렛은 체력과 사망 상태가 없는 고정 불파괴 오브젝트다.

const TowerVisualAssetsScript := preload("res://scripts/tower_visual_assets.gd")
const TowerProjectileScript := preload("res://scripts/tower_projectile.gd")
const TowerFlamethrowerScript := preload("res://scripts/tower_flamethrower.gd")
const TowerHitEffectScript := preload("res://scripts/tower_hit_effect.gd")
const MeleeExecutionEffectScript := preload("res://scripts/melee_execution_effect.gd")
const RangedLaserEffectScript := preload("res://scripts/ranged_laser_effect.gd")
const DotFireballProjectileScript := preload("res://scripts/dot_fireball_projectile.gd")
const STUN_CHARGE_AURA_TEXTURE := preload("res://assets/combat_vfx/stun_charge_aura_v2.png")

# Tier가 높아질수록 본체가 조금씩 커져 머지 결과를 실루엣만으로도 구분할 수 있다.
# 이 값은 기존 더미 도형의 반경과 무관한 실제 스프라이트 표시 크기다.
# 각 Tier의 실제 불투명 그림 면적이 아래 정사각형과 같은 면적이 되도록 정규화한다.
# 캔버스 크기가 아닌 육안 면적을 기준으로 하므로 모든 포탑이 단계별로 일정하게 커진다.
const BODY_VISIBLE_AREA_SIDE_BY_TIER := [132.0, 154.0, 178.0, 205.0]
# 슬롯 노드는 발판 접지선보다 100px 위에 있으며 일반 타워의 실제 발끝은 이 위치에 맞춘다.
const BODY_BOTTOM_Y := 100.0
# STUN은 다리가 지면에 닿는 타워가 아니라 공중부양형이므로 접지선 위에 여백을 둔다.
const STUN_HOVER_HEIGHT := 36.0
# 대기 시트는 좌→우 프레임을 천천히 반복하고, 공격 시트는 좌상→우상→좌하→우하
# 순서로 0.08초씩 재생한다.
const IDLE_FRAME_DURATION_SEC := 0.45
const ATTACK_FRAME_DURATION_SEC := 0.08
# STUN 공격의 충전 시간은 피해 밸런스와 분리된 시각 전용 PLACEHOLDER 값이다.
const STUN_CHARGE_DURATION_SEC := 0.38
# 기획에 수치가 없는 Tier 3 근접 넉백의 시각·전투용 PLACEHOLDER 거리다.
const MELEE_KNOCKBACK_DISTANCE_PX := 80.0
const MELEE_EXECUTION_HP_RATIO := 0.20
# Tier 2의 세 발이 기존 투사체로 분명하게 구분되어 보이도록 두는 짧은 연사 간격이다.
const RANGED_BURST_SHOT_INTERVAL_SEC := 0.10

# 데이터 식별자와 머지 트리 정보다. 현재 머지 UI가 추가되면 이 값을 그대로 사용한다.
var turret_id: String = ""
var display_name: String = ""
var turret_type: String = "RANGED"
var next_turret_id: String = "-1"
var tier: int = 1

# 전투 능력치다. 모두 prototype_turrets.json에서 로드된 PLACEHOLDER 값이다.
var damage: float = 1.0
var attack_interval_sec: float = 1.0
var attack_range_px: float = 100.0
var cc_duration: float = 0.0
var cc_value: float = 0.0

# 렌더링 색상과 현재 배치된 전투층 인덱스다.
var tower_color := Color("68d8c1")
var floor_index: int = 0

# 공격 재사용 대기시간과 기절 포탑의 충전 상태다.
var cooldown_sec: float = 0.0
var enabled: bool = true
var stun_charge_remaining_sec: float = 0.0
var stun_charge_target: Node2D
var ranged_burst_shots_remaining: int = 0
var ranged_burst_interval_remaining_sec: float = 0.0
var ranged_burst_target: PrototypeMonster

# 머지 직후 상위 Tier가 생성됐음을 보여주는 코드 기반 승급 연출 시간이다.
const UPGRADE_EFFECT_DURATION_SEC := 0.7
var upgrade_effect_remaining_sec: float = 0.0

# 대기 본체와 2x2 공격 시트는 독립 노드로 두고 공격 순간에 표시를 교대한다.
var body_sprite: Sprite2D
var attack_sprite: Sprite2D
var stun_charge_sprite: Sprite2D
var body_base_position := Vector2.ZERO
var idle_animation_elapsed_sec: float = 0.0
var idle_visual_requested: bool = false
var idle_visual_ready: bool = false
var attack_animation_elapsed_sec: float = -1.0
var attack_visual_requested: bool = false
var attack_visual_ready: bool = false


# 로더가 만든 내부 설정을 복사하고 해당 층의 터렛 그룹에 등록한다.
func setup(config: Dictionary, assigned_floor_index: int, request_animation_visuals: bool = true) -> void:
	turret_id = str(config.get("id", ""))
	display_name = str(config.get("display_name", turret_id))
	turret_type = str(config.get("type", "RANGED"))
	next_turret_id = str(config.get("next_turret_id", "-1"))
	tier = int(config.get("tier", 1))
	damage = float(config.get("damage", 1.0))
	attack_interval_sec = float(config.get("attack_interval_sec", 1.0))
	attack_range_px = float(config.get("range_px", 100.0))
	cc_duration = float(config.get("cc_duration", 0.0))
	cc_value = float(config.get("cc_value", 0.0))
	tower_color = Color(str(config.get("color_hex", "68d8c1")))
	floor_index = assigned_floor_index
	cooldown_sec = 0.0
	ranged_burst_shots_remaining = 0
	ranged_burst_interval_remaining_sec = 0.0
	ranged_burst_target = null
	_refresh_visual_nodes(request_animation_visuals)
	add_to_group("prototype_towers")
	_queue_effect_redraw()


# 테스트 밸런스 편집에서 ID·Tier·현재 쿨다운은 보존하고 전투 수치만 즉시 갱신한다.
func apply_runtime_balance(config: Dictionary) -> void:
	damage = float(config.get("damage", damage))
	attack_interval_sec = maxf(0.001, float(config.get("attack_interval_sec", attack_interval_sec)))
	attack_range_px = maxf(0.0, float(config.get("range_px", attack_range_px)))
	cc_duration = maxf(0.0, float(config.get("cc_duration", cc_duration)))
	cc_value = float(config.get("cc_value", cc_value))
	cooldown_sec = minf(cooldown_sec, attack_interval_sec)
	_queue_effect_redraw()


# 타입·Tier별 대기 본체와 공격 시트를 자식 Sprite2D에 연결한다.
func _refresh_visual_nodes(request_animation_visuals: bool = true) -> void:
	if body_sprite == null:
		body_sprite = Sprite2D.new()
		body_sprite.name = "BodySprite"
		body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(body_sprite)
	if attack_sprite == null:
		attack_sprite = Sprite2D.new()
		attack_sprite.name = "AttackSprite"
		attack_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(attack_sprite)
	if stun_charge_sprite == null:
		stun_charge_sprite = Sprite2D.new()
		stun_charge_sprite.name = "StunChargeSprite"
		stun_charge_sprite.texture = STUN_CHARGE_AURA_TEXTURE
		stun_charge_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		stun_charge_sprite.z_index = 2
		stun_charge_sprite.visible = false
		add_child(stun_charge_sprite)

	body_sprite.texture = TowerVisualAssetsScript.body_texture(turret_type, tier)
	body_sprite.hframes = 1
	body_sprite.vframes = 1
	body_sprite.frame = 0
	var body_bounds: Rect2 = TowerVisualAssetsScript.body_visible_bounds(turret_type, tier)
	var body_scale := _scale_for_visible_area(body_bounds, body_visible_area_side(turret_type, tier))
	var target_bottom_y := body_target_bottom_y(turret_type)
	body_base_position = _position_visible_bounds(body_sprite.texture, body_bounds, Vector2(0.0, target_bottom_y), body_scale)
	body_sprite.position = body_base_position
	body_sprite.scale = Vector2.ONE * body_scale
	body_sprite.z_index = 0
	attack_sprite.texture = null
	# Web 메모리 급증을 막기 위해 두 시트 모두 화면 표시 크기에 맞춰 512px로 임포트하며,
	# 실제 배치된 타입·Tier만 한 프레임에 한 장씩 지연 로드한다.
	idle_animation_elapsed_sec = 0.0
	idle_visual_requested = request_animation_visuals
	idle_visual_ready = false
	attack_visual_requested = request_animation_visuals
	attack_visual_ready = false
	if idle_visual_requested:
		TowerVisualAssetsScript.request_idle_texture(turret_type, tier)
	if attack_visual_requested:
		TowerVisualAssetsScript.request_attack_texture(turret_type, tier)
	_try_bind_idle_texture()
	_try_bind_attack_texture()


# 지연 로드된 2프레임 대기 시트로 정지 플레이스홀더를 교체한다.
func _try_bind_idle_texture() -> void:
	if not idle_visual_requested or idle_visual_ready or body_sprite == null:
		return
	var idle_texture := TowerVisualAssetsScript.try_get_idle_texture(turret_type, tier)
	if idle_texture == null:
		return
	body_sprite.texture = idle_texture
	body_sprite.hframes = TowerVisualAssetsScript.IDLE_FRAME_COLUMNS
	body_sprite.vframes = TowerVisualAssetsScript.IDLE_FRAME_ROWS
	body_sprite.frame = 0
	var idle_bounds: Rect2 = TowerVisualAssetsScript.idle_first_frame_visible_bounds(turret_type, tier)
	var idle_scale := _scale_for_visible_area(idle_bounds, body_visible_area_side(turret_type, tier))
	body_base_position = _position_visible_bounds_for_size(
		TowerVisualAssetsScript.IDLE_FRAME_SIZE,
		idle_bounds,
		Vector2(0.0, body_target_bottom_y(turret_type)),
		idle_scale
	)
	body_sprite.position = body_base_position
	body_sprite.scale = Vector2.ONE * idle_scale
	idle_visual_ready = true
	idle_animation_elapsed_sec = 0.0


# 비동기 로드가 완료된 프레임에서만 공격 시트를 연결해 상점 입력 프레임의 정지를 피한다.
func _try_bind_attack_texture() -> void:
	if not attack_visual_requested or attack_visual_ready or attack_sprite == null:
		return
	var attack_texture := TowerVisualAssetsScript.try_get_attack_texture(turret_type, tier)
	if attack_texture == null:
		return
	attack_sprite.texture = attack_texture
	attack_sprite.hframes = TowerVisualAssetsScript.ATTACK_FRAME_COLUMNS
	attack_sprite.vframes = TowerVisualAssetsScript.ATTACK_FRAME_ROWS
	attack_sprite.frame = 0
	var attack_bounds: Rect2 = TowerVisualAssetsScript.attack_first_frame_visible_bounds(turret_type, tier)
	var attack_scale := _scale_for_visible_area(attack_bounds, body_visible_area_side(turret_type, tier))
	attack_sprite.position = _position_visible_bounds_for_size(
		TowerVisualAssetsScript.ATTACK_FRAME_SIZE,
		attack_bounds,
		Vector2(0.0, body_target_bottom_y(turret_type)),
		attack_scale
	)
	attack_sprite.scale = Vector2.ONE * attack_scale
	attack_sprite.z_index = 1
	attack_visual_ready = true
	attack_animation_elapsed_sec = -1.0
	_set_attack_visual_active(false)


# 경계 상자의 면적이 지정된 정사각형 면적과 같아지도록 균일 배율을 계산한다.
static func _scale_for_visible_area(bounds: Rect2, target_area_side: float) -> float:
	var visible_area := maxf(1.0, bounds.size.x * bounds.size.y)
	return target_area_side / sqrt(visible_area)


# 종류별 실루엣 차이까지 반영한 최종 본체 목표 크기를 자동 검사에서도 함께 사용한다.
static func body_visible_area_side(_turret_type_value: String, tier_value: int) -> float:
	var tier_index := clampi(tier_value - 1, 0, BODY_VISIBLE_AREA_SIDE_BY_TIER.size() - 1)
	return float(BODY_VISIBLE_AREA_SIDE_BY_TIER[tier_index])


static func body_target_bottom_y(turret_type_value: String) -> float:
	return BODY_BOTTOM_Y - STUN_HOVER_HEIGHT if turret_type_value == "STUN" else BODY_BOTTOM_Y


# 텍스처 중심 기준 Sprite2D에서 실제 그림의 아래 중앙을 원하는 월드 좌표에 고정한다.
static func _position_visible_bounds(texture: Texture2D, bounds: Rect2, target_bottom_center: Vector2, scale_value: float) -> Vector2:
	return _position_visible_bounds_for_size(texture.get_size(), bounds, target_bottom_center, scale_value)


static func _position_visible_bounds_for_size(texture_size: Vector2, bounds: Rect2, target_bottom_center: Vector2, scale_value: float) -> Vector2:
	var texture_center := texture_size * 0.5
	var visible_bottom_center := Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.y + bounds.size.y)
	return target_bottom_center - (visible_bottom_center - texture_center) * scale_value


# 새 밤 시작 시 공격 가능 상태와 시각 효과 타이머를 초기화한다.
func reset_for_wave() -> void:
	enabled = true
	cooldown_sec = 0.0
	stun_charge_remaining_sec = 0.0
	stun_charge_target = null
	ranged_burst_shots_remaining = 0
	ranged_burst_interval_remaining_sec = 0.0
	ranged_burst_target = null
	_update_stun_charge_visual()
	idle_animation_elapsed_sec = 0.0
	if body_sprite != null:
		body_sprite.frame = 0
	attack_animation_elapsed_sec = -1.0
	_set_attack_visual_active(false)
	_queue_effect_redraw()


# 실제 VFX 리소스가 들어오기 전까지 확장 원과 빛 점으로 짧은 머지 완료 연출을 재생한다.
func play_upgrade_effect() -> void:
	upgrade_effect_remaining_sec = UPGRADE_EFFECT_DURATION_SEC
	_queue_effect_redraw()

# 공격 간격을 갱신하고 같은 층·사거리 안의 최우선 몬스터를 자동 공격한다.
func _process(delta: float) -> void:
	_try_bind_idle_texture()
	_try_bind_attack_texture()
	_update_idle_animation(delta)
	_update_attack_animation(delta)
	if upgrade_effect_remaining_sec > 0.0:
		upgrade_effect_remaining_sec = maxf(0.0, upgrade_effect_remaining_sec - delta)
		_queue_effect_redraw()

	if not enabled:
		return
	_process_ranged_burst(delta)
	if stun_charge_remaining_sec > 0.0:
		stun_charge_remaining_sec = maxf(0.0, stun_charge_remaining_sec - delta)
		_update_stun_charge_visual()
		if stun_charge_remaining_sec <= 0.0:
			_finish_stun_attack()
		return

	cooldown_sec = maxf(0.0, cooldown_sec - delta)
	if cooldown_sec > 0.0:
		return
	if turret_type == "RANGED" and tier >= 3:
		var laser_targets := _select_ranged_front_targets()
		if laser_targets.is_empty():
			return
		_play_attack_animation()
		_fire_ranged_laser(laser_targets)
		cooldown_sec = attack_interval_sec
		return

	var target := _select_target()
	if target == null:
		return

	_play_attack_animation()
	match turret_type:
		"MELEE":
			_apply_melee_attack(target)
		"DOT":
			if tier == 1:
				_spawn_dot_fireball(target)
			else:
				_spawn_flamethrower(target)
		"STUN":
			stun_charge_target = target
			stun_charge_remaining_sec = STUN_CHARGE_DURATION_SEC
			_update_stun_charge_visual()
		"RANGED":
			_start_ranged_projectile_attack(target)
		_:
			_spawn_projectile(target)
	cooldown_sec = attack_interval_sec


func _update_idle_animation(delta: float) -> void:
	if not idle_visual_ready or body_sprite == null:
		return
	idle_animation_elapsed_sec = fmod(
		idle_animation_elapsed_sec + delta,
		IDLE_FRAME_DURATION_SEC * float(TowerVisualAssetsScript.IDLE_FRAME_COUNT)
	)
	body_sprite.frame = clampi(
		int(floor(idle_animation_elapsed_sec / IDLE_FRAME_DURATION_SEC)),
		0,
		TowerVisualAssetsScript.IDLE_FRAME_COUNT - 1
	)


func _play_attack_animation() -> void:
	if attack_sprite == null or not attack_visual_ready:
		return
	attack_animation_elapsed_sec = 0.0
	attack_sprite.frame = 0
	_set_attack_visual_active(true)


func _update_attack_animation(delta: float) -> void:
	if attack_animation_elapsed_sec < 0.0 or attack_sprite == null:
		return
	attack_animation_elapsed_sec += delta
	var animation_duration := ATTACK_FRAME_DURATION_SEC * float(TowerVisualAssetsScript.ATTACK_FRAME_COUNT)
	if attack_animation_elapsed_sec >= animation_duration:
		attack_animation_elapsed_sec = -1.0
		_set_attack_visual_active(false)
		return
	attack_sprite.frame = clampi(
		int(floor(attack_animation_elapsed_sec / ATTACK_FRAME_DURATION_SEC)),
		0,
		TowerVisualAssetsScript.ATTACK_FRAME_COUNT - 1
	)


func _set_attack_visual_active(active: bool) -> void:
	if attack_sprite != null:
		attack_sprite.visible = active
	if body_sprite != null:
		body_sprite.visible = not active


# SLOW/RANGED는 실제 이동 노드를 만들고 투사체가 몬스터에 닿을 때 피해·상태이상을 적용한다.
func _spawn_projectile(target: PrototypeMonster) -> void:
	var projectile := TowerProjectileScript.new() as PrototypeTowerProjectile
	get_parent().add_child(projectile)
	projectile.global_position = projectile_muzzle_global_position()
	projectile.setup(target, turret_type, damage, cc_duration, cc_value, tier)


# Tier 1은 기존 한 발, Tier 2는 같은 투사체를 0.1초 간격으로 세 발 발사한다.
func _start_ranged_projectile_attack(target: PrototypeMonster) -> void:
	_spawn_projectile(target)
	if tier == 2:
		ranged_burst_target = target
		ranged_burst_shots_remaining = 2
		ranged_burst_interval_remaining_sec = RANGED_BURST_SHOT_INTERVAL_SEC


func _process_ranged_burst(delta: float) -> void:
	if ranged_burst_shots_remaining <= 0:
		return
	ranged_burst_interval_remaining_sec -= delta
	while ranged_burst_shots_remaining > 0 and ranged_burst_interval_remaining_sec <= 0.0:
		var target := ranged_burst_target
		if not _target_is_attackable(target):
			target = _select_target()
			ranged_burst_target = target
		if target == null:
			ranged_burst_shots_remaining = 0
			ranged_burst_target = null
			return
		_spawn_projectile(target)
		ranged_burst_shots_remaining -= 1
		ranged_burst_interval_remaining_sec += RANGED_BURST_SHOT_INTERVAL_SEC
	if ranged_burst_shots_remaining <= 0:
		ranged_burst_target = null


# Tier 3은 주 포구 한 줄, Tier 4는 주 포구와 보조 포구 두 줄의 관통 레이저를 표시하고
# 포탑 오른쪽의 같은 층 모든 적에게 줄 수만큼 즉시 피해를 적용한다.
func _fire_ranged_laser(targets: Array[PrototypeMonster]) -> void:
	var source_positions := PackedVector2Array([_ranged_laser_muzzle_parent_position(false)])
	var hit_count := 1
	if tier >= 4:
		source_positions.append(_ranged_laser_muzzle_parent_position(true))
		hit_count = 2
	for target in targets:
		for hit_index in hit_count:
			if target.move_state == PrototypeMonster.MoveState.DEAD:
				break
			target.receive_turret_hit(damage, "RANGED", cc_duration, cc_value)

	var endpoint := source_positions[0] + Vector2.RIGHT * 120.0
	for target in targets:
		var target_right := target.position.x + target.body_visible_world_size.x * 0.5
		if target_right > endpoint.x:
			endpoint = Vector2(target_right + 18.0, target.position.y - 8.0)
	var laser_effect := RangedLaserEffectScript.new()
	get_parent().add_child(laser_effect)
	laser_effect.position = Vector2.ZERO
	laser_effect.setup(source_positions, endpoint)


# 원거리 스프라이트는 오른쪽을 바라본다. 실제 불투명 경계 안의 정규화 좌표로 포구를
# 계산해 Tier별 크기와 정지/대기 시트 로딩 여부가 달라도 레이저가 포구에서 시작한다.
func _ranged_laser_muzzle_parent_position(secondary: bool) -> Vector2:
	var bounds := TowerVisualAssetsScript.body_visible_bounds("RANGED", tier)
	var frame_size := body_sprite.texture.get_size() if body_sprite != null and body_sprite.texture != null else Vector2.ONE
	if idle_visual_ready:
		bounds = TowerVisualAssetsScript.idle_first_frame_visible_bounds("RANGED", tier)
		frame_size = TowerVisualAssetsScript.IDLE_FRAME_SIZE
	var normalized_point := Vector2(0.90, 0.34)
	if secondary and tier >= 4:
		normalized_point = Vector2(0.39, 0.51)
	var texture_point := bounds.position + bounds.size * normalized_point
	var tower_local_point := body_sprite.position + (texture_point - frame_size * 0.5) * body_sprite.scale
	return get_parent().to_local(to_global(tower_local_point))


# DOT는 일반 투사체 대신 포구에서 표적까지 짧게 뻗는 전용 화염방사를 생성한다.
func _spawn_flamethrower(target: PrototypeMonster) -> void:
	var flamethrower := TowerFlamethrowerScript.new() as PrototypeTowerFlamethrower
	get_parent().add_child(flamethrower)
	flamethrower.setup(self, target, damage, cc_duration, cc_value, tier)


func _spawn_dot_fireball(target: PrototypeMonster) -> void:
	var fireball := DotFireballProjectileScript.new()
	get_parent().add_child(fireball)
	fireball.global_position = projectile_muzzle_global_position()
	fireball.setup(target, damage, cc_duration, cc_value, tier)


# STUN 충전이 끝났을 때 표적이 여전히 같은 층·사거리 안에 있으면 낙뢰 히트스캔을 실행한다.
func _finish_stun_attack() -> void:
	var target := stun_charge_target as PrototypeMonster
	stun_charge_target = null
	_update_stun_charge_visual()
	if not _target_is_attackable(target):
		return
	_apply_hitscan_attack(target, "STUN")


# Tier 1은 기존 단일 표적 히트스캔을 유지하고, Tier 2부터 같은 층·수평 사거리 안의
# 모든 적을 한 번씩 공격한다. Tier 3은 피해 후 역방향 넉백, Tier 4는 피해 후 남은
# 체력이 20% 이하인 생존 적을 즉사시킨다.
func _apply_melee_attack(primary_target: PrototypeMonster) -> void:
	var targets: Array[PrototypeMonster] = [primary_target]
	if tier >= 2:
		targets = _select_targets_in_range()
	for target in targets:
		if not _target_is_attackable(target):
			continue
		target.receive_turret_hit(damage, "MELEE", cc_duration, cc_value)
		_spawn_hitscan_effect(target, "MELEE")
		if tier >= 4 and target.move_state != PrototypeMonster.MoveState.DEAD \
				and target.hp <= target.max_hp * MELEE_EXECUTION_HP_RATIO:
			target.take_damage(target.hp)
			_spawn_melee_execution_effect(target)
		elif tier >= 3 and target.move_state != PrototypeMonster.MoveState.DEAD:
			target.apply_knockback(MELEE_KNOCKBACK_DISTANCE_PX)


# 히트스캔 타입은 즉시 기존 피해 규칙을 적용하고 표적 위치에 별도 피격 이펙트를 생성한다.
func _apply_hitscan_attack(target: PrototypeMonster, attack_type: String) -> void:
	if not _target_is_attackable(target):
		return
	target.receive_turret_hit(damage, attack_type, cc_duration, cc_value)
	_spawn_hitscan_effect(target, attack_type)


func _spawn_hitscan_effect(target: PrototypeMonster, attack_type: String) -> void:
	var hit_effect := TowerHitEffectScript.new() as PrototypeTowerHitEffect
	get_parent().add_child(hit_effect)
	# 같은 전장 부모의 로컬 좌표를 사용해 전장 축소율이 접지 오프셋에 중복 적용되지 않게 한다.
	hit_effect.position = target.position
	var target_height_world := 0.0
	if attack_type == "STUN":
		hit_effect.position.y += target.body_bottom_offset_y
		target_height_world = target.body_visible_world_size.y
	hit_effect.setup(attack_type, tier, target_height_world)


func _spawn_melee_execution_effect(target: PrototypeMonster) -> void:
	var execution_effect := MeleeExecutionEffectScript.new()
	get_parent().add_child(execution_effect)
	execution_effect.position = target.position - Vector2(0.0, target.body_bottom_offset_y * 0.35)
	execution_effect.setup()


func projectile_muzzle_global_position() -> Vector2:
	var local_muzzle := Vector2(0.0, -58.0)
	if body_sprite != null:
		local_muzzle = body_sprite.position + Vector2(0.0, -12.0)
	return to_global(local_muzzle)


func _target_is_attackable(target: PrototypeMonster) -> bool:
	if not is_instance_valid(target) or not target.is_in_combat_floor():
		return false
	if target.current_combat_floor() != floor_index:
		return false
	return absf(global_position.x - target.global_position.x) <= attack_range_px


# 같은 전투층에서 수평 사거리 안에 있으며 코어 진행도가 가장 높은 몬스터를 선택한다.
# 포탑과 경로의 수직 좌표 차이는 화면 연출용이므로 사거리 계산에서 제외한다.
func _select_target() -> PrototypeMonster:
	var selected: PrototypeMonster = null
	var best_progress := -INF
	for node in get_tree().get_nodes_in_group("prototype_monsters"):
		var monster := node as PrototypeMonster
		if monster == null or not monster.is_in_combat_floor():
			continue
		if monster.current_combat_floor() != floor_index:
			continue
		var horizontal_distance := absf(global_position.x - monster.global_position.x)
		if horizontal_distance > attack_range_px:
			continue
		var progress := monster.progress_score()
		if progress > best_progress:
			best_progress = progress
			selected = monster
	return selected


func _select_targets_in_range() -> Array[PrototypeMonster]:
	var targets: Array[PrototypeMonster] = []
	for node in get_tree().get_nodes_in_group("prototype_monsters"):
		var monster := node as PrototypeMonster
		if _target_is_attackable(monster):
			targets.append(monster)
	return targets


# 포탑 외형의 전방인 오른쪽에 있으며 같은 전투층에 남아 있는 모든 적을 반환한다.
# Tier 3·4 레이저는 기존 사거리 제한을 대체하므로 수평 거리 상한을 적용하지 않는다.
func _select_ranged_front_targets() -> Array[PrototypeMonster]:
	var targets: Array[PrototypeMonster] = []
	for node in get_tree().get_nodes_in_group("prototype_monsters"):
		var monster := node as PrototypeMonster
		if monster == null or not monster.is_in_combat_floor():
			continue
		if monster.current_combat_floor() != floor_index:
			continue
		if monster.global_position.x <= global_position.x:
			continue
		targets.append(monster)
	return targets


# Web에서도 동적 draw 콜백 없이 STUN 충전 이미지를 표시한다.
func _update_stun_charge_visual() -> void:
	if stun_charge_sprite == null:
		return
	stun_charge_sprite.visible = stun_charge_remaining_sec > 0.0
	if not stun_charge_sprite.visible:
		return
	var charge_progress := 1.0 - stun_charge_remaining_sec / STUN_CHARGE_DURATION_SEC
	var charge_size := Vector2.ONE * lerpf(108.0, 144.0, charge_progress)
	stun_charge_sprite.position = body_sprite.position if body_sprite != null else Vector2(0.0, -100.0)
	stun_charge_sprite.scale = charge_size / stun_charge_sprite.texture.get_size()
	stun_charge_sprite.modulate.a = 0.70 + sin(charge_progress * TAU * 2.0) * 0.16


# 타워 이미지는 자식 Sprite2D가 그리며, 여기서는 머지 피드백만 그린다.
func _draw() -> void:
	if OS.has_feature("web"):
		return
	# 머지 직후 바깥으로 퍼지는 링과 방사형 빛 점을 그려 승급 순간을 강조한다.
	if upgrade_effect_remaining_sec > 0.0:
		var effect_progress := 1.0 - upgrade_effect_remaining_sec / UPGRADE_EFFECT_DURATION_SEC
		var effect_color := tower_color.lightened(0.55)
		effect_color.a = 1.0 - effect_progress
		var effect_radius := lerpf(30.0, 64.0, effect_progress)
		draw_arc(Vector2.ZERO, effect_radius, 0.0, TAU, 40, effect_color, 5.0)
		for spark_index in 8:
			var spark_angle := TAU * float(spark_index) / 8.0
			var spark_position := Vector2.from_angle(spark_angle) * effect_radius
			draw_circle(spark_position, 4.0 * (1.0 - effect_progress * 0.6), effect_color)


func _queue_effect_redraw() -> void:
	if not OS.has_feature("web"):
		queue_redraw()


# 커진 스프라이트를 가장자리에서도 잡을 수 있도록 선택 반경도 Tier와 함께 확장한다.
func get_interaction_radius() -> float:
	return body_visible_area_side(turret_type, tier) * 0.60
