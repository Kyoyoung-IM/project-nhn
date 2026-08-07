class_name PrototypeTowerProjectile
extends Node2D

# 둔화/원거리 포탑이 발사하는 실제 이동 투사체다.
# 이미지에는 고정 트레일을 포함하지 않고, 매 프레임 기록한 이동 좌표로 궤적을 그린다.
const PROJECTILE_SPEED_PX_SEC := {
	"SLOW": 720.0,
	"RANGED": 900.0,
}
const HIT_DISTANCE_PX := 18.0
const MAX_LIFETIME_SEC := 3.0
const IMPACT_EFFECT_SEC := 0.18
const MAX_TRAIL_POINT_COUNT := 10
const TRAIL_POINT_INTERVAL_PX := 10.0

const SLOW_PROJECTILE_TEXTURE := preload("res://assets/combat_vfx/projectile_slow_snowball_v2.png")
const RANGED_PROJECTILE_TEXTURE := preload("res://assets/combat_vfx/projectile_ranged_pea_v2.png")

var target: Node2D
var source_type: String = "RANGED"
var damage: float = 0.0
var cc_duration: float = 0.0
var cc_value: float = 0.0
var tier: int = 1
var speed_px_sec: float = 900.0
var elapsed_sec: float = 0.0
var impact_remaining_sec: float = 0.0
var impacted: bool = false
var travel_direction := Vector2.RIGHT
var fired_floor_index: int = -1
var trail_global_points := PackedVector2Array()


# 발사 시점의 전투층을 저장해 표적이 층 이동을 시작하면 즉시 추적과 피해를 취소한다.
func setup(target_node: Node2D, attack_type: String, attack_damage: float, duration: float, value: float, attack_tier: int) -> void:
	target = target_node
	source_type = attack_type
	damage = attack_damage
	cc_duration = duration
	cc_value = value
	tier = clampi(attack_tier, 1, 4)
	speed_px_sec = float(PROJECTILE_SPEED_PX_SEC.get(source_type, 900.0))
	fired_floor_index = _target_combat_floor()
	trail_global_points = PackedVector2Array([global_position])
	z_index = 40
	add_to_group("tower_projectiles")
	_queue_effect_redraw()


func _process(delta: float) -> void:
	if impacted:
		impact_remaining_sec = maxf(0.0, impact_remaining_sec - delta)
		_queue_effect_redraw()
		if impact_remaining_sec <= 0.0:
			queue_free()
		return

	elapsed_sec += delta
	if elapsed_sec >= MAX_LIFETIME_SEC or not _target_remains_on_fired_floor():
		queue_free()
		return

	var destination := target.global_position + Vector2(0.0, -8.0)
	var to_target := destination - global_position
	if to_target.length() <= maxf(HIT_DISTANCE_PX, speed_px_sec * delta):
		global_position = destination
		_record_trail_point(true)
		_apply_impact()
		return

	travel_direction = to_target.normalized()
	global_position += travel_direction * speed_px_sec * delta
	rotation = travel_direction.angle()
	_record_trail_point(false)
	_queue_effect_redraw()


# 층 전환이 시작된 표적에는 기존 층에서 발사된 투사체가 따라가지 않는다.
func _target_remains_on_fired_floor() -> bool:
	if not is_instance_valid(target) or not target.has_method("is_in_combat_floor"):
		return false
	return bool(target.call("is_in_combat_floor")) and _target_combat_floor() == fired_floor_index


func _target_combat_floor() -> int:
	if not is_instance_valid(target) or not target.has_method("current_combat_floor"):
		return -1
	return int(target.call("current_combat_floor"))


func _record_trail_point(force_append: bool) -> void:
	var should_append := trail_global_points.is_empty() or force_append
	if not should_append:
		var last_point_index := trail_global_points.size() - 1
		should_append = trail_global_points[last_point_index].distance_to(global_position) >= TRAIL_POINT_INTERVAL_PX
	if not should_append:
		return

	# 한 프레임에는 한 점만 추가되므로 반복 제거가 필요 없다. Web 빌드는 메인 스레드에서
	# 실행되며, 배열 축소가 실패하는 예외 상황에서도 무한 반복으로 게임 전체가 멎지 않게 한다.
	if trail_global_points.size() >= MAX_TRAIL_POINT_COUNT:
		trail_global_points.remove_at(0)
	trail_global_points.append(global_position)


func _apply_impact() -> void:
	if impacted:
		return
	impacted = true
	impact_remaining_sec = IMPACT_EFFECT_SEC
	rotation = 0.0
	if _target_remains_on_fired_floor() and target.has_method("receive_turret_hit"):
		target.call("receive_turret_hit", damage, source_type, cc_duration, cc_value)
	_queue_effect_redraw()


func _draw() -> void:
	if OS.has_feature("web"):
		return
	if impacted:
		var progress := 1.0 - impact_remaining_sec / IMPACT_EFFECT_SEC
		var burst_color := _primary_color()
		burst_color.a = 1.0 - progress
		draw_arc(Vector2.ZERO, lerpf(12.0, 36.0, progress), 0.0, TAU, 20, burst_color, 6.0)
		for spark_index in 6:
			var spark_direction := Vector2.from_angle(TAU * float(spark_index) / 6.0)
			draw_circle(spark_direction * lerpf(6.0, 27.0, progress), 4.5 * (1.0 - progress), burst_color)
		return

	_draw_runtime_trail()
	var projectile_size := _projectile_draw_size() * (1.0 + float(tier - 1) * 0.06)
	draw_texture_rect(_projectile_texture(), Rect2(-projectile_size * 0.5, projectile_size), false)


func _queue_effect_redraw() -> void:
	if not OS.has_feature("web"):
		queue_redraw()


# 오래된 점은 가늘고 투명하게, 현재 투사체에 가까울수록 굵고 선명하게 이어 실제 이동 궤적을 만든다.
func _draw_runtime_trail() -> void:
	if trail_global_points.size() < 2:
		return
	var local_points := PackedVector2Array()
	var point_colors := PackedColorArray()
	var base_color := _primary_color()
	for point_index in trail_global_points.size():
		var normalized_age := float(point_index) / float(trail_global_points.size() - 1)
		var point_color := base_color
		point_color.a = lerpf(0.05, 0.62, normalized_age)
		local_points.append(to_local(trail_global_points[point_index]))
		point_colors.append(point_color)
	# 여러 draw_line 호출 대신 한 번의 polyline 명령으로 Web 렌더러의 프레임당 작업량을 제한한다.
	draw_polyline_colors(local_points, point_colors, 9.0, true)


# 트레일이 분리된 정사각형 투사체 이미지를 기존 화면 효과보다 약 50% 크게 표시한다.
func _projectile_draw_size() -> Vector2:
	if source_type == "SLOW":
		return Vector2.ONE * 81.0
	return Vector2.ONE * 87.0


func _projectile_texture() -> Texture2D:
	if source_type == "SLOW":
		return SLOW_PROJECTILE_TEXTURE
	return RANGED_PROJECTILE_TEXTURE


func _primary_color() -> Color:
	if source_type == "SLOW":
		return Color("a8e7ff")
	return Color("7ed957")
