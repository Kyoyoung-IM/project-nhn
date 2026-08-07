class_name PrototypeMonster
extends Node2D

# 밤에 생성되는 몬스터 한 개의 이동·피격·상태 이상을 담당한다.
# 실제 플랫폼 물리 없이 고정 웨이포인트와 상태 전환으로 층을 이동한다.

# 처치와 최심부 도달은 보상/패배 처리를 위해 게임 컨트롤러에 알린다.
signal defeated(monster: PrototypeMonster)
signal reached_deepest_floor(monster: PrototypeMonster)

# SPAWNING부터 DEAD까지 몬스터의 현재 행동을 명시적으로 구분한다.
enum MoveState { SPAWNING, WALKING, DESCENDING, STUNNED, EXIT, DEAD }

# 몬스터 노드의 등장·층 이동 연출 배율이다. 실제 스프라이트 크기는 타입별 텍스처
# 배율과 이 노드 배율을 나눠 적용하며, 접지 오프셋을 함께 적용해 발판 접촉을 유지한다.
const MONSTER_VISUAL_SCALE := 1.6
const STUN_STATUS_TEXTURE := preload("res://assets/combat_vfx/status_stun_stars_v2.png")
const STUN_STATUS_DRAW_SIZE := Vector2(126.0, 84.0)
# 일반형의 기존 표시 크기를 보존하는 원본 픽셀 공통 배율이다. SPEED와 TANK에도
# 같은 값을 적용해 불투명 그림의 절대 픽셀 크기 차이가 화면 크기 차이로 이어지게 한다.
const REGULAR_TEXTURE_SCALE := 0.654589271
const BOSS_VISIBLE_HEIGHT := 440.0
const HEALTH_BAR_HEIGHT := 4.0
const HEALTH_BAR_HEAD_GAP := 10.0
const HIT_VISUAL_DURATION_SEC := 0.25
const HIT_VISUAL_STACK_SEC := 0.1
const DEATH_FRAME_SIZE := Vector2(512.0, 512.0)
const DEATH_FRAME_COUNT := 5
const DEATH_FRAME_DURATION_SEC := 0.12
const DEATH_ANIMATION_DURATION_SEC := DEATH_FRAME_COUNT * DEATH_FRAME_DURATION_SEC

const MONSTER_TEXTURES := {
	"NORMAL": preload("res://assets/enemy/normal1.png"),
	"SPEED": preload("res://assets/enemy/spped1.png"),
	"TANK": preload("res://assets/enemy/tank1.png"),
	"BOSS": preload("res://assets/enemy/boss1.png"),
}

const MONSTER_HIT_TEXTURES := {
	"NORMAL": preload("res://assets/enemy/hit animation/normal1_hit.png"),
	"SPEED": preload("res://assets/enemy/hit animation/spped1_hit.png"),
	"TANK": preload("res://assets/enemy/hit animation/tank1_hit.png"),
	"BOSS": preload("res://assets/enemy/hit animation/boss1_hit.png"),
}

const MONSTER_DEATH_TEXTURES := {
	"NORMAL": preload("res://assets/enemy/death animation/normal1_death.png"),
	"SPEED": preload("res://assets/enemy/death animation/speed1_death.png"),
	"TANK": preload("res://assets/enemy/death animation/tank_death.png"),
	"BOSS": preload("res://assets/enemy/death animation/boss1_death.png"),
}

# 사망 시트의 다섯 프레임에서 가장 낮은 불투명 픽셀 위치다. 모든 프레임에 같은
# 접지선을 적용해 쓰러지는 자세가 바뀌어도 발판 위에서 위아래로 흔들리지 않게 한다.
const MONSTER_DEATH_FLOOR_Y := {
	"NORMAL": 362.0,
	"SPEED": 444.0,
	"TANK": 416.0,
	"BOSS": 492.0,
}

# 512px 원본 안에서 알파가 있는 실제 그림 경계다. 캔버스 여백을 제외하고 실제 그림의
# 크기와 중심, 발끝을 계산하되 일반 몬스터 사이의 원본 픽셀 크기 차이는 보존한다.
const MONSTER_VISIBLE_BOUNDS := {
	"NORMAL": Rect2(164.0, 146.0, 184.0, 221.0),
	"SPEED": Rect2(94.0, 121.0, 325.0, 271.0),
	"TANK": Rect2(124.0, 83.0, 262.0, 345.0),
	"BOSS": Rect2(4.0, 21.0, 502.0, 469.0),
}

