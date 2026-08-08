class_name PrototypeRangedLaserEffect
extends Node2D

# Tier 3·4 원거리 포탑의 Web-safe 초록 관통 레이저다.
const DURATION_SEC := 0.24
const GLOW_WIDTH := 20.0
const CORE_WIDTH := 7.0

var remaining_sec: float = 0.0
var beam_count: int = 0
var glow_lines: Array[Line2D] = []
var core_lines: Array[Line2D] = []
var endpoint_flares: Array[Polygon2D] = []


func setup(source_positions: PackedVector2Array, endpoint: Vector2) -> void:
	remaining_sec = DURATION_SEC
	beam_count = source_positions.size()
	z_index = 46
	for source_position in source_positions:
		var points := PackedVector2Array([source_position, endpoint])
		var glow := Line2D.new()
		glow.name = "LaserGlow"
		glow.points = points
		glow.width = GLOW_WIDTH
		glow.default_color = Color(0.18, 1.0, 0.30, 0.30)
		glow.antialiased = true
		add_child(glow)
		glow_lines.append(glow)

		var core := Line2D.new()
		core.name = "LaserCore"
		core.points = points
		core.width = CORE_WIDTH
		core.default_color = Color("9dff70")
		core.antialiased = true
		add_child(core)
		core_lines.append(core)

		var flare := Polygon2D.new()
		flare.name = "LaserEndpoint"
		flare.position = endpoint
		flare.polygon = PackedVector2Array([
			Vector2(0.0, -16.0), Vector2(8.0, -8.0), Vector2(16.0, 0.0),
			Vector2(8.0, 8.0), Vector2(0.0, 16.0), Vector2(-8.0, 8.0),
			Vector2(-16.0, 0.0), Vector2(-8.0, -8.0),
		])
		flare.color = Color("b8ff7a")
		add_child(flare)
		endpoint_flares.append(flare)
	add_to_group("ranged_laser_effects")


func _process(delta: float) -> void:
	remaining_sec = maxf(0.0, remaining_sec - delta)
	var progress := 1.0 - remaining_sec / DURATION_SEC
	var alpha := 1.0 - clampf((progress - 0.42) / 0.58, 0.0, 1.0)
	var pulse := 0.86 + sin(progress * PI) * 0.24
	for glow in glow_lines:
		glow.width = GLOW_WIDTH * pulse
		glow.modulate.a = alpha
	for core in core_lines:
		core.width = CORE_WIDTH * pulse
		core.modulate.a = alpha
	for flare in endpoint_flares:
		flare.scale = Vector2.ONE * pulse
		flare.modulate.a = alpha
	if remaining_sec <= 0.0:
		queue_free()
