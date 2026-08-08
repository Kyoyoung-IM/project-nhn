class_name PrototypeTowerFlamethrower
extends Node2D

# 지속 포탑 전용 화염방사 공격이다. 일반 투사체처럼 한 점이 날아가지 않고,
# 포구에서 표적까지 짧은 시간 동안 화염 줄기가 뻗은 뒤 피해와 화상을 적용한다.
const FLAME_TEXTURE := preload("res://assets/combat_vfx/flamethrower_dot_v2.png")
const ATTACK_DURATION_SEC := 0.56
const CONTACT_TIME_SEC := 0.20
const FADE_START_TIME_SEC := 0.40
const BASE_FLAME_HEIGHT_PX := 120.0
# 불투명 경계의 끝점만 적 중심에 맞추면 끝부분의 성긴 알파 때문에 떨어져 보일 수 있다.
# 이 이펙트만 가로로 더 늘려 적 중심을 지나도록 겹쳐 직접 접촉을 보장한다.
const TARGET_CENTER_OVERLAP_PX := 48.0
# 원본 505x317 PNG에서 실제 불투명 화염이 차지하는 영역이다. 캔버스 투명 여백이
# 포구와 표적 사이의 시각 길이를 줄이지 않도록 이 경계를 기준으로 배율을 계산한다.
const FLAME_VISIBLE_BOUNDS := Rect2(28.0, 28.0, 449.0, 261.0)

var source_tower: Node2D
var target: Node2D
var damage: float = 0.0
var cc_duration: float = 0.0
var cc_value: float = 0.0
var tier: int = 1
var elapsed_sec: float = 0.0
var target_distance_px: float = 1.0
var fired_floor_index: int = -1
var damage_applied: bool = false
var flame_sprite: Sprite2D


func setup(source_node: Node2D, target_node: Node2D, attack_damage: float, duration: float, value: float, attack_tier: int) -> void:
	source_tower = source_node
	target = target_node
	damage = attack_damage
	cc_duration = duration
	cc_value = value
	tier = clampi(attack_tier, 1, 4)
	fired_floor_index = _target_combat_floor()
	z_index = 40
	_configure_flame_sprite()
	add_to_group("tower_flamethrowers")
	_update_transform_from_combatants()
	_update_flame_visual()


func _process(delta: float) -> void:
	if not is_instance_valid(source_tower) or not _target_remains_on_fired_floor():
		queue_free()
		return

	elapsed_sec += delta
	_update_transform_from_combatants()
	if not damage_applied and elapsed_sec >= CONTACT_TIME_SEC:
		damage_applied = true
		if target.has_method("receive_turret_hit"):
			target.call("receive_turret_hit", damage, "DOT", cc_duration, cc_value)
	if elapsed_sec >= ATTACK_DURATION_SEC:
		queue_free()
		return
	_update_flame_visual()


func _update_transform_from_combatants() -> void:
	var muzzle := source_tower.global_position
	if source_tower.has_method("projectile_muzzle_global_position"):
		muzzle = source_tower.call("projectile_muzzle_global_position") as Vector2
	# 몬스터 노드 원점은 불투명 본체 그림의 중심에 정렬돼 있으므로 추가 오프셋 없이 사용한다.
	var destination := target.global_position
	# 화염은 전장 엔티티 부모의 자식이며 이 부모는 전체 화면 표시를 위해 0.5배 축소된다.
	# 전역 화면 거리로 길이를 만든 뒤 부모 배율을 다시 받지 않도록 두 점을 부모 로컬
	# 좌표로 변환해 위치·각도·길이를 모두 같은 좌표계에서 계산한다.
	var parent_2d := get_parent() as Node2D
	var local_muzzle := parent_2d.to_local(muzzle) if parent_2d != null else muzzle
	var local_destination := parent_2d.to_local(destination) if parent_2d != null else destination
	var flame_vector := local_destination - local_muzzle
	position = local_muzzle
	rotation = flame_vector.angle()
	target_distance_px = maxf(1.0, flame_vector.length())


func _target_remains_on_fired_floor() -> bool:
	if not is_instance_valid(target) or not target.has_method("is_in_combat_floor"):
		return false
	return bool(target.call("is_in_combat_floor")) and _target_combat_floor() == fired_floor_index


func _target_combat_floor() -> int:
	if not is_instance_valid(target) or not target.has_method("current_combat_floor"):
		return -1
	return int(target.call("current_combat_floor"))


func _configure_flame_sprite() -> void:
	flame_sprite = Sprite2D.new()
	flame_sprite.name = "FlameSprite"
	flame_sprite.texture = FLAME_TEXTURE
	flame_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(flame_sprite)


func _update_flame_visual() -> void:
	if flame_sprite == null:
		return
	# Keep the completed flame readable briefly before fading. At high game speed
	# the previous immediate fade could disappear between rendered frames.
	var fade_progress := clampf((elapsed_sec - FADE_START_TIME_SEC) / maxf(0.01, ATTACK_DURATION_SEC - FADE_START_TIME_SEC), 0.0, 1.0)
	# 생성 첫 프레임부터 전체 길이를 표시해 공격 중간 프레임에서도 적과 끊겨 보이지 않게 한다.
	var flame_length := target_distance_px + TARGET_CENTER_OVERLAP_PX
	var flame_height := BASE_FLAME_HEIGHT_PX * (1.0 + float(tier - 1) * 0.06)
	var flame_alpha := 1.0 - fade_progress * 0.68
	var texture_size := flame_sprite.texture.get_size()
	# 기획 확정에 따라 원본 좌→우 방향을 유지한다. 좁은 왼쪽 끝을 포구(0px),
	# 넓은 오른쪽 불투명 끝은 표적 중심을 지나도록 가로로 늘린다. 이 이펙트는
	# 명시적으로 원본 종횡비를 보존하지 않아 적 본체 위에 직접 포개져 보이게 한다.
	var flame_scale := Vector2(
		maxf(1.0, flame_length) / FLAME_VISIBLE_BOUNDS.size.x,
		flame_height / FLAME_VISIBLE_BOUNDS.size.y
	)
	var visible_source_from_center := Vector2(
		FLAME_VISIBLE_BOUNDS.position.x - texture_size.x * 0.5,
		FLAME_VISIBLE_BOUNDS.get_center().y - texture_size.y * 0.5
	)
	flame_sprite.scale = flame_scale
	flame_sprite.position = -visible_source_from_center * flame_scale
	flame_sprite.modulate.a = flame_alpha