const MONSTER_HIT_VISIBLE_BOUNDS := {
	"NORMAL": Rect2(198.0, 120.0, 184.0, 240.0),
	"SPEED": Rect2(147.0, 80.0, 307.0, 364.0),
	"TANK": Rect2(137.0, 12.0, 319.0, 403.0),
	"BOSS": Rect2(44.0, 3.0, 459.0, 500.0),
}

# 데이터 식별자와 표시용 속성이다.
var monster_id: String = ""
var display_name: String = ""
var monster_type: String = "NORMAL"

# 기본 전투 능력치다. 원본 Monster 컬럼과 표시용 prototypeExtensions를 정규화한 값이다.
var max_hp: float = 1.0
var hp: float = 1.0
var move_speed_px_sec: float = 1.0
var reward_gold: int = 0
var body_visible_world_size := Vector2.ZERO
var body_sprite: Sprite2D
var hit_sprite: Sprite2D
var death_sprite: Sprite2D
var hit_visual_remaining_sec: float = 0.0
var death_animation_elapsed_sec: float = 0.0
# 처음 피해를 받기 전에는 체력 바를 숨기고, 첫 유효 피해부터 남은 전투 동안 표시한다.
var health_bar_visible: bool = false
var health_bar: ProgressBar

# 터렛의 STUN, SLOW, DOT 효과를 초 단위 런타임 상태로 보관한다.
var stun_remaining_sec: float = 0.0
var slow_remaining_sec: float = 0.0
var slow_multiplier: float = 1.0
var dot_remaining_sec: float = 0.0
var dot_tick_damage: float = 0.0
var dot_tick_cooldown_sec: float = 0.0

# 현재 웨이포인트와 지상→B1→B2→B3 진행 상태다.
var path_points := PackedVector2Array()
var path_index: int = 0
var move_state: MoveState = MoveState.SPAWNING
var spawn_animation_sec: float = 0.24
var spawn_floor_contact_position := Vector2.ZERO

# 한 층의 왼쪽 출구에서 다음 층 오른쪽 입구로 이동하는 축소/확대 연출 상태다.
var floor_transfer_active: bool = false
var floor_transfer_repositioned: bool = false
var floor_transfer_remaining_sec: float = 0.0
var floor_transfer_destination_index: int = -1
var floor_transfer_duration_sec: float = 0.36

# 경로 좌표는 몬스터 중심이 아니라 발판에 닿아야 하는 바닥 접촉점으로 전달된다.
var body_bottom_offset_y: float = 16.0
var visual_elapsed_sec: float = 0.0


# 로더가 정규화한 몬스터 데이터와 공유 이동 경로를 복사해 초기 상태를 만든다.
func setup(config: Dictionary, movement_path: PackedVector2Array) -> void:
	health_bar = get_node_or_null("HealthBar") as ProgressBar
	monster_id = str(config.get("id", ""))
	display_name = str(config.get("display_name", monster_id))
	monster_type = str(config.get("type", "NORMAL"))
	max_hp = float(config.get("max_hp", 1.0))
	hp = max_hp
	move_speed_px_sec = float(config.get("move_speed_px_sec", 1.0))
	reward_gold = int(config.get("reward_gold", 0))
	body_visible_world_size = _visible_world_size_for_type(monster_type)
	body_bottom_offset_y = _body_bottom_offset_for_type(monster_type)
	_configure_body_sprite()
	_configure_hit_sprite()
	_configure_death_sprite()
	health_bar_visible = false
	_configure_health_bar_layout()
	_update_health_bar()
	stun_remaining_sec = 0.0
	slow_remaining_sec = 0.0
	slow_multiplier = 1.0
	dot_remaining_sec = 0.0
	dot_tick_damage = 0.0
	dot_tick_cooldown_sec = 0.0
	hit_visual_remaining_sec = 0.0
	death_animation_elapsed_sec = 0.0
	_set_hit_visual_active(false)
	_set_death_visual_active(false)
	path_points.clear()
	for floor_contact_point in movement_path:
		path_points.append(center_position_for_floor_contact(floor_contact_point))
	position = path_points[0]
	spawn_floor_contact_position = position + Vector2(0.0, body_bottom_offset_y)
	path_index = 0
	move_state = MoveState.SPAWNING
	scale = Vector2.ZERO
	# 같은 전장 CanvasItem 안에서 설치 터렛보다 앞, 투사체·피격 이펙트보다 뒤에 표시한다.
	z_index = 30
	add_to_group("prototype_monsters")
	_queue_status_redraw()
	_update_health_bar()


