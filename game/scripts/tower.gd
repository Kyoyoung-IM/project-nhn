class_name PrototypeTower
extends Node2D

# 한 개의 배치된 터렛 오브젝트를 담당한다.
# 데이터베이스에서 정규화된 설정을 받아 표적 선택, 공격과 타입별 연출을 처리한다.
# 이 분기에서 터렛은 체력과 사망 상태가 없는 고정 불파괴 오브젝트다.

const TowerVisualAssetsScript := preload("res://scripts/tower_visual_assets.gd")
const TowerProjectileScript := preload("res://scripts/tower_projectile.gd")
const TowerFlamethrowerScript := preload("res://scripts/tower_flamethrower.gd")
const TowerHitEffectScript := preload("res://scripts/tower_hit_effect.gd")
const STUN_CHARGE_AURA_TEXTURE := preload("res://assets/combat_vfx/stun_charge_aura_v2.png")

# Tier가 높아질수록 본체가 조금씩 커져 머지 결과를 실루엣만으로도 구분할 수 있다.
# 이 값은 기존 더미 도형의 반경과 무관한 실제 스프라이트 표시 크기다.
# 각 Tier의 실제 불투명 그림 면적이 아래 정사각형과 같은 면적이 되도록 정규화한다.
# 캔버스 크기가 아닌 육안 면적을 기준으로 하므로 모든 포탑이 단계별로 일정하게 커진다.
const BODY_VISIBLE_AREA_SIDE_BY_TIER := [132.0, 154.0, 178.0, 205.0]
# 낮고 넓은 DOT Tier 4 실루엣은 같은 면적만으로는 Tier 3보다 작게 인식되므로 별도 목표를 사용한다.
const DOT_TIER_4_BODY_VISIBLE_AREA_SIDE := 244.0
const BODY_BOTTOM_Y := 100.0

# 지속 피해 불꽃도 실제 불투명 영역을 기준으로 커지고, 본체 윗면과 조금 겹치게 결합한다.
const DOT_EFFECT_VISIBLE_AREA_SIDE_BY_TIER := [82.0, 96.0, 112.0, 132.0]
const DOT_TIER_4_EFFECT_VISIBLE_AREA_SIDE := 156.0
const DOT_EFFECT_BODY_OVERLAP_BY_TIER := [18.0, 22.0, 60.0, 76.0]
const STUN_LIGHTNING_BODY_WIDTH_RATIO := 1.14
# 기존 144px 부유 높이의 2/3 지점으로 내려 발판과의 시각적 연결을 강화한다.
const STUN_HOVER_HEIGHT := 96.0
const STUN_HOVER_AMPLITUDE := 4.0
# STUN 공격의 충전 시간은 피해 밸런스와 분리된 시각 전용 PLACEHOLDER 값이다.
const STUN_CHARGE_DURATION_SEC := 0.38

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

# 이 터렛을 만들기 위해 실제로 지불한 골드 총액이다.
# 머지할 때 두 재료의 값을 합쳐 상위 Tier에 넘기므로 판매가는 원본 구매 이력을 보존한다.
var invested_gold: int = 0

# 공격 재사용 대기시간과 기절 포탑의 충전 상태다.
var cooldown_sec: float = 0.0
var enabled: bool = true
var stun_charge_remaining_sec: float = 0.0
var stun_charge_target: Node2D

# 머지 직후 상위 Tier가 생성됐음을 보여주는 코드 기반 승급 연출 시간이다.
const UPGRADE_EFFECT_DURATION_SEC := 0.7
var upgrade_effect_remaining_sec: float = 0.0

# 본체와 상시 이펙트는 독립 노드다. 불꽃과 번개를 공격·상태 연출로 교체할 때
# 본체 텍스처를 다시 만들지 않고 이 노드만 애니메이션하거나 숨길 수 있다.
var body_sprite: Sprite2D
var body_front_sprite: Sprite2D
var idle_effect_sprite: Sprite2D
var body_base_position := Vector2.ZERO
var idle_effect_base_position := Vector2.ZERO
var idle_effect_base_scale := Vector2.ONE
var visual_elapsed_sec: float = 0.0


# 로더가 만든 내부 설정을 복사하고 해당 층의 터렛 그룹에 등록한다.
func setup(config: Dictionary, assigned_floor_index: int, assigned_invested_gold: int = 0) -> void:
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
	invested_gold = maxi(0, assigned_invested_gold)
	cooldown_sec = 0.0
	_refresh_visual_nodes()
	add_to_group("prototype_towers")
	queue_redraw()


