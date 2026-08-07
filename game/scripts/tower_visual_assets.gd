class_name PrototypeTowerVisualAssets
extends RefCounted

# 새 캐릭터 원본과 2프레임 대기·2x2 공격 시트를 타입/Tier 순서로 관리한다.
# 공격 프레임 번호는 Godot의 행 우선 순서와 같아서
# 0=좌상, 1=우상, 2=좌하, 3=우하로 재생된다.

const IDLE_FRAME_COLUMNS := 2
const IDLE_FRAME_ROWS := 1
const IDLE_FRAME_COUNT := 2
const IDLE_FRAME_SIZE := Vector2(256.0, 256.0)
const ATTACK_FRAME_COLUMNS := 2
const ATTACK_FRAME_ROWS := 2
const ATTACK_FRAME_COUNT := 4
const ATTACK_FRAME_SIZE := Vector2(256.0, 256.0)

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

const IDLE_TEXTURE_PATHS := {
	"MELEE": [
		"res://assets/towers/charactor/turretMelee/idle animation/cha_1_1.png",
		"res://assets/towers/charactor/turretMelee/idle animation/cha_1_2.png",
		"res://assets/towers/charactor/turretMelee/idle animation/cha_1_3.png",
		"res://assets/towers/charactor/turretMelee/idle animation/cha_1_4.png",
	],
	"RANGED": [
		"res://assets/towers/charactor/turretRanged/idle animation/cha_2_1.png",
		"res://assets/towers/charactor/turretRanged/idle animation/cha_2_2.png",
		"res://assets/towers/charactor/turretRanged/idle animation/cha_2_3.png",
		"res://assets/towers/charactor/turretRanged/idle animation/cha_2_4.png",
	],
	"DOT": [
		"res://assets/towers/charactor/turretDot/idle animation/cha_3_1.png",
		"res://assets/towers/charactor/turretDot/idle animation/cha_3_2.png",
		"res://assets/towers/charactor/turretDot/idle animation/cha_3_3.png",
		"res://assets/towers/charactor/turretDot/idle animation/cha_3_4.png",
	],
	"SLOW": [
		"res://assets/towers/charactor/turretSlow/idle animation/cha_4_1.png",
		"res://assets/towers/charactor/turretSlow/idle animation/cha_4_2.png",
		"res://assets/towers/charactor/turretSlow/idle animation/cha_4_3.png",
		"res://assets/towers/charactor/turretSlow/idle animation/cha_4_4.png",
	],
	"STUN": [
		"res://assets/towers/charactor/turretStun/idle animation/cha_5_1.png",
		"res://assets/towers/charactor/turretStun/idle animation/cha_5_2.png",
		"res://assets/towers/charactor/turretStun/idle animation/cha_5_3.png",
		"res://assets/towers/charactor/turretStun/idle animation/cha_5_4.png",
	],
}

const ATTACK_TEXTURE_PATHS := {
	"MELEE": [
		"res://assets/towers/charactor/turretMelee/atk animation/turretMelee1_atk.png",
		"res://assets/towers/charactor/turretMelee/atk animation/turretMelee2_atk.png",
		"res://assets/towers/charactor/turretMelee/atk animation/turretMelee3_atk.png",
		"res://assets/towers/charactor/turretMelee/atk animation/turretMelee4_atk.png",
	],
	"RANGED": [
		"res://assets/towers/charactor/turretRanged/atk animation/turretRanged1_atk.png",
		"res://assets/towers/charactor/turretRanged/atk animation/turretRanged2_atk.png",
		"res://assets/towers/charactor/turretRanged/atk animation/turretRanged3_atk.png",
		"res://assets/towers/charactor/turretRanged/atk animation/turretRanged4_atk.png",
	],
	"DOT": [
		"res://assets/towers/charactor/turretDot/atk animation/turretDot1_atk.png",
		"res://assets/towers/charactor/turretDot/atk animation/turretDot2_atk.png",
		"res://assets/towers/charactor/turretDot/atk animation/turretDot3_atk.png",
		"res://assets/towers/charactor/turretDot/atk animation/turretDot4_atk.png",
	],
	"SLOW": [
		"res://assets/towers/charactor/turretSlow/atk animation/turretSlow1_atk.png",
		"res://assets/towers/charactor/turretSlow/atk animation/turretSlow2_atk.png",
		"res://assets/towers/charactor/turretSlow/atk animation/turretSlow3_atk.png",
		"res://assets/towers/charactor/turretSlow/atk animation/turretSlow4_atk.png",
	],
	"STUN": [
		"res://assets/towers/charactor/turretStun/atk animation/turretStun1_atk.png",
		"res://assets/towers/charactor/turretStun/atk animation/turretStun2_atk.png",
		"res://assets/towers/charactor/turretStun/atk animation/turretStun3_atk.png",
		"res://assets/towers/charactor/turretStun/atk animation/turretStun4_atk.png",
	],
}