# 테스트 밸런스 편집을 살아 있는 몬스터에도 반영하되 현재 체력 비율과 이동 상태는 유지한다.
func apply_runtime_balance(config: Dictionary) -> void:
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = maxf(0.001, float(config.get("max_hp", max_hp)))
	hp = clampf(max_hp * hp_ratio, 0.0, max_hp)
	move_speed_px_sec = maxf(0.001, float(config.get("move_speed_px_sec", move_speed_px_sec)))
	reward_gold = int(config.get("reward_gold", reward_gold))
	_update_health_bar()
	_queue_status_redraw()


# 타입별 텍스처와 실제 그림 경계를 반환한다.
static func _texture_for_type(type_value: String) -> Texture2D:
	return MONSTER_TEXTURES.get(type_value, MONSTER_TEXTURES["NORMAL"]) as Texture2D


static func _visible_bounds_for_type(type_value: String) -> Rect2:
	return MONSTER_VISIBLE_BOUNDS.get(type_value, MONSTER_VISIBLE_BOUNDS["NORMAL"]) as Rect2


static func _hit_texture_for_type(type_value: String) -> Texture2D:
	return MONSTER_HIT_TEXTURES.get(type_value, MONSTER_HIT_TEXTURES["NORMAL"]) as Texture2D


static func _hit_visible_bounds_for_type(type_value: String) -> Rect2:
	return MONSTER_HIT_VISIBLE_BOUNDS.get(type_value, MONSTER_HIT_VISIBLE_BOUNDS["NORMAL"]) as Rect2


static func _death_texture_for_type(type_value: String) -> Texture2D:
	return MONSTER_DEATH_TEXTURES.get(type_value, MONSTER_DEATH_TEXTURES["NORMAL"]) as Texture2D


static func _death_floor_y_for_type(type_value: String) -> float:
	return float(MONSTER_DEATH_FLOOR_Y.get(type_value, MONSTER_DEATH_FLOOR_Y["NORMAL"]))


# 일반 몬스터에는 원본 픽셀 크기 차이를 보존하는 공통 배율을 적용하고, 보스만 한 층보다
# 약간 작은 기존 높이에 맞춘다. 가로·세로에 같은 값을 적용해 종횡비를 보존한다.
static func _texture_scale_for_type(type_value: String) -> float:
	var bounds := _visible_bounds_for_type(type_value)
	if type_value == "BOSS":
		return BOSS_VISIBLE_HEIGHT / maxf(1.0, bounds.size.y)
	return REGULAR_TEXTURE_SCALE


static func _visible_world_size_for_type(type_value: String) -> Vector2:
	return _visible_bounds_for_type(type_value).size * _texture_scale_for_type(type_value)


# 본체 이미지는 상태이상 redraw와 분리된 고정 Sprite2D로 유지한다. 투명 캔버스 안의
# 실제 그림 중심을 노드 원점에 맞추되 가로·세로에는 항상 같은 배율을 적용한다.
func _configure_body_sprite() -> void:
	if body_sprite == null:
		body_sprite = Sprite2D.new()
		body_sprite.name = "BodySprite"
		body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		body_sprite.z_index = -1
		add_child(body_sprite)
	var texture := _texture_for_type(monster_type)
	var bounds := _visible_bounds_for_type(monster_type)
	var local_texture_scale := _texture_scale_for_type(monster_type) / MONSTER_VISUAL_SCALE
	var texture_center := texture.get_size() * 0.5
	var visible_center := bounds.position + bounds.size * 0.5
	body_sprite.texture = texture
	body_sprite.position = -(visible_center - texture_center) * local_texture_scale
	body_sprite.scale = Vector2.ONE * local_texture_scale


