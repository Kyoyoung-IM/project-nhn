class_name PrototypeTowerHitEffect
extends Node2D

# 히트스캔 공격의 판정 위치에 붙는 MELEE 할퀴기와 STUN 낙뢰·헤롱헤롱 연출이다.
const MELEE_DURATION_SEC := 0.24
const STUN_DURATION_SEC := 0.72

var effect_type: String = "MELEE"
var remaining_sec: float = 0.0
var total_duration_sec: float = MELEE_DURATION_SEC
var tier: int = 1


func setup(attack_type: String, attack_tier: int) -> void:
	effect_type = attack_type
	tier = clampi(attack_tier, 1, 4)
	total_duration_sec = STUN_DURATION_SEC if effect_type == "STUN" else MELEE_DURATION_SEC
	remaining_sec = total_duration_sec
	z_index = 45
	add_to_group("tower_hit_effects")
	queue_redraw()


func _process(delta: float) -> void:
	remaining_sec = maxf(0.0, remaining_sec - delta)
	queue_redraw()
	if remaining_sec <= 0.0:
		queue_free()


func _draw() -> void:
	var progress := 1.0 - remaining_sec / total_duration_sec
	if effect_type == "STUN":
		_draw_stun_effect(progress)
	else:
		_draw_melee_slashes(progress)


# 세 줄의 발톱 자국이 빠르게 벌어졌다 사라지며 근접 히트스캔의 피격 위치를 명확히 보여준다.
func _draw_melee_slashes(progress: float) -> void:
	var slash_color := Color("fff0c2")
	slash_color.a = 1.0 - progress
	var spread := lerpf(4.0, 14.0, progress)
	for slash_index in 3:
		var offset_x := (float(slash_index) - 1.0) * spread
		var points := PackedVector2Array([
			Vector2(offset_x - 13.0, -20.0),
			Vector2(offset_x - 4.0, -7.0),
			Vector2(offset_x + 5.0, 5.0),
			Vector2(offset_x + 13.0, 18.0),
		])
		draw_polyline(points, slash_color, 4.0 + tier * 0.35, true)


# 머리 위에서 떨어지는 지그재그 낙뢰와 회전하는 별을 한 이펙트로 묶어 타격과 기절을 동시에 전달한다.
func _draw_stun_effect(progress: float) -> void:
	var lightning_alpha := clampf(1.0 - progress * 1.8, 0.0, 1.0)
	var lightning_color := Color(0.88, 0.94, 1.0, lightning_alpha)
	var lightning_points := PackedVector2Array([
		Vector2(-8.0, -112.0),
		Vector2(9.0, -86.0),
		Vector2(-5.0, -66.0),
		Vector2(12.0, -43.0),
		Vector2(0.0, -18.0),
	])
	draw_polyline(lightning_points, Color(0.43, 0.56, 1.0, lightning_alpha * 0.7), 10.0, true)
	draw_polyline(lightning_points, lightning_color, 4.0, true)
	var orbit_angle := progress * TAU * 1.7
	for star_index in 3:
		var angle := orbit_angle + TAU * float(star_index) / 3.0
		var star_position := Vector2(cos(angle) * 24.0, -36.0 + sin(angle) * 7.0)
		_draw_star(star_position, 6.0 + tier * 0.5, Color(1.0, 0.91, 0.32, 1.0 - progress * 0.45))


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for point_index in 8:
		var point_radius := radius if point_index % 2 == 0 else radius * 0.42
		points.append(center + Vector2.from_angle(-PI * 0.5 + TAU * float(point_index) / 8.0) * point_radius)
	draw_colored_polygon(points, color)
