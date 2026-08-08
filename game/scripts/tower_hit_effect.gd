class_name PrototypeTowerHitEffect
extends Node2D

# 히트스캔 공격의 판정 위치에 붙는 MELEE 할퀴기와 STUN 낙뢰·헤롱헤롱 연출이다.
const MELEE_DURATION_SEC := 0.24
const STUN_DURATION_SEC := 1.0

# 히트스캔은 판정 자체는 즉시 처리하고, 이 이미지만 대상 위치에 짧게 재생한다.
const MELEE_SLASH_TEXTURE := preload("res://assets/combat_vfx/hit_melee_slash_v2.png")
const STUN_LIGHTNING_TEXTURE := preload("res://assets/combat_vfx/hit_stun_lightning_v2.png")
const STUN_CLOUD_REGION := Rect2(0.0, 0.0, 270.0, 135.0)
const STUN_BOLT_REGION := Rect2(0.0, 115.0, 270.0, 275.0)
const STUN_CLOUD_HEAD_GAP := 12.0
const STUN_CLOUD_BOLT_OVERLAP := 10.0
const STUN_TIER_ONE_CLOUD_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 white_cloud = mix(vec3(0.22, 0.29, 0.38), vec3(1.0), smoothstep(0.12, 0.72, luminance));
	COLOR = vec4(white_cloud, source.a) * COLOR;
}
"""

var effect_type: String = "MELEE"
var remaining_sec: float = 0.0
var total_duration_sec: float = MELEE_DURATION_SEC
var tier: int = 1
var effect_sprite: Sprite2D
var stun_cloud_sprite: Sprite2D
var base_draw_size := Vector2.ZERO
var stun_cloud_draw_size := Vector2.ZERO
var stun_target_height_world: float = 0.0


func setup(attack_type: String, attack_tier: int, target_height_world: float = 0.0) -> void:
	effect_type = attack_type
	tier = clampi(attack_tier, 1, 4)
	stun_target_height_world = maxf(0.0, target_height_world)
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
		var tier_scale := 1.0 + float(tier - 1) * 0.035
		var cloud_texture := AtlasTexture.new()
		cloud_texture.atlas = STUN_LIGHTNING_TEXTURE
		cloud_texture.region = STUN_CLOUD_REGION
		var bolt_texture := AtlasTexture.new()
		bolt_texture.atlas = STUN_LIGHTNING_TEXTURE
		bolt_texture.region = STUN_BOLT_REGION

		stun_cloud_draw_size = Vector2(147.0, 73.5) * tier_scale
		var cloud_bottom_y := -stun_target_height_world - STUN_CLOUD_HEAD_GAP
		base_draw_size = Vector2(
			147.0 * tier_scale,
			4.0 - cloud_bottom_y + STUN_CLOUD_BOLT_OVERLAP
		)
		effect_sprite.texture = bolt_texture
		# 번개·지면 섬광 조각의 최하단을 표적의 실제 접지점에 고정한다.
		effect_sprite.position.y = -base_draw_size.y * 0.5 + 4.0
		stun_cloud_sprite = Sprite2D.new()
		stun_cloud_sprite.name = "StunCloudSprite"
		stun_cloud_sprite.texture = cloud_texture
		stun_cloud_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		stun_cloud_sprite.position.y = cloud_bottom_y - stun_cloud_draw_size.y * 0.5
		stun_cloud_sprite.scale = stun_cloud_draw_size / stun_cloud_sprite.texture.get_size()
		if tier == 1:
			var cloud_shader := Shader.new()
			cloud_shader.code = STUN_TIER_ONE_CLOUD_SHADER
			var cloud_material := ShaderMaterial.new()
			cloud_material.shader = cloud_shader
			stun_cloud_sprite.material = cloud_material
		add_child(stun_cloud_sprite)
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
	if stun_cloud_sprite != null:
		stun_cloud_sprite.scale = stun_cloud_draw_size / stun_cloud_sprite.texture.get_size()
		stun_cloud_sprite.modulate.a = alpha