# Web 빌드에서 대기·공격 시트 40장을 시작 시 한꺼번에 디코딩하면 전투 전부터
# 메모리를 크게 점유한다. 512px 제한으로 임포트하고 실제 배치된 타입·Tier의 시트만
# 처음 필요할 때 로드해 재사용한다.
static var idle_texture_cache: Dictionary = {}
static var idle_texture_requests: Dictionary = {}
static var attack_texture_cache: Dictionary = {}
static var attack_texture_requests: Dictionary = {}
static var last_animation_texture_load_frame: int = -1

# 정지 이미지는 투명 여백 없이 잘려 있으므로 전체 캔버스를 사용한다.
const BODY_VISIBLE_BOUNDS := {
	"MELEE": [Rect2(0, 0, 133, 146), Rect2(0, 0, 222, 260), Rect2(0, 0, 279, 343), Rect2(0, 0, 617, 420)],
	"RANGED": [Rect2(0, 0, 147, 175), Rect2(0, 0, 246, 235), Rect2(0, 0, 393, 318), Rect2(0, 0, 615, 491)],
	"DOT": [Rect2(0, 0, 117, 133), Rect2(0, 0, 230, 151), Rect2(0, 0, 256, 248), Rect2(0, 0, 430, 360)],
	"SLOW": [Rect2(0, 0, 162, 128), Rect2(0, 0, 189, 226), Rect2(0, 0, 221, 264), Rect2(0, 0, 287, 426)],
	"STUN": [Rect2(0, 0, 165, 109), Rect2(0, 0, 229, 160), Rect2(0, 0, 358, 314), Rect2(0, 0, 445, 396)],
}

# 512px 제한으로 임포트한 2프레임 대기 시트의 첫 프레임 불투명 영역이다.
const IDLE_FIRST_FRAME_VISIBLE_BOUNDS := {
	"MELEE": [Rect2(94.75, 97.5, 67, 73.25), Rect2(75, 77.25, 106, 123.75), Rect2(64.5, 58.25, 126, 154.25), Rect2(0.75, 61, 253, 172)],
	"RANGED": [Rect2(99, 93.75, 58, 68.75), Rect2(79.5, 82.25, 97, 91.5), Rect2(51.5, 66.25, 153.25, 123.5), Rect2(18.25, 42.25, 223, 178)],
	"DOT": [Rect2(105.25, 102, 45.5, 51.75), Rect2(83.25, 98.75, 89.25, 58.5), Rect2(78.25, 79.75, 99.5, 96.5), Rect2(44.5, 58, 167.25, 140)],
	"SLOW": [Rect2(96.5, 112.5, 63, 49.75), Rect2(91.25, 84, 73.5, 88), Rect2(85, 101, 86, 102.75), Rect2(72.25, 78.75, 111.75, 165.75)],
	"STUN": [Rect2(95.75, 108.25, 64.25, 42.25), Rect2(83.25, 97, 89.5, 62.25), Rect2(58.25, 66.75, 139.25, 122), Rect2(41.5, 47.75, 173, 154)],
}

# 각 시트의 좌상단(1번) 프레임에서 측정한 불투명 영역이다.
# 이 경계로 정지 이미지와 공격 시트의 육안 크기 및 발판 기준선을 맞춘다.
const ATTACK_FIRST_FRAME_VISIBLE_BOUNDS := {
	"MELEE": [Rect2(94.75, 97.5, 67, 73.25), Rect2(75, 77.25, 106, 123.75), Rect2(64.75, 58.25, 126, 154.25), Rect2(0.75, 61, 253, 172)],
	"RANGED": [Rect2(99, 93.75, 58, 68.75), Rect2(79.5, 82.25, 97, 91.5), Rect2(51.5, 66.25, 153.25, 123.5), Rect2(18.25, 42.25, 223, 178)],
	"DOT": [Rect2(105.25, 102, 45.5, 51.75), Rect2(83.25, 98.75, 89.25, 58.5), Rect2(78.25, 79.75, 99.5, 96.5), Rect2(44.5, 58, 167.25, 140)],
	"SLOW": [Rect2(96.5, 112.5, 63, 49.75), Rect2(91.25, 84, 73.5, 88), Rect2(85, 101, 86, 102.75), Rect2(72.25, 78.75, 111.75, 165.75)],
	"STUN": [Rect2(95.75, 108.25, 64.25, 42.25), Rect2(83.25, 97, 89.5, 62.25), Rect2(58.25, 66.75, 139.25, 122), Rect2(41.5, 47.75, 173, 154)],
}


static func body_texture(turret_type: String, tier: int) -> Texture2D:
	var textures: Array = BODY_TEXTURES.get(turret_type, BODY_TEXTURES["RANGED"])
	return textures[clampi(tier - 1, 0, textures.size() - 1)] as Texture2D


