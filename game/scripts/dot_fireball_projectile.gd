class_name PrototypeDotFireballProjectile
extends Node2D

# 지속 포탑 Tier 1이 사용하는 생성형 화염구 이미지 투사체다.
const FIREBALL_TEXTURE := preload("res://assets/combat_vfx/dot_fireball_v1.png")
const SPEED_PX_SEC := 760.0
const HIT_DISTANCE_PX := 20.0
const MAX_LIFETIME_SEC := 3.0
const IMPACT_DURATION_SEC := 0.18
const DRAW_SIZE := Vector2.ONE * 126.0

var target: PrototypeMonster
var damage: float = 0.0
var cc_duration: float = 0.0
var cc_value: float = 0.0
var tier: int = 1
var fired_floor_index: int = -1
var elapsed_sec: float = 0.0
var impact_remaining_sec: float = 0.0
var impacted: bool = false
var fireball_sprite: Sprite2D


func setup(target_node: PrototypeMonster, attack_damage: float, duration: float, value: float, attack_tier: int) -> void:
	target = target_node
	damage = attack_damage
	cc_duration = duration
	cc_value = value
	tier = clampi(attack_tier, 1, 4)
	fired_floor_index = target.current_combat_floor() if is_instance_valid(target) else -1
	z_index = 40
	_configure_sprite()
	add_to_group("dot_fireball_projectiles")


func _process(delta: float) -> void:
	if impacted:
		impact_remaining_sec = maxf(0.0, impact_remaining_sec - delta)
		var progress := 1.0 - impact_remaining_sec / IMPACT_DURATION_SEC
		fireball_sprite.scale = DRAW_SIZE / fireball_sprite.texture.get_size() * lerpf(1.0, 1.55, progress)
		fireball_sprite.modulate.a = 1.0 - progress
		if impact_remaining_sec <= 0.0:
			queue_free()
		return
	if not _target_remains_on_fired_floor():
		queue_free()
		return
	elapsed_sec += delta
	if elapsed_sec >= MAX_LIFETIME_SEC:
		queue_free()
		return
	var destination := target.global_position
	var offset := destination - global_position
	if offset.length() <= maxf(HIT_DISTANCE_PX, SPEED_PX_SEC * delta):
		global_position = destination
		_apply_impact()
		return
	var direction := offset.normalized()
	global_position += direction * SPEED_PX_SEC * delta
	rotation = direction.angle()


func _target_remains_on_fired_floor() -> bool:
	return is_instance_valid(target) and target.is_in_combat_floor() \
		and target.current_combat_floor() == fired_floor_index


func _apply_impact() -> void:
	if impacted:
		return
	impacted = true
	impact_remaining_sec = IMPACT_DURATION_SEC
	rotation = 0.0
	if _target_remains_on_fired_floor():
		target.receive_turret_hit(damage, "DOT", cc_duration, cc_value, tier)


func _configure_sprite() -> void:
	fireball_sprite = Sprite2D.new()
	fireball_sprite.name = "FireballSprite"
	fireball_sprite.texture = FIREBALL_TEXTURE
	fireball_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fireball_sprite.scale = DRAW_SIZE / fireball_sprite.texture.get_size()
	add_child(fireball_sprite)