# 피격 이미지는 본체와 같은 원본 픽셀 배율을 사용하고, 자세가 달라도 발끝은 기존
# 접지선에 고정한다. 평소에는 본체만, 직접 피해 중에는 피격 이미지만 표시한다.
func _configure_hit_sprite() -> void:
	if hit_sprite == null:
		hit_sprite = Sprite2D.new()
		hit_sprite.name = "HitSprite"
		hit_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		hit_sprite.z_index = -1
		add_child(hit_sprite)
	var texture := _hit_texture_for_type(monster_type)
	var bounds := _hit_visible_bounds_for_type(monster_type)
	var local_texture_scale := _texture_scale_for_type(monster_type) / MONSTER_VISUAL_SCALE
	var texture_center := texture.get_size() * 0.5
	var visible_center_x := bounds.position.x + bounds.size.x * 0.5
	var local_body_bottom := body_bottom_offset_y / MONSTER_VISUAL_SCALE
	hit_sprite.texture = texture
	hit_sprite.position = Vector2(
		-(visible_center_x - texture_center.x) * local_texture_scale,
		local_body_bottom - (bounds.end.y - texture_center.y) * local_texture_scale
	)
	hit_sprite.scale = Vector2.ONE * local_texture_scale
	hit_sprite.visible = false


# 사망 이미지는 512×512 프레임 다섯 장이 세로로 이어진 시트다. 본체와 같은 픽셀
# 배율 및 공통 접지선을 사용하고 region_rect만 바꿔 추가 텍스처 생성 없이 재생한다.
func _configure_death_sprite() -> void:
	if death_sprite == null:
		death_sprite = Sprite2D.new()
		death_sprite.name = "DeathSprite"
		death_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		death_sprite.z_index = -1
		death_sprite.region_enabled = true
		add_child(death_sprite)
	var local_texture_scale := _texture_scale_for_type(monster_type) / MONSTER_VISUAL_SCALE
	var local_body_bottom := body_bottom_offset_y / MONSTER_VISUAL_SCALE
	death_sprite.texture = _death_texture_for_type(monster_type)
	death_sprite.region_rect = Rect2(Vector2.ZERO, DEATH_FRAME_SIZE)
	death_sprite.position = Vector2(
		0.0,
		local_body_bottom - (_death_floor_y_for_type(monster_type) - DEATH_FRAME_SIZE.y * 0.5) * local_texture_scale
	)
	death_sprite.scale = Vector2.ONE * local_texture_scale
	death_sprite.visible = false


# 스프라이트의 실제 최하단을 중심점 기준으로 반환해 종류별 뜨거나 파묻히는 차이를 없앤다.
static func _body_bottom_offset_for_type(type_value: String) -> float:
	return _visible_world_size_for_type(type_value).y * 0.5


func center_position_for_floor_contact(floor_contact_position: Vector2) -> Vector2:
	return floor_contact_position - Vector2(0.0, body_bottom_offset_y)


# 상태 이상, 등장 연출과 웨이포인트 이동을 우선순위대로 처리한다.
func _process(delta: float) -> void:
	visual_elapsed_sec += delta
	if move_state == MoveState.DEAD:
		_process_death_animation(delta)
		return
	_process_status_effects(delta)
	if move_state == MoveState.DEAD:
		return
	_process_hit_visual(delta)
	if move_state == MoveState.SPAWNING:
		spawn_animation_sec -= delta
		var reveal := clampf(1.0 - spawn_animation_sec / 0.24, 0.0, 1.0)
		scale = Vector2.ONE * MONSTER_VISUAL_SCALE * reveal
		# 중심 확대 중에도 도형의 실제 발끝을 지면에 고정해 지상 진입 시 공중부양처럼 보이지 않게 한다.
		position = spawn_floor_contact_position - Vector2(0.0, body_bottom_offset_y * reveal)
		if spawn_animation_sec <= 0.0:
			scale = Vector2.ONE * MONSTER_VISUAL_SCALE
			position = center_position_for_floor_contact(spawn_floor_contact_position)
			move_state = MoveState.WALKING
		return

	if move_state == MoveState.DEAD or move_state == MoveState.EXIT:
		return
	if stun_remaining_sec > 0.0:
		move_state = MoveState.STUNNED
		return

	if floor_transfer_active:
		_process_floor_transfer(delta)
		return
	if _is_floor_transfer_origin():
		_begin_floor_transfer()
		return

	if path_index >= path_points.size() - 1:
		_reach_deepest_floor()
		return

	var target := path_points[path_index + 1]
	var offset := target - position
	move_state = MoveState.DESCENDING if absf(offset.y) > absf(offset.x) else MoveState.WALKING
	position = position.move_toward(target, move_speed_px_sec * slow_multiplier * delta)

	if position.is_equal_approx(target):
		path_index += 1
		if path_index >= path_points.size() - 1:
			_reach_deepest_floor()