# 테스트 밸런스 편집에서 ID·Tier·투자금·현재 쿨다운은 보존하고 전투 수치만 즉시 갱신한다.
func apply_runtime_balance(config: Dictionary) -> void:
	damage = float(config.get("damage", damage))
	attack_interval_sec = maxf(0.001, float(config.get("attack_interval_sec", attack_interval_sec)))
	attack_range_px = maxf(0.0, float(config.get("range_px", attack_range_px)))
	cc_duration = maxf(0.0, float(config.get("cc_duration", cc_duration)))
	cc_value = float(config.get("cc_value", cc_value))
	cooldown_sec = minf(cooldown_sec, attack_interval_sec)
	queue_redraw()


# 승인된 타입·Tier별 본체와 분리 이펙트 텍스처를 자식 Sprite2D에 연결한다.
func _refresh_visual_nodes() -> void:
	if body_sprite == null:
		body_sprite = Sprite2D.new()
		body_sprite.name = "BodySprite"
		body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(body_sprite)
	if idle_effect_sprite == null:
		idle_effect_sprite = Sprite2D.new()
		idle_effect_sprite.name = "IdleEffectSprite"
		idle_effect_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(idle_effect_sprite)
	if body_front_sprite == null:
		body_front_sprite = Sprite2D.new()
		body_front_sprite.name = "BodyFrontSprite"
		body_front_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(body_front_sprite)

	var tier_index := clampi(tier - 1, 0, BODY_VISIBLE_AREA_SIDE_BY_TIER.size() - 1)
	var body_bottom_y := BODY_BOTTOM_Y - (STUN_HOVER_HEIGHT if turret_type == "STUN" else 0.0)
	body_sprite.texture = TowerVisualAssetsScript.body_texture(turret_type, tier)
	var body_bounds: Rect2 = TowerVisualAssetsScript.body_visible_bounds(turret_type, tier)
	var body_scale := _scale_for_visible_area(body_bounds, body_visible_area_side(turret_type, tier))
	body_base_position = _position_visible_bounds(body_sprite.texture, body_bounds, Vector2(0.0, body_bottom_y), body_scale)
	body_sprite.position = body_base_position
	body_sprite.scale = Vector2.ONE * body_scale
	body_sprite.z_index = 0
	body_front_sprite.visible = false
	body_front_sprite.texture = null
	if turret_type == "DOT" and tier >= 3:
		var front_region: Rect2 = TowerVisualAssetsScript.dot_front_region(tier)
		body_front_sprite.texture = TowerVisualAssetsScript.dot_front_texture(tier)
		# AtlasTexture 중심이 원본 중심과 달라지므로 잘라낸 영역의 중심 차이만큼 위치를 보정한다.
		body_front_sprite.position = body_base_position + (front_region.get_center() - body_sprite.texture.get_size() * 0.5) * body_scale
		body_front_sprite.scale = Vector2.ONE * body_scale
		body_front_sprite.z_index = 2
		body_front_sprite.visible = true

	idle_effect_sprite.visible = false
	idle_effect_sprite.texture = null
	idle_effect_sprite.modulate = Color.WHITE
	if turret_type == "DOT":
		idle_effect_sprite.texture = TowerVisualAssetsScript.dot_flame_texture(tier)
		var effect_bounds: Rect2 = TowerVisualAssetsScript.dot_flame_visible_bounds(tier)
		var effect_scale := _scale_for_visible_area(effect_bounds, dot_effect_visible_area_side(tier))
		var body_visible_top_y := _visible_top_y(body_sprite.texture, body_bounds, body_base_position, body_scale)
		var effect_bottom_y: float = body_visible_top_y + float(DOT_EFFECT_BODY_OVERLAP_BY_TIER[tier_index])
		idle_effect_base_position = _position_visible_bounds(idle_effect_sprite.texture, effect_bounds, Vector2(0.0, effect_bottom_y), effect_scale)
		idle_effect_sprite.position = idle_effect_base_position
		idle_effect_base_scale = Vector2.ONE * effect_scale
		idle_effect_sprite.scale = idle_effect_base_scale
		idle_effect_sprite.z_index = 1
		idle_effect_sprite.visible = true
	elif turret_type == "STUN" and tier >= 4:
		idle_effect_sprite.texture = TowerVisualAssetsScript.stun_lightning_texture()
		var lightning_bounds: Rect2 = TowerVisualAssetsScript.stun_lightning_visible_bounds()
		var visible_body_width := body_bounds.size.x * body_scale
		var lightning_scale := visible_body_width * STUN_LIGHTNING_BODY_WIDTH_RATIO / lightning_bounds.size.x
		var body_visible_center := _visible_center(body_sprite.texture, body_bounds, body_base_position, body_scale)
		idle_effect_base_position = _position_visible_center(idle_effect_sprite.texture, lightning_bounds, body_visible_center, lightning_scale)
		idle_effect_sprite.position = idle_effect_base_position
		idle_effect_base_scale = Vector2.ONE * lightning_scale
		idle_effect_sprite.scale = idle_effect_base_scale
		idle_effect_sprite.z_index = -1
		idle_effect_sprite.visible = true


