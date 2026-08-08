class_name PrototypeMeleeExecutionEffect
extends Node2D

# Tier 4 근접 처형 때 사망 위치 위로 떠오르는 Web-safe 붉은 해골 연출이다.
# 외부 비트맵 없이 지속 CanvasItem 자식만 변환해 Web 메인 스레드에서도 안전하게 재생한다.
const DURATION_SEC := 0.72
const DRAW_SCALE := 1.35

var remaining_sec: float = 0.0
var skull_root: Node2D


func setup() -> void:
	remaining_sec = DURATION_SEC
	z_index = 55
	_configure_skull()
	add_to_group("melee_execution_effects")


func _process(delta: float) -> void:
	remaining_sec = maxf(0.0, remaining_sec - delta)
	var progress := 1.0 - remaining_sec / DURATION_SEC
	position.y -= 38.0 * delta
	if skull_root != null:
		var pulse := DRAW_SCALE * (0.78 + sin(progress * PI) * 0.32)
		skull_root.scale = Vector2.ONE * pulse
		skull_root.modulate.a = 1.0 - clampf((progress - 0.52) / 0.48, 0.0, 1.0)
	if remaining_sec <= 0.0:
		queue_free()


func _configure_skull() -> void:
	skull_root = Node2D.new()
	skull_root.name = "RedSkull"
	add_child(skull_root)

	var skull := Polygon2D.new()
	skull.name = "Skull"
	skull.polygon = PackedVector2Array([
		Vector2(-22.0, -15.0), Vector2(-14.0, -28.0), Vector2(0.0, -33.0),
		Vector2(14.0, -28.0), Vector2(22.0, -15.0), Vector2(21.0, 2.0),
		Vector2(13.0, 12.0), Vector2(9.0, 25.0), Vector2(3.0, 20.0),
		Vector2(0.0, 27.0), Vector2(-3.0, 20.0), Vector2(-9.0, 25.0),
		Vector2(-13.0, 12.0), Vector2(-21.0, 2.0),
	])
	skull.color = Color("ef334f")
	skull_root.add_child(skull)

	for eye_x in [-8.0, 8.0]:
		var eye := Polygon2D.new()
		eye.name = "Eye"
		eye.polygon = PackedVector2Array([
			Vector2(eye_x - 5.0, -9.0), Vector2(eye_x + 5.0, -9.0),
			Vector2(eye_x + 3.0, 1.0), Vector2(eye_x - 4.0, 2.0),
		])
		eye.color = Color("4b0715")
		skull_root.add_child(eye)

	var nose := Polygon2D.new()
	nose.name = "Nose"
	nose.polygon = PackedVector2Array([
		Vector2(0.0, 1.0), Vector2(5.0, 9.0), Vector2(0.0, 11.0), Vector2(-5.0, 9.0),
	])
	nose.color = Color("4b0715")
	skull_root.add_child(nose)
