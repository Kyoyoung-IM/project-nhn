class_name PrototypeDotDeathExplosion
extends Node2D

# Tier 4 DOT 보유 적의 사망 위치에 표시하는 생성형 폭발 이미지 연출이다.
const EXPLOSION_TEXTURE := preload("res://assets/combat_vfx/dot_death_explosion_v1.png")
const DURATION_SEC := 0.46
const DRAW_SIZE := Vector2.ONE * 230.0

var remaining_sec: float = 0.0
var explosion_sprite: Sprite2D


func setup() -> void:
	remaining_sec = DURATION_SEC
	z_index = 48
	explosion_sprite = Sprite2D.new()
	explosion_sprite.name = "ExplosionSprite"
	explosion_sprite.texture = EXPLOSION_TEXTURE
	explosion_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	explosion_sprite.scale = DRAW_SIZE / explosion_sprite.texture.get_size() * 0.55
	add_child(explosion_sprite)
	add_to_group("dot_death_explosions")


func _process(delta: float) -> void:
	remaining_sec = maxf(0.0, remaining_sec - delta)
	var progress := 1.0 - remaining_sec / DURATION_SEC
	var size_factor := lerpf(0.55, 1.25, minf(1.0, progress * 1.7))
	explosion_sprite.scale = DRAW_SIZE / explosion_sprite.texture.get_size() * size_factor
	explosion_sprite.modulate.a = 1.0 - clampf((progress - 0.58) / 0.42, 0.0, 1.0)
	if remaining_sec <= 0.0:
		queue_free()
