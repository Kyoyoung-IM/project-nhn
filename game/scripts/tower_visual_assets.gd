class_name PrototypeTowerVisualAssets
extends RefCounted

# 타워 본체와 상시 이펙트 텍스처를 한곳에서 관리한다.
# 데이터 테이블의 타입 문자열과 배열 인덱스(Tier - 1)를 연결해 전장과 상점이
# 동일한 이미지를 사용하도록 한다.

const BODY_TEXTURES := {
	"MELEE": [
		preload("res://assets/towers/bodies/melee_t1.png"),
		preload("res://assets/towers/bodies/melee_t2.png"),
		preload("res://assets/towers/bodies/melee_t3.png"),
		preload("res://assets/towers/bodies/melee_t4.png"),
	],
	"RANGED": [
		preload("res://assets/towers/bodies/ranged_t1.png"),
		preload("res://assets/towers/bodies/ranged_t2.png"),
		preload("res://assets/towers/bodies/ranged_t3.png"),
		preload("res://assets/towers/bodies/ranged_t4.png"),
	],
	"DOT": [
		preload("res://assets/towers/bodies/dot_t1.png"),
		preload("res://assets/towers/bodies/dot_t2.png"),
		preload("res://assets/towers/bodies/dot_t3.png"),
		preload("res://assets/towers/bodies/dot_t4.png"),
	],
	"SLOW": [
		preload("res://assets/towers/bodies/slow_t1.png"),
		preload("res://assets/towers/bodies/slow_t2.png"),
		preload("res://assets/towers/bodies/slow_t3.png"),
		preload("res://assets/towers/bodies/slow_t4.png"),
	],
	"STUN": [
		preload("res://assets/towers/bodies/stun_t1.png"),
		preload("res://assets/towers/bodies/stun_t2.png"),
		preload("res://assets/towers/bodies/stun_t3.png"),
		preload("res://assets/towers/bodies/stun_t4.png"),
	],
}

const DOT_FLAME_TEXTURES := [
	preload("res://assets/towers/effects/dot_flame_t1.png"),
	preload("res://assets/towers/effects/dot_flame_t2.png"),
	preload("res://assets/towers/effects/dot_flame_t3.png"),
	preload("res://assets/towers/effects/dot_flame_t4.png"),
]

const STUN_LIGHTNING_TIER_4 := preload("res://assets/towers/effects/stun_lightning_t4.png")

# 원본 PNG는 모두 256×256 캔버스지만 실제 그림이 차지하는 영역은 종류와 Tier마다 다르다.
# 아래 경계값으로 투명 여백을 제외해야 머지 단계에 따른 육안 크기를 일관되게 계산할 수 있다.
const BODY_VISIBLE_BOUNDS := {
	"MELEE": [
		Rect2(24.0, 14.0, 208.0, 228.0),
		Rect2(33.0, 14.0, 190.0, 228.0),
		Rect2(15.0, 14.0, 225.0, 228.0),
		Rect2(14.0, 46.0, 228.0, 196.0),
	],
	"RANGED": [
		Rect2(44.0, 14.0, 168.0, 228.0),
		Rect2(40.0, 14.0, 176.0, 228.0),
		Rect2(18.0, 14.0, 220.0, 228.0),
		Rect2(14.0, 53.0, 228.0, 189.0),
	],
	"DOT": [
		Rect2(14.0, 78.0, 228.0, 164.0),
		Rect2(14.0, 64.0, 228.0, 178.0),
		Rect2(25.0, 14.0, 206.0, 228.0),
		Rect2(14.0, 67.0, 228.0, 175.0),
	],
	"SLOW": [
		Rect2(14.0, 93.0, 228.0, 149.0),
		Rect2(34.0, 14.0, 188.0, 228.0),
		Rect2(40.0, 14.0, 175.0, 228.0),
		Rect2(29.0, 14.0, 197.0, 228.0),
	],
	"STUN": [
		Rect2(14.0, 80.0, 228.0, 162.0),
		Rect2(14.0, 79.0, 228.0, 163.0),
		Rect2(14.0, 84.0, 228.0, 158.0),
		Rect2(14.0, 117.0, 228.0, 125.0),
	],
}

