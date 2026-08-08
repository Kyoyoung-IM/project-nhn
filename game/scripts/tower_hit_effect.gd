class_name PrototypeTowerHitEffect
extends Node2D

# 히트스캔 공격의 판정 위치에 붙는 MELEE 할퀴기와 STUN 낙뢰·헤롱헤롱 연출이다.
const MELEE_DURATION_SEC := 0.24
const STUN_DURATION_SEC := 1.0

# 히트스캔은 판정 자체는 즉시 처리하고, 이 이미지만 대상 위치에 짧게 재생한다.
const MELEE_SLASH_TEXTURE := preload("res://assets/combat_vfx/hit_melee_slash_v2.png")
const STUN_LIGHTNING_TEXTURE := preload("res://assets/combat_vfx/hit_stun_lightning_v2.png")

var effect_type: String = "MELEE"
var remaining_sec: float = 0.0
var total_duration_sec: float = MELEE_DURATION_SEC
var tier: int = 1
var effect_sprite: Sprite2D
var base_draw_size := Vector2.ZERO


func setup(attack_type: String, attack_tier: int) -> void:
	effect_type = attack_type
	tier = clampi(attack_tier, 1, 4)
	total_duration_sec = STUN_DURATION_SEC if effect_type == "STUN" else MELEE_DURATION_SEC
	remaining_sec = total_duration_sec
	z_index = 45
	_configure_effect_sprite()
	add_to_group("tower_hit_effects")


func _process(delta: float) -> void:
	remaining_sec = maxf(0.0, remaining_sec - delta)
	_update_effect_visual()
	if remaining_sec <= 0.0:
		queue_free()


func _configure_effect_sprite() -> void:
	effect_sprite = Sprite2D.new()
	effect_sprite.name = "EffectSprite"
	effect_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if effect_type == "STUN":
		effect_sprite.texture = STUN_LIGHTNING_TEXTURE
		base_draw_size = Vector2(147.0, 213.0) * (1.0 + float(tier - 1) * 0.035)
		# 효과 노드는 지면 접촉점에 있으므로 낙뢰 하단을 원점에 고정한다.
		effect_sprite.position.y = -base_draw_size.y * 0.5 + 4.0
	else:
		effect_sprite.texture = MELEE_SLASH_TEXTURE
		base_draw_size = Vector2(123.0, 138.0) * (1.0 + float(tier - 1) * 0.05)
	effect_sprite.scale = base_draw_size / effect_sprite.texture.get_size()
	add_child(effect_sprite)
	_update_effect_visual()


func _update_effect_visual() -> void:
	if effect_sprite == null:
		return
	var progress := 1.0 - remaining_sec / total_duration_sec
	var alpha := 1.0 - progress
	var scale_factor := 0.82 + progress * 0.28
	if effect_type == "STUN":
		alpha = 1.0 - clampf((progress - 0.55) / 0.45, 0.0, 1.0)
		scale_factor = 1.0
	effect_sprite.scale = base_draw_size / effect_sprite.texture.get_size() * scale_factor
	effect_sprite.modulate.a = alpha