static func body_visible_bounds(turret_type: String, tier: int) -> Rect2:
	var bounds_by_tier: Array = BODY_VISIBLE_BOUNDS.get(turret_type, BODY_VISIBLE_BOUNDS["RANGED"])
	return bounds_by_tier[clampi(tier - 1, 0, bounds_by_tier.size() - 1)] as Rect2


static func idle_texture(turret_type: String, tier: int) -> Texture2D:
	var texture_path := idle_texture_path(turret_type, tier)
	if not idle_texture_cache.has(texture_path):
		idle_texture_cache[texture_path] = load(texture_path) as Texture2D
		idle_texture_requests.erase(texture_path)
	return idle_texture_cache[texture_path] as Texture2D


static func idle_texture_path(turret_type: String, tier: int) -> String:
	var paths: Array = IDLE_TEXTURE_PATHS.get(turret_type, IDLE_TEXTURE_PATHS["RANGED"])
	return str(paths[clampi(tier - 1, 0, paths.size() - 1)])


static func request_idle_texture(turret_type: String, tier: int) -> void:
	var texture_path := idle_texture_path(turret_type, tier)
	if idle_texture_cache.has(texture_path) or idle_texture_requests.has(texture_path):
		return
	idle_texture_requests[texture_path] = true


static func try_get_idle_texture(turret_type: String, tier: int) -> Texture2D:
	var texture_path := idle_texture_path(turret_type, tier)
	if idle_texture_cache.has(texture_path):
		return idle_texture_cache[texture_path] as Texture2D
	if not idle_texture_requests.has(texture_path):
		request_idle_texture(turret_type, tier)
		return null
	var current_frame := Engine.get_process_frames()
	if current_frame == last_animation_texture_load_frame:
		return null
	last_animation_texture_load_frame = current_frame
	var texture := load(texture_path) as Texture2D
	idle_texture_requests.erase(texture_path)
	if texture != null:
		idle_texture_cache[texture_path] = texture
	return texture


static func idle_first_frame_visible_bounds(turret_type: String, tier: int) -> Rect2:
	var bounds_by_tier: Array = IDLE_FIRST_FRAME_VISIBLE_BOUNDS.get(turret_type, IDLE_FIRST_FRAME_VISIBLE_BOUNDS["RANGED"])
	return bounds_by_tier[clampi(tier - 1, 0, bounds_by_tier.size() - 1)] as Rect2


static func attack_texture(turret_type: String, tier: int) -> Texture2D:
	var texture_path := attack_texture_path(turret_type, tier)
	if not attack_texture_cache.has(texture_path):
		attack_texture_cache[texture_path] = load(texture_path) as Texture2D
		attack_texture_requests.erase(texture_path)
	return attack_texture_cache[texture_path] as Texture2D


static func attack_texture_path(turret_type: String, tier: int) -> String:
	var paths: Array = ATTACK_TEXTURE_PATHS.get(turret_type, ATTACK_TEXTURE_PATHS["RANGED"])
	return str(paths[clampi(tier - 1, 0, paths.size() - 1)])


# 공격 시트가 필요함을 큐에 기록한다. 단일 스레드 Web에서는 ResourceLoader의 threaded
# API가 여러 타입 동시 요청 중 WASM null-function 크래시를 낼 수 있어 사용하지 않는다.
static func request_attack_texture(turret_type: String, tier: int) -> void:
	var texture_path := attack_texture_path(turret_type, tier)
	if attack_texture_cache.has(texture_path) or attack_texture_requests.has(texture_path):
		return
	attack_texture_requests[texture_path] = true


# 한 프레임에 최대 한 장만 동기 로드해 큰 공격 시트 여러 장이 같은 입력 프레임을 막지
# 않게 한다. 나머지 타워는 다음 프레임까지 정지 본체를 유지한다.
static func try_get_attack_texture(turret_type: String, tier: int) -> Texture2D:
	var texture_path := attack_texture_path(turret_type, tier)
	if attack_texture_cache.has(texture_path):
		return attack_texture_cache[texture_path] as Texture2D
	if not attack_texture_requests.has(texture_path):
		request_attack_texture(turret_type, tier)
		return null
	var current_frame := Engine.get_process_frames()
	if current_frame == last_animation_texture_load_frame:
		return null
	last_animation_texture_load_frame = current_frame
	var texture := load(texture_path) as Texture2D
	attack_texture_requests.erase(texture_path)
	if texture != null:
		attack_texture_cache[texture_path] = texture
	return texture


static func attack_first_frame_visible_bounds(turret_type: String, tier: int) -> Rect2:
	var bounds_by_tier: Array = ATTACK_FIRST_FRAME_VISIBLE_BOUNDS.get(turret_type, ATTACK_FIRST_FRAME_VISIBLE_BOUNDS["RANGED"])
	return bounds_by_tier[clampi(tier - 1, 0, bounds_by_tier.size() - 1)] as Rect2