const DOT_FLAME_VISIBLE_BOUNDS := [
	Rect2(53.0, 14.0, 149.0, 228.0),
	Rect2(56.0, 14.0, 143.0, 228.0),
	Rect2(49.0, 14.0, 157.0, 228.0),
	# Tier 4는 원본의 작은 좌측 불꽃을 자른 AtlasTexture 기준 경계다.
	Rect2(1.0, 9.0, 169.0, 169.0),
]

const STUN_LIGHTNING_VISIBLE_BOUNDS := Rect2(14.0, 96.0, 228.0, 146.0)
const DOT_TIER_4_MAIN_FLAME_REGION := Rect2(72.0, 64.0, 184.0, 192.0)
# Tier 3·4 본체의 아래쪽 전면부를 불꽃보다 위에 다시 그려 화로 안쪽에서 불이 솟는 깊이를 만든다.
const DOT_FRONT_REGIONS := {
	# 불투명 본체가 시작되는 지점부터 사용해 전방 조각에 수평 절단선이 생기지 않게 한다.
	3: Rect2(0.0, 14.0, 256.0, 242.0),
	4: Rect2(0.0, 67.0, 256.0, 189.0),
}


# 잘못된 타입이나 Tier가 들어와도 원거리 Tier 1로 안전하게 폴백한다.
static func body_texture(turret_type: String, tier: int) -> Texture2D:
	var textures: Array = BODY_TEXTURES.get(turret_type, BODY_TEXTURES["RANGED"])
	return textures[clampi(tier - 1, 0, textures.size() - 1)] as Texture2D


# 투명 여백을 제외한 본체의 실제 그림 경계를 반환한다.
static func body_visible_bounds(turret_type: String, tier: int) -> Rect2:
	var bounds_by_tier: Array = BODY_VISIBLE_BOUNDS.get(turret_type, BODY_VISIBLE_BOUNDS["RANGED"])
	return bounds_by_tier[clampi(tier - 1, 0, bounds_by_tier.size() - 1)] as Rect2


# 지속 피해 타워의 불꽃은 본체와 별도 Sprite2D에서 애니메이션한다.
static func dot_flame_texture(tier: int) -> Texture2D:
	var tier_index := clampi(tier - 1, 0, DOT_FLAME_TEXTURES.size() - 1)
	if tier_index < 3:
		return DOT_FLAME_TEXTURES[tier_index] as Texture2D
	# Tier 4 원본 좌측의 작은 불꽃은 공격 연출 조각이므로 idle 본체 효과에서 제외한다.
	var main_flame := AtlasTexture.new()
	main_flame.atlas = DOT_FLAME_TEXTURES[tier_index] as Texture2D
	main_flame.region = DOT_TIER_4_MAIN_FLAME_REGION
	main_flame.filter_clip = true
	return main_flame


# 표시용으로 잘라낸 텍스처 좌표계를 기준으로 불꽃의 실제 그림 경계를 반환한다.
static func dot_flame_visible_bounds(tier: int) -> Rect2:
	return DOT_FLAME_VISIBLE_BOUNDS[clampi(tier - 1, 0, DOT_FLAME_VISIBLE_BOUNDS.size() - 1)] as Rect2


# DOT Tier 3·4의 전방 본체 조각을 원본과 동일한 픽셀로 잘라 반환한다.
static func dot_front_texture(tier: int) -> Texture2D:
	if not DOT_FRONT_REGIONS.has(tier):
		return null
	var front_texture := AtlasTexture.new()
	front_texture.atlas = body_texture("DOT", tier)
	front_texture.region = DOT_FRONT_REGIONS[tier]
	front_texture.filter_clip = true
	return front_texture


static func dot_front_region(tier: int) -> Rect2:
	return DOT_FRONT_REGIONS.get(tier, Rect2()) as Rect2


# 기절 Tier 4만 사용하는 번개 텍스처를 반환한다.
static func stun_lightning_texture() -> Texture2D:
	return STUN_LIGHTNING_TIER_4


static func stun_lightning_visible_bounds() -> Rect2:
	return STUN_LIGHTNING_VISIBLE_BOUNDS