# 경로 인덱스 2는 지상 광산 입구, 4/6은 B1/B2 왼쪽 출구이므로 하강 연출을 시작한다.
func _is_floor_transfer_origin() -> bool:
	return path_index == 2 or path_index == 4 or path_index == 6


# 다음 전투층의 오른쪽 입구를 목적지로 지정하고 DESCENDING 상태로 바꾼다.
func _begin_floor_transfer() -> void:
	floor_transfer_active = true
	floor_transfer_repositioned = false
	floor_transfer_remaining_sec = floor_transfer_duration_sec
	floor_transfer_destination_index = path_index + 1
	move_state = MoveState.DESCENDING


# 연출 중간에 목적지로 재배치하고 크기를 복원해 순간 이동을 부드럽게 보이게 한다.
func _process_floor_transfer(delta: float) -> void:
	floor_transfer_remaining_sec = maxf(0.0, floor_transfer_remaining_sec - delta)
	var progress := 1.0 - floor_transfer_remaining_sec / floor_transfer_duration_sec
	var transition_scale := 1.0 - sin(progress * PI) * 0.78
	scale = Vector2.ONE * MONSTER_VISUAL_SCALE * transition_scale
	if progress >= 0.5 and not floor_transfer_repositioned:
		position = path_points[floor_transfer_destination_index]
		floor_transfer_repositioned = true
	if floor_transfer_remaining_sec <= 0.0:
		path_index = floor_transfer_destination_index
		floor_transfer_active = false
		floor_transfer_destination_index = -1
		scale = Vector2.ONE * MONSTER_VISUAL_SCALE
		move_state = MoveState.WALKING


# 즉시 피해를 적용하고 체력이 0이 되면 보상 처리를 위한 처치 신호를 보낸 뒤
# 사망 애니메이션을 시작한다. 실제 노드 제거는 마지막 프레임 재생 후 처리한다.
func take_damage(amount: float, show_hit_visual: bool = true) -> void:
	if move_state == MoveState.DEAD or move_state == MoveState.EXIT:
		return
	if amount > 0.0 and hp > 0.0:
		health_bar_visible = true
		if show_hit_visual:
			_show_hit_visual()
	hp = maxf(0.0, hp - amount)
	_update_health_bar()
	_queue_status_redraw()
	if hp <= 0.0:
		move_state = MoveState.DEAD
		_begin_death_animation()
		defeated.emit(self)


# 터렛 타입에 따라 기본 피해와 DOT/STUN/SLOW를 적용한다.
# BOSS는 명세에 따라 상태 이상 지속시간과 감속량을 50%만 받는다.
func receive_turret_hit(amount: float, source_type: String, cc_duration: float, cc_value: float) -> void:
	take_damage(amount)
	if move_state == MoveState.DEAD:
		return
	var boss_factor := 0.5 if monster_type == "BOSS" else 1.0
	match source_type:
		"DOT":
			dot_remaining_sec = maxf(dot_remaining_sec, cc_duration * boss_factor)
			dot_tick_damage = maxf(dot_tick_damage, amount * cc_value)
			dot_tick_cooldown_sec = minf(dot_tick_cooldown_sec, 0.35)
		"STUN":
			stun_remaining_sec = maxf(stun_remaining_sec, cc_duration * boss_factor)
		"SLOW":
			slow_remaining_sec = maxf(slow_remaining_sec, cc_duration * boss_factor)
			slow_multiplier = minf(slow_multiplier, clampf(1.0 - cc_value * boss_factor, 0.2, 1.0))
	_queue_status_redraw()


