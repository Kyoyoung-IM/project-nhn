class_name PrototypeTowerVisualAssets
extends RefCounted

# 새 캐릭터 원본과 2x2 공격 시트를 타입/Tier 순서로 관리한다.
# 공격 프레임 번호는 Godot의 행 우선 순서와 같아서
# 0=좌상, 1=우상, 2=좌하, 3=우하로 재생된다.

const ATTACK_FRAME_COLUMNS := 2
const ATTACK_FRAME_ROWS := 2
const ATTACK_FRAME_COUNT := 4
const ATTACK_FRAME_SIZE := Vector2(512.0, 512.0)

const BODY_TEXTURES := {
	"MELEE": [
		preload("res://assets/towers/charactor/turretMelee/turretMelee1.png"),
		preload("res://assets/towers/charactor/turretMelee/turretMelee2.png"),
		preload("res://assets/towers/charactor/turretMelee/turretMelee3.png"),
		preload("res://assets/towers/charactor/turretMelee/turretMelee4.png"),
	],
	"RANGED": [
		preload("res://assets/towers/charactor/turretRanged/turretRanged1.png"),
		preload("res://assets/towers/charactor/turretRanged/turretRanged2.png"),
		preload("res://assets/towers/charactor/turretRanged/turretRanged3.png"),
		preload("res://assets/towers/charactor/turretRanged/turretRanged4.png"),
	],
	"DOT": [
		preload("res://assets/towers/charactor/turretDot/turretDot1.png"),
		preload("res://assets/towers/charactor/turretDot/turretDot2.png"),
		preload("res://assets/towers/charactor/turretDot/turretDot3.png"),
		preload("res://assets/towers/charactor/turretDot/turretDot4.png"),
	],
	"SLOW": [
		preload("res://assets/towers/charactor/turretSlow/turretSlow1.png"),
		preload("res://assets/towers/charactor/turretSlow/turretSlow2.png"),
		preload("res://assets/towers/charactor/turretSlow/turretSlow3.png"),
		preload("res://assets/towers/charactor/turretSlow/turretSlow4.png"),
	],
	"STUN": [
		preload("res://assets/towers/charactor/turretStun/turretStun1.png"),
		preload("res://assets/towers/charactor/turretStun/turretStun2.png"),
		preload("res://assets/towers/charactor/turretStun/turretStun3.png"),
		preload("res://assets/towers/charactor/turretStun/turretStun4.png"),
	],
}

const ATTACK_TEXTURES := {
	"MELEE": [
		preload("res://assets/towers/charactor/turretMelee/atk animation/turretMelee1_atk.png"),
		preload("res://assets/towers/charactor/turretMelee/atk animation/turretMelee2_atk.png"),
		preload("res://assets/towers/charactor/turretMelee/atk animation/turretMelee3_atk.png"),
		preload("res://assets/towers/charactor/turretMelee/atk animation/turretMelee4_atk.png"),
	],
	"RANGED": [
		preload("res://assets/towers/charactor/turretRanged/atk animation/turretRanged1_atk.png"),
		preload("res://assets/towers/charactor/turretRanged/atk animation/turretRanged2_atk.png"),
		preload("res://assets/towers/charactor/turretRanged/atk animation/turretRanged3_atk.png"),
		preload("res://assets/towers/charactor/turretRanged/atk animation/turretRanged4_atk.png"),
	],
	"DOT": [
		preload("res://assets/towers/charactor/turretDot/atk animation/turretDot1_atk.png"),
		preload("res://assets/towers/charactor/turretDot/atk animation/turretDot2_atk.png"),
		preload("res://assets/towers/charactor/turretDot/atk animation/turretDot3_atk.png"),
		preload("res://assets/towers/charactor/turretDot/atk animation/turretDot4_atk.png"),
	],
	"SLOW": [
		preload("res://assets/towers/charactor/turretSlow/atk animation/turretSlow1_atk.png"),
		preload("res://assets/towers/charactor/turretSlow/atk animation/turretSlow2_atk.png"),
		preload("res://assets/towers/charactor/turretSlow/atk animation/turretSlow3_atk.png"),
		preload("res://assets/towers/charactor/turretSlow/atk animation/turretSlow4_atk.png"),
	],
	"STUN": [
		preload("res://assets/towers/charactor/turretStun/atk animation/turretStun1_atk.png"),
		preload("res://assets/towers/charactor/turretStun/atk animation/turretStun2_atk.png"),
		preload("res://assets/towers/charactor/turretStun/atk animation/turretStun3_atk.png"),
		preload("res://assets/towers/charactor/turretStun/atk animation/turretStun4_atk.png"),
	],
}

