class_name PrototypeStunLaneLightningEffect
extends Node2D

# 같은 층 전체에 한 장의 낙뢰 PNG를 반복 배치해 Tier 3·4 라인 공격을 표시한다.
const BLUE_TEXTURE := preload("res://assets/combat_vfx/stun_lane_lightning_blue_v1.png")
const PURPLE_TEXTURE := preload("res://assets/combat_vfx/stun_lane_lightning_purple_v1.png")
const LANE_LEFT_X := -1797.0
const LANE_RIGHT_X := 3717.0
const BOLT_COUNT := 10
const BOLT_DRAW_SIZE := Vector2(245.0, 430.0)
const BOLT_STAGGER_SEC := 0.025
const BOLT_VISIBLE_SEC := 0.34

var elapsed_sec: float = 0.0
var total_duration_sec: float = 0.0
var bolt_sprites: Array[Sprite2D] = []


func setup(attack_tier: int, lane_y: float) -> void:
	var texture := PURPLE_TEXTURE if attack_tier >= 4 else BLUE_TEXTURE
	total_duration_sec = BOLT_VISIBLE_SEC + BOLT_STAGGER_SEC * float(BOLT_COUNT - 1)
	z_index = 44
	for bolt_index in BOLT_COUNT:
		var bolt := Sprite2D.new()
		bolt.name = "LaneBolt%d" % (bolt_index + 1)
		bolt.texture = texture
		bolt.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var ratio := float(bolt_index) / float(BOLT_COUNT - 1)
		bolt.position = Vector2(lerpf(LANE_LEFT_X, LANE_RIGHT_X, ratio), lane_y - BOLT_DRAW_SIZE.y * 0.5)
		bolt.scale = BOLT_DRAW_SIZE / texture.get_size()
		bolt.modulate.a = 0.0
		add_child(bolt)
		bolt_sprites.append(bolt)
	add_to_group("stun_lane_lightning_effects")


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
