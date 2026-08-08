class_name PrototypeStunLaneLightningEffect
extends Node2D

# 같은 층 전체에 한 장의 낙뢰 PNG를 반복 배치해 Tier 3·4 라인 공격을 표시한다.
const BLUE_TEXTURE := preload("res://assets/combat_vfx/stun_lane_lightning_blue_v1.png")
const PURPLE_TEXTURE := preload("res://assets/combat_vfx/stun_lane_lightning_purple_v1.png")
const LANE_LEFT_X := -1797.0
const LANE_RIGHT_X := 3717.0
const BOLT_COUNT := 10
const BOLT_DRAW_SIZE := Vector2(245.0, 430.0)
const BOLT_SEGMENT_INSET_RATIO := 0.14
const BOLT_STAGGER_SEC := 0.025
const BOLT_VISIBLE_SEC := 0.34

var elapsed_sec: float = 0.0
var total_duration_sec: float = 0.0
var bolt_sprites: Array[Sprite2D] = []


func setup(attack_tier: int, lane_y: float, random_seed: int = 0) -> void:
	var texture := PURPLE_TEXTURE if attack_tier >= 4 else BLUE_TEXTURE
	var bolt_x_positions := _randomized_bolt_x_positions(random_seed)
	total_duration_sec = BOLT_VISIBLE_SEC + BOLT_STAGGER_SEC * float(BOLT_COUNT - 1)
	z_index = 44
	for bolt_index in BOLT_COUNT:
		var bolt := Sprite2D.new()
		bolt.name = "LaneBolt%d" % (bolt_index + 1)
		bolt.texture = texture
		bolt.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bolt.position = Vector2(bolt_x_positions[bolt_index], lane_y - BOLT_DRAW_SIZE.y * 0.5)
		bolt.scale = BOLT_DRAW_SIZE / texture.get_size()
		bolt.modulate.a = 0.0
		add_child(bolt)
		bolt_sprites.append(bolt)
	add_to_group("stun_lane_lightning_effects")


# 라인을 같은 폭의 구간으로 나눠 각 구간 안에서 한 번씩 무작위 추출한 뒤 낙하 순서도 섞는다.
# 완전 독립 난수의 한쪽 몰림은 피하면서 매 공격마다 다른 위치·순서를 만든다.
func _randomized_bolt_x_positions(random_seed: int = 0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	if random_seed == 0:
		# 같은 프레임에 Tier 3·4가 함께 발동해도 인스턴스별로 다른 배열을 보장한다.
		rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id())
	else:
		rng.seed = random_seed
	var positions := PackedFloat32Array()
	var usable_left := LANE_LEFT_X + BOLT_DRAW_SIZE.x * 0.5
	var usable_right := LANE_RIGHT_X - BOLT_DRAW_SIZE.x * 0.5
	var segment_width := (usable_right - usable_left) / float(BOLT_COUNT)
	for segment_index in BOLT_COUNT:
		var segment_start := usable_left + segment_width * float(segment_index)
		var inset := segment_width * BOLT_SEGMENT_INSET_RATIO
		positions.append(rng.randf_range(segment_start + inset, segment_start + segment_width - inset))
	for index in range(BOLT_COUNT - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := positions[index]
		positions[index] = positions[swap_index]
		positions[swap_index] = temporary
	return positions


func _process(delta: float) -> void:
	elapsed_sec += delta
	for bolt_index in bolt_sprites.size():
		var local_progress := (elapsed_sec - BOLT_STAGGER_SEC * float(bolt_index)) / BOLT_VISIBLE_SEC
		var bolt := bolt_sprites[bolt_index]
		if local_progress < 0.0 or local_progress > 1.0:
			bolt.modulate.a = 0.0
			continue
		bolt.modulate.a = 1.0 - clampf((local_progress - 0.62) / 0.38, 0.0, 1.0)
		var height_scale := lerpf(0.86, 1.0, minf(local_progress / 0.16, 1.0))
		bolt.scale = Vector2(BOLT_DRAW_SIZE.x, BOLT_DRAW_SIZE.y * height_scale) / bolt.texture.get_size()
	if elapsed_sec >= total_duration_sec:
		queue_free()