# 정지 이미지는 투명 여백 없이 잘려 있으므로 전체 캔버스를 사용한다.
const BODY_VISIBLE_BOUNDS := {
	"MELEE": [Rect2(0, 0, 133, 146), Rect2(0, 0, 222, 260), Rect2(0, 0, 279, 343), Rect2(0, 0, 617, 420)],
	"RANGED": [Rect2(0, 0, 147, 175), Rect2(0, 0, 246, 235), Rect2(0, 0, 393, 318), Rect2(0, 0, 615, 491)],
	"DOT": [Rect2(0, 0, 117, 133), Rect2(0, 0, 230, 151), Rect2(0, 0, 256, 248), Rect2(0, 0, 430, 360)],
	"SLOW": [Rect2(0, 0, 162, 128), Rect2(0, 0, 189, 226), Rect2(0, 0, 221, 264), Rect2(0, 0, 287, 426)],
	"STUN": [Rect2(0, 0, 165, 109), Rect2(0, 0, 229, 160), Rect2(0, 0, 358, 314), Rect2(0, 0, 445, 396)],
}

# 각 시트의 좌상단(1번) 프레임에서 측정한 불투명 영역이다.
# 이 경계로 정지 이미지와 공격 시트의 육안 크기 및 발판 기준선을 맞춘다.
const ATTACK_FIRST_FRAME_VISIBLE_BOUNDS := {
	"MELEE": [Rect2(189.5, 195, 134, 146.5), Rect2(150, 154.5, 212, 247.5), Rect2(129.5, 116.5, 252, 308.5), Rect2(1.5, 122, 506, 344)],
	"RANGED": [Rect2(198, 187.5, 116, 137.5), Rect2(159, 164.5, 194, 183), Rect2(103, 132.5, 306.5, 247), Rect2(36.5, 84.5, 446, 356)],
	"DOT": [Rect2(210.5, 204, 91, 103.5), Rect2(166.5, 197.5, 178.5, 117), Rect2(156.5, 159.5, 199, 193), Rect2(89, 116, 334.5, 280)],
	"SLOW": [Rect2(193, 225, 126, 99.5), Rect2(182.5, 168, 147, 176), Rect2(170, 202, 172, 205.5), Rect2(144.5, 157.5, 223.5, 331.5)],
	"STUN": [Rect2(191.5, 216.5, 128.5, 84.5), Rect2(166.5, 194, 179, 124.5), Rect2(116.5, 133.5, 278.5, 244), Rect2(83, 95.5, 346, 308)],
}


static func body_texture(turret_type: String, tier: int) -> Texture2D:
	var textures: Array = BODY_TEXTURES.get(turret_type, BODY_TEXTURES["RANGED"])
	return textures[clampi(tier - 1, 0, textures.size() - 1)] as Texture2D


static func body_visible_bounds(turret_type: String, tier: int) -> Rect2:
	var bounds_by_tier: Array = BODY_VISIBLE_BOUNDS.get(turret_type, BODY_VISIBLE_BOUNDS["RANGED"])
	return bounds_by_tier[clampi(tier - 1, 0, bounds_by_tier.size() - 1)] as Rect2


static func attack_texture(turret_type: String, tier: int) -> Texture2D:
	var textures: Array = ATTACK_TEXTURES.get(turret_type, ATTACK_TEXTURES["RANGED"])
	return textures[clampi(tier - 1, 0, textures.size() - 1)] as Texture2D


static func attack_first_frame_visible_bounds(turret_type: String, tier: int) -> Rect2:
	var bounds_by_tier: Array = ATTACK_FIRST_FRAME_VISIBLE_BOUNDS.get(turret_type, ATTACK_FIRST_FRAME_VISIBLE_BOUNDS["RANGED"])
	return bounds_by_tier[clampi(tier - 1, 0, bounds_by_tier.size() - 1)] as Rect2
