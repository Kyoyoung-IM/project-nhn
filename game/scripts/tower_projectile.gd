class_name PrototypeTowerProjectile
extends Node2D

# DOT/SLOW/RANGED의 공격 판정과 코드 기반 투사체 연출을 함께 담당한다.
# 속도는 데이터 테이블에 아직 필드가 없으므로 전투 피해와 분리된 시각 전용 PLACEHOLDER 값이다.
const PROJECTILE_SPEED_PX_SEC := {
	"DOT": 620.0,
	"SLOW": 720.0,
	"RANGED": 900.0,
}
const HIT_DISTANCE_PX := 18.0
const MAX_LIFETIME_SEC := 3.0
const IMPACT_EFFECT_SEC := 0.18

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


# 포탑의 발사 위치에서 시작해 움직이는 대상을 추적하고, 도달한 순간에만 기존 공격 규칙을 호출한다.
func setup(target_node: Node2D, attack_type: String, attack_damage: float, duration: float, value: float, attack_tier: int) -> void:
	target = target_node
	source_type = attack_type
	damage = attack_damage
	cc_duration = duration
	cc_value = value
	tier = clampi(attack_tier, 1, 4)
	speed_px_sec = float(PROJECTILE_SPEED_PX_SEC.get(source_type, 900.0))
	z_index = 40
	add_to_group("tower_projectiles")
	queue_redraw()


func _process(delta: float) -> void:
	if impacted:
		impact_remaining_sec = maxf(0.0, impact_remaining_sec - delta)
		queue_redraw()
		if impact_remaining_sec <= 0.0:
			queue_free()
		return

	elapsed_sec += delta
	if elapsed_sec >= MAX_LIFETIME_SEC or not is_instance_valid(target):
		queue_free()
		return

	# 몬스터 몸통 중심보다 약간 위를 향하게 해 투사체가 발판 아래로 파고들지 않게 한다.
	var destination := target.global_position + Vector2(0.0, -8.0)
	var to_target := destination - global_position
	if to_target.length() <= maxf(HIT_DISTANCE_PX, speed_px_sec * delta):
		global_position = destination
		_apply_impact()
		return

	travel_direction = to_target.normalized()
	global_position += travel_direction * speed_px_sec * delta
	rotation = travel_direction.angle()
	queue_redraw()


# 명중 시점에 피해와 DOT/SLOW 상태이상을 적용하고 짧은 타입별 파열 연출로 전환한다.
func _apply_impact() -> void:
	if impacted:
		return
	impacted = true
	impact_remaining_sec = IMPACT_EFFECT_SEC
	rotation = 0.0
	if is_instance_valid(target) and target.has_method("receive_turret_hit"):
		target.call("receive_turret_hit", damage, source_type, cc_duration, cc_value)
	queue_redraw()


func _draw() -> void:
	if impacted:
		var progress := 1.0 - impact_remaining_sec / IMPACT_EFFECT_SEC
		var burst_color := _primary_color()
		burst_color.a = 1.0 - progress
		draw_arc(Vector2.ZERO, lerpf(8.0, 24.0, progress), 0.0, TAU, 20, burst_color, 4.0)
		for spark_index in 6:
			var spark_direction := Vector2.from_angle(TAU * float(spark_index) / 6.0)
			draw_circle(spark_direction * lerpf(4.0, 18.0, progress), 3.0 * (1.0 - progress), burst_color)
		return

	match source_type:
		"DOT":
			# 화염방사 투사체는 진행 방향 앞쪽의 밝은 심과 뒤로 늘어지는 불꽃 덩어리로 표현한다.
			draw_circle(Vector2(-18.0, 0.0), 10.0 + tier, Color("e94c2b"))
			draw_circle(Vector2(-8.0, 0.0), 12.0 + tier, Color("ff842f"))
			draw_circle(Vector2(4.0, 0.0), 9.0 + tier * 0.7, Color("ffd45a"))
			draw_colored_polygon(PackedVector2Array([Vector2(-29.0, 0.0), Vector2(-17.0, -8.0), Vector2(-17.0, 8.0)]), Color("d83a26"))
		"SLOW":
			# 눈덩이는 밝은 본체, 푸른 외곽과 작은 눈 결정로 구분한다.
			draw_circle(Vector2.ZERO, 11.0 + tier, Color("eaf8ff"))
			draw_arc(Vector2.ZERO, 11.0 + tier, 0.0, TAU, 20, Color("83cbe8"), 3.0)
			draw_line(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), Color("b8e8f8"), 2.0)
			draw_line(Vector2(0.0, -5.0), Vector2(0.0, 5.0), Color("b8e8f8"), 2.0)
		_:
			# 원거리 포탑은 둥근 초록 콩알과 뒤쪽의 작은 잎 실루엣을 사용한다.
			draw_colored_polygon(PackedVector2Array([Vector2(-13.0, 0.0), Vector2(-22.0, -7.0), Vector2(-20.0, 5.0)]), Color("4b9c46"))
			draw_circle(Vector2.ZERO, 9.0 + tier * 0.8, Color("7ed957"))
			draw_circle(Vector2(3.0, -3.0), 3.0, Color("b8f57c"))


func _primary_color() -> Color:
	match source_type:
		"DOT":
			return Color("ff8a35")
		"SLOW":
			return Color("a8e7ff")
		_:
			return Color("7ed957")
