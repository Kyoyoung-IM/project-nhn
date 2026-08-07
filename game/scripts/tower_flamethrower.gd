class_name PrototypeTowerFlamethrower
extends Node2D

# 지속 포탑 전용 화염방사 공격이다. 일반 투사체처럼 한 점이 날아가지 않고,
# 포구에서 표적까지 짧은 시간 동안 화염 줄기가 뻗은 뒤 피해와 화상을 적용한다.
const FLAME_TEXTURE := preload("res://assets/combat_vfx/flamethrower_dot_v2.png")
const ATTACK_DURATION_SEC := 0.56
const CONTACT_TIME_SEC := 0.20
const FADE_START_TIME_SEC := 0.40
const BASE_FLAME_HEIGHT_PX := 120.0

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


func setup(source_node: Node2D, target_node: Node2D, attack_damage: float, duration: float, value: float, attack_tier: int) -> void:
	source_tower = source_node
	target = target_node
	damage = attack_damage
	cc_duration = duration
	cc_value = value
	tier = clampi(attack_tier, 1, 4)
	fired_floor_index = _target_combat_floor()
	z_index = 40
	add_to_group("tower_flamethrowers")
	_update_transform_from_combatants()
	_queue_effect_redraw()


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
	_queue_effect_redraw()


func _update_transform_from_combatants() -> void:
	var muzzle := source_tower.global_position
	if source_tower.has_method("projectile_muzzle_global_position"):
		muzzle = source_tower.call("projectile_muzzle_global_position") as Vector2
	var destination := target.global_position + Vector2(0.0, -8.0)
	var flame_vector := destination - muzzle
	global_position = muzzle
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


func _draw() -> void:
	if OS.has_feature("web"):
		return
	var reach_progress := clampf(elapsed_sec / CONTACT_TIME_SEC, 0.0, 1.0)
	# Keep the completed flame readable briefly before fading. At high game speed
	# the previous immediate fade could disappear between rendered frames.
	var fade_progress := clampf((elapsed_sec - FADE_START_TIME_SEC) / maxf(0.01, ATTACK_DURATION_SEC - FADE_START_TIME_SEC), 0.0, 1.0)
	var flame_length := target_distance_px * smoothstep(0.0, 1.0, reach_progress)
	var flame_height := BASE_FLAME_HEIGHT_PX * (1.0 + float(tier - 1) * 0.06)
	var flame_alpha := 1.0 - fade_progress * 0.68
	draw_texture_rect(
		FLAME_TEXTURE,
		Rect2(Vector2(0.0, -flame_height * 0.5), Vector2(maxf(1.0, flame_length), flame_height)),
		false,
		Color(1.0, 1.0, 1.0, flame_alpha)
	)


func _queue_effect_redraw() -> void:
	if not OS.has_feature("web"):
		queue_redraw()