# 경계 상자의 면적이 지정된 정사각형 면적과 같아지도록 균일 배율을 계산한다.
static func _scale_for_visible_area(bounds: Rect2, target_area_side: float) -> float:
	var visible_area := maxf(1.0, bounds.size.x * bounds.size.y)
	return target_area_side / sqrt(visible_area)


# 종류별 실루엣 차이까지 반영한 최종 본체 목표 크기를 자동 검사에서도 함께 사용한다.
static func body_visible_area_side(turret_type_value: String, tier_value: int) -> float:
	var tier_index := clampi(tier_value - 1, 0, BODY_VISIBLE_AREA_SIDE_BY_TIER.size() - 1)
	if turret_type_value == "DOT" and tier_index == 3:
		return DOT_TIER_4_BODY_VISIBLE_AREA_SIDE
	return float(BODY_VISIBLE_AREA_SIDE_BY_TIER[tier_index])


static func dot_effect_visible_area_side(tier_value: int) -> float:
	var tier_index := clampi(tier_value - 1, 0, DOT_EFFECT_VISIBLE_AREA_SIDE_BY_TIER.size() - 1)
	if tier_index == 3:
		return DOT_TIER_4_EFFECT_VISIBLE_AREA_SIDE
	return float(DOT_EFFECT_VISIBLE_AREA_SIDE_BY_TIER[tier_index])


# 텍스처 중심 기준 Sprite2D에서 실제 그림의 아래 중앙을 원하는 월드 좌표에 고정한다.
static func _position_visible_bounds(texture: Texture2D, bounds: Rect2, target_bottom_center: Vector2, scale_value: float) -> Vector2:
	var texture_center := texture.get_size() * 0.5
	var visible_bottom_center := Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.y + bounds.size.y)
	return target_bottom_center - (visible_bottom_center - texture_center) * scale_value


static func _position_visible_center(texture: Texture2D, bounds: Rect2, target_center: Vector2, scale_value: float) -> Vector2:
	var texture_center := texture.get_size() * 0.5
	var visible_center := bounds.position + bounds.size * 0.5
	return target_center - (visible_center - texture_center) * scale_value


static func _visible_center(texture: Texture2D, bounds: Rect2, sprite_position: Vector2, scale_value: float) -> Vector2:
	return sprite_position + (bounds.position + bounds.size * 0.5 - texture.get_size() * 0.5) * scale_value


static func _visible_top_y(texture: Texture2D, bounds: Rect2, sprite_position: Vector2, scale_value: float) -> float:
	return sprite_position.y + (bounds.position.y - texture.get_size().y * 0.5) * scale_value


# 새 밤 시작 시 공격 가능 상태와 시각 효과 타이머를 초기화한다.
func reset_for_wave() -> void:
	enabled = true
	cooldown_sec = 0.0
	stun_charge_remaining_sec = 0.0
	stun_charge_target = null
	queue_redraw()


# 실제 VFX 리소스가 들어오기 전까지 확장 원과 빛 점으로 짧은 머지 완료 연출을 재생한다.
func play_upgrade_effect() -> void:
	upgrade_effect_remaining_sec = UPGRADE_EFFECT_DURATION_SEC
	queue_redraw()

# 공격 간격을 갱신하고 같은 층·사거리 안의 최우선 몬스터를 자동 공격한다.
func _process(delta: float) -> void:
	visual_elapsed_sec += delta
	_update_idle_effect_animation()
	if upgrade_effect_remaining_sec > 0.0:
		upgrade_effect_remaining_sec = maxf(0.0, upgrade_effect_remaining_sec - delta)
		queue_redraw()

	if not enabled:
		return
	if stun_charge_remaining_sec > 0.0:
		stun_charge_remaining_sec = maxf(0.0, stun_charge_remaining_sec - delta)
		queue_redraw()
		if stun_charge_remaining_sec <= 0.0:
			_finish_stun_attack()
		return

	cooldown_sec = maxf(0.0, cooldown_sec - delta)
	if cooldown_sec > 0.0:
		return

	var target := _select_target()
	if target == null:
		return

	match turret_type:
		"MELEE":
			_apply_hitscan_attack(target, "MELEE")
		"DOT":
			_spawn_flamethrower(target)
		"STUN":
			stun_charge_target = target
			stun_charge_remaining_sec = STUN_CHARGE_DURATION_SEC
			queue_redraw()
		_:
			_spawn_projectile(target)
	cooldown_sec = attack_interval_sec