# 매 프레임 상태 이상 시간을 감소시키고 DOT의 1초 주기 피해를 처리한다.
func _process_status_effects(delta: float) -> void:
	var status_visual_was_active := stun_remaining_sec > 0.0 or slow_remaining_sec > 0.0 or dot_remaining_sec > 0.0
	if stun_remaining_sec > 0.0:
		stun_remaining_sec = maxf(0.0, stun_remaining_sec - delta)
	if slow_remaining_sec > 0.0:
		slow_remaining_sec = maxf(0.0, slow_remaining_sec - delta)
		if slow_remaining_sec <= 0.0:
			slow_multiplier = 1.0
	if dot_remaining_sec > 0.0:
		dot_remaining_sec = maxf(0.0, dot_remaining_sec - delta)
		dot_tick_cooldown_sec -= delta
		if dot_tick_cooldown_sec <= 0.0:
			# 화상의 주기 피해는 체력만 줄이고 피격 이미지는 다시 표시하지 않는다.
			take_damage(dot_tick_damage, false)
			dot_tick_cooldown_sec += 1.0
		if dot_remaining_sec <= 0.0:
			dot_tick_damage = 0.0
	# 이동은 CanvasItem 변환만 바꾸므로 도형 명령을 다시 만들 필요가 없다. 상태 표시가
	# 실제로 보이는 동안에만 갱신해 다수 몬스터가 쌓여도 Web 메인 스레드 부하가 증가하지 않게 한다.
	if status_visual_was_active or stun_remaining_sec > 0.0 or slow_remaining_sec > 0.0 or dot_remaining_sec > 0.0:
		_queue_status_redraw()


# 직접 명중 시 새 재생은 0.25초, 이미 재생 중인 명중은 남은 시간에 0.1초를 더한다.
func _show_hit_visual() -> void:
	if hit_visual_remaining_sec > 0.0:
		hit_visual_remaining_sec += HIT_VISUAL_STACK_SEC
	else:
		hit_visual_remaining_sec = HIT_VISUAL_DURATION_SEC
	_set_hit_visual_active(true)


func _process_hit_visual(delta: float) -> void:
	if hit_visual_remaining_sec <= 0.0:
		return
	hit_visual_remaining_sec = maxf(0.0, hit_visual_remaining_sec - delta)
	if hit_visual_remaining_sec <= 0.0:
		_set_hit_visual_active(false)


func _set_hit_visual_active(active: bool) -> void:
	if body_sprite != null:
		body_sprite.visible = not active
	if hit_sprite != null:
		hit_sprite.visible = active


func _begin_death_animation() -> void:
	death_animation_elapsed_sec = 0.0
	hit_visual_remaining_sec = 0.0
	stun_remaining_sec = 0.0
	slow_remaining_sec = 0.0
	dot_remaining_sec = 0.0
	dot_tick_damage = 0.0
	health_bar_visible = false
	_update_health_bar()
	_set_hit_visual_active(false)
	_set_death_visual_active(true)
	_set_death_animation_frame(0)
	_queue_status_redraw()


func _process_death_animation(delta: float) -> void:
	death_animation_elapsed_sec += delta
	if death_animation_elapsed_sec >= DEATH_ANIMATION_DURATION_SEC:
		queue_free()
		return
	var frame_index := mini(
		int(death_animation_elapsed_sec / DEATH_FRAME_DURATION_SEC),
		DEATH_FRAME_COUNT - 1
	)
	_set_death_animation_frame(frame_index)


func _set_death_animation_frame(frame_index: int) -> void:
	if death_sprite == null:
		return
	death_sprite.region_rect = Rect2(
		Vector2(0.0, float(frame_index) * DEATH_FRAME_SIZE.y),
		DEATH_FRAME_SIZE
	)


func _set_death_visual_active(active: bool) -> void:
	if body_sprite != null:
		body_sprite.visible = not active
	if hit_sprite != null:
		hit_sprite.visible = false
	if death_sprite != null:
		death_sprite.visible = active


# Web에서는 피해로 죽는 프레임에 redraw 예약과 queue_free가 겹치면 해제된
# GDScript draw 콜백을 호출하는 WASM null-function 크래시가 발생할 수 있다.
# 체력 바와 본체 Sprite2D는 별도 노드이므로 Web에서는 이 동적 draw 예약을 생략한다.
func _queue_status_redraw() -> void:
	if not OS.has_feature("web"):
		queue_redraw()