# SLOW/RANGED는 실제 이동 노드를 만들고 투사체가 몬스터에 닿을 때 피해·상태이상을 적용한다.
func _spawn_projectile(target: PrototypeMonster) -> void:
	var projectile := TowerProjectileScript.new() as PrototypeTowerProjectile
	get_parent().add_child(projectile)
	projectile.global_position = projectile_muzzle_global_position()
	projectile.setup(target, turret_type, damage, cc_duration, cc_value, tier)


# DOT는 일반 투사체 대신 포구에서 표적까지 짧게 뻗는 전용 화염방사를 생성한다.
func _spawn_flamethrower(target: PrototypeMonster) -> void:
	var flamethrower := TowerFlamethrowerScript.new() as PrototypeTowerFlamethrower
	get_parent().add_child(flamethrower)
	flamethrower.setup(self, target, damage, cc_duration, cc_value, tier)


# STUN 충전이 끝났을 때 표적이 여전히 같은 층·사거리 안에 있으면 낙뢰 히트스캔을 실행한다.
func _finish_stun_attack() -> void:
	var target := stun_charge_target as PrototypeMonster
	stun_charge_target = null
	if not _target_is_attackable(target):
		return
	_apply_hitscan_attack(target, "STUN")


# 히트스캔 타입은 즉시 기존 피해 규칙을 적용하고 표적 위치에 별도 피격 이펙트를 생성한다.
func _apply_hitscan_attack(target: PrototypeMonster, attack_type: String) -> void:
	if not _target_is_attackable(target):
		return
	target.receive_turret_hit(damage, attack_type, cc_duration, cc_value)
	var hit_effect := TowerHitEffectScript.new() as PrototypeTowerHitEffect
	get_parent().add_child(hit_effect)
	# The lightning texture includes a ground impact. Anchor STUN at the target's
	# floor contact instead of its body center so the whole bolt stays legible.
	hit_effect.global_position = target.global_position
	if attack_type == "STUN":
		hit_effect.global_position.y += target.body_bottom_offset_y
	hit_effect.setup(attack_type, tier)


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


# 분리된 불꽃과 번개에 아주 작은 크기·밝기 변화를 주어 정지 이미지처럼 굳어 보이지 않게 한다.
func _update_idle_effect_animation() -> void:
	# 구름형 기절 포탑은 발판에서 떨어진 채 천천히 위아래로 부유한다.
	if turret_type == "STUN" and body_sprite != null:
		var hover_offset := sin(visual_elapsed_sec * 2.4) * STUN_HOVER_AMPLITUDE
		body_sprite.position = body_base_position + Vector2(0.0, hover_offset)
		if idle_effect_sprite != null and idle_effect_sprite.visible:
			idle_effect_sprite.position = idle_effect_base_position + Vector2(0.0, hover_offset)
	if idle_effect_sprite == null or not idle_effect_sprite.visible:
		return
	if turret_type == "DOT":
		var pulse := sin(visual_elapsed_sec * 5.2) * 0.035
		idle_effect_sprite.scale = idle_effect_base_scale * (1.0 + pulse)
		idle_effect_sprite.modulate = Color(1.0, 0.96 + pulse * 0.5, 0.86, 1.0)
	elif turret_type == "STUN" and tier >= 4:
		var pulse := sin(visual_elapsed_sec * 7.5) * 0.045
		idle_effect_sprite.scale = idle_effect_base_scale * (1.0 + pulse)
		idle_effect_sprite.modulate = Color(0.92, 0.92, 1.0, 0.74 + pulse * 2.0)


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


# 본체와 상시 효과는 자식 Sprite2D가 그리며, 여기서는 STUN 충전과 머지 피드백만 그린다.
func _draw() -> void:
	if stun_charge_remaining_sec > 0.0:
		var charge_progress := 1.0 - stun_charge_remaining_sec / STUN_CHARGE_DURATION_SEC
		var charge_center := body_sprite.position if body_sprite != null else Vector2(0.0, -100.0)
		var charge_size := Vector2.ONE * lerpf(108.0, 144.0, charge_progress)
		var charge_alpha := 0.70 + sin(charge_progress * TAU * 2.0) * 0.16
		draw_texture_rect(
			STUN_CHARGE_AURA_TEXTURE,
			Rect2(charge_center - charge_size * 0.5, charge_size),
			false,
			Color(1.0, 1.0, 1.0, charge_alpha)
		)
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


# 커진 스프라이트를 가장자리에서도 잡을 수 있도록 선택 반경도 Tier와 함께 확장한다.
func get_interaction_radius() -> float:
	return body_visible_area_side(turret_type, tier) * 0.60