# 지상 진입과 층간 하강을 제외하고 터렛이 공격할 수 있는 전투층인지 반환한다.
func is_in_combat_floor() -> bool:
	return current_combat_floor() >= 0 and not floor_transfer_active and move_state != MoveState.DEAD and move_state != MoveState.EXIT


# 경로 인덱스를 B1=0, B2=1, B3=2로 변환한다. 전투층 밖이면 -1이다.
func current_combat_floor() -> int:
	match path_index:
		3:
			return 0
		5:
			return 1
		7:
			return 2
	return -1


# 터렛 표적 우선순위용 진행도다. 경로 인덱스가 높을수록 코어에 더 가깝다.
func progress_score() -> float:
	if path_points.is_empty():
		return 0.0
	var score := float(path_index) * 10000.0
	if path_index < path_points.size() - 1:
		score -= position.distance_to(path_points[path_index + 1])
	return score


# B3 왼쪽 끝에 도달했음을 한 번만 알리고 자신을 장면에서 제거한다.
func _reach_deepest_floor() -> void:
	if move_state == MoveState.EXIT:
		return
	move_state = MoveState.EXIT
	reached_deepest_floor.emit(self)
	queue_free()


# 본체 스프라이트는 고정 자식 노드가 담당한다. 여기서는 지속시간에 따라 바뀌는 상태
# 연출만 다시 그려 Web 전투 중 텍스처 드로우 명령이 반복 재생성되지 않게 한다.
func _draw() -> void:
	if OS.has_feature("web"):
		return
	var local_visible_size := body_visible_world_size / MONSTER_VISUAL_SCALE
	var local_half_height := body_bottom_offset_y / MONSTER_VISUAL_SCALE
	if stun_remaining_sec > 0.0:
		# 생성된 별 헤일로가 실제 기절 시간 동안 머리 위에서 가볍게 흔들리도록 표시한다.
		var stun_wobble := sin(visual_elapsed_sec * 7.0) * 4.0
		draw_texture_rect(
			STUN_STATUS_TEXTURE,
			Rect2(Vector2(-STUN_STATUS_DRAW_SIZE.x * 0.5 + stun_wobble, -local_half_height - STUN_STATUS_DRAW_SIZE.y * 0.8), STUN_STATUS_DRAW_SIZE),
			false
		)
	if slow_remaining_sec > 0.0:
		var slow_radius := minf(local_visible_size.x, local_visible_size.y) * 0.42
		draw_arc(Vector2.ZERO, slow_radius, 0.0, TAU, 32, Color("8fffea"), 2.0)
	if dot_remaining_sec > 0.0:
		draw_circle(Vector2(0.0, local_half_height - 4.0), 4.0, Color("d99aff"))


func _configure_health_bar_layout() -> void:
	if health_bar == null:
		return
	var bar_width_world := 180.0 if monster_type == "BOSS" else 84.0
	var bar_top_world := -body_bottom_offset_y - HEALTH_BAR_HEAD_GAP
	var target_local_height := HEALTH_BAR_HEIGHT / MONSTER_VISUAL_SCALE
	health_bar.position = Vector2(-bar_width_world * 0.5, bar_top_world) / MONSTER_VISUAL_SCALE
	health_bar.size = Vector2(bar_width_world / MONSTER_VISUAL_SCALE, target_local_height)
	# ProgressBar의 테마 최소 높이가 요청 두께보다 크므로 위쪽 가장자리를 기준으로 세로만
	# 축소한다. 부모 노드 배율까지 적용된 최종 화면 두께는 HEALTH_BAR_HEIGHT가 된다.
	health_bar.pivot_offset = Vector2.ZERO
	health_bar.scale = Vector2(1.0, target_local_height / maxf(target_local_height, health_bar.size.y))


# 체력 바의 배치·크기·스타일은 monster.tscn에서 편집하고 현재 수치와 표시 여부만 연결한다.
func _update_health_bar() -> void:
	if health_bar == null:
		health_bar = get_node_or_null("HealthBar") as ProgressBar
	if health_bar == null:
		return
	health_bar.max_value = maxf(max_hp, 0.001)
	health_bar.value = clampf(hp, 0.0, health_bar.max_value)
	health_bar.visible = health_bar_visible
