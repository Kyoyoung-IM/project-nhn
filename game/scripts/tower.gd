class_name PrototypeTower
extends Node2D

# 한 개의 배치된 터렛 오브젝트를 담당한다.
# 데이터베이스에서 정규화된 설정을 받아 표적 선택, 공격, 체력, 타입별 연출을 처리한다.

# 체력이 0이 되면 슬롯을 비울 수 있도록 게임 컨트롤러에 자신을 전달한다.
signal tower_destroyed(tower: PrototypeTower)

# 데이터 식별자와 머지 트리 정보다. 현재 머지 UI가 추가되면 이 값을 그대로 사용한다.
var turret_id: String = ""
var display_name: String = ""
var turret_type: String = "RANGED"
var next_turret_id: String = "-1"
var tier: int = 1

# 전투 능력치다. 모두 prototype_turrets.json에서 로드된 PLACEHOLDER 값이다.
var max_hp: float = 1.0
var hp: float = 1.0
var damage: float = 1.0
var attack_interval_sec: float = 1.0
var attack_range_px: float = 100.0
var cc_duration: float = 0.0
var cc_value: float = 0.0

# 렌더링 색상과 현재 배치된 전투층 인덱스다.
var tower_color := Color("68d8c1")
var floor_index: int = 0

# 공격 재사용 대기시간 및 짧은 광선 피드백 상태다.
var cooldown_sec: float = 0.0
var enabled: bool = true
var beam_end := Vector2.ZERO
var beam_visible_sec: float = 0.0


# 로더가 만든 내부 설정을 복사하고 해당 층의 터렛 그룹에 등록한다.
func setup(config: Dictionary, assigned_floor_index: int) -> void:
	turret_id = str(config.get("id", ""))
	display_name = str(config.get("display_name", turret_id))
	turret_type = str(config.get("type", "RANGED"))
	next_turret_id = str(config.get("next_turret_id", "-1"))
	tier = int(config.get("tier", 1))
	max_hp = float(config.get("max_hp", 1.0))
	hp = max_hp
	damage = float(config.get("damage", 1.0))
	attack_interval_sec = float(config.get("attack_interval_sec", 1.0))
	attack_range_px = float(config.get("range_px", 100.0))
	cc_duration = float(config.get("cc_duration", 0.0))
	cc_value = float(config.get("cc_value", 0.0))
	tower_color = Color(str(config.get("color_hex", "68d8c1")))
	floor_index = assigned_floor_index
	cooldown_sec = 0.0
	add_to_group("prototype_towers")
	queue_redraw()


# 새 웨이브 시작 시 공격 가능 상태와 시각 효과 타이머를 초기화한다.
# 체력 회복은 웨이브 클리어 시점에 게임 컨트롤러가 별도로 요청한다.
func reset_for_wave() -> void:
	enabled = true
	cooldown_sec = 0.0
	beam_visible_sec = 0.0
	queue_redraw()


# 웨이브 클리어 보상으로 생존 터렛의 체력을 최대치까지 회복한다.
func restore_full_health() -> void:
	hp = max_hp
	queue_redraw()


# 몬스터 공격 피해를 적용하고 체력이 소진되면 파괴 신호를 보낸다.
func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	queue_redraw()
	if hp <= 0.0:
		enabled = false
		tower_destroyed.emit(self)
		queue_free()


# 공격 간격을 갱신하고 같은 층·사거리 안의 최우선 몬스터를 자동 공격한다.
func _process(delta: float) -> void:
	if beam_visible_sec > 0.0:
		beam_visible_sec -= delta
		queue_redraw()

	if not enabled:
		return

	cooldown_sec = maxf(0.0, cooldown_sec - delta)
	if cooldown_sec > 0.0:
		return

	var target := _select_target()
	if target == null:
		return

	target.receive_turret_hit(damage, turret_type, cc_duration, cc_value)
	beam_end = to_local(target.global_position)
	beam_visible_sec = 0.09
	cooldown_sec = attack_interval_sec
	queue_redraw()


# 같은 전투층에서 수평 사거리 안에 있으며 코어 진행도가 가장 높은 몬스터를 선택한다.
# 포탑과 경로의 수직 좌표 차이는 화면 연출용이므로 사거리 계산에서 제외한다.
func _select_target() -> PrototypeMonster:
	var selected: PrototypeMonster = null
	var best_progress := -INF
	for node in get_tree().get_nodes_in_group("prototype_monsters"):
		var monster := node as PrototypeMonster
		if monster == null or not monster.is_in_combat_floor():
			continue
		if monster.current_combat_floor() != floor_index:
			continue
		var horizontal_distance := absf(global_position.x - monster.global_position.x)
		if horizontal_distance > attack_range_px:
			continue
		var progress := monster.progress_score()
		if progress > best_progress:
			best_progress = progress
			selected = monster
	return selected


# 외부 이미지가 없는 프로토타입이므로 타입별 도형과 체력 바를 직접 그린다.
func _draw() -> void:
	# PLACEHOLDER tower objects: table-driven colors and type silhouettes.
	draw_circle(Vector2.ZERO, 24.0, Color("29384f"))
	draw_circle(Vector2.ZERO, 19.0, tower_color)
	match turret_type:
		"MELEE":
			draw_colored_polygon(PackedVector2Array([Vector2(-5.0, -32.0), Vector2(6.0, -32.0), Vector2(12.0, -4.0), Vector2(-11.0, -4.0)]), tower_color.lightened(0.32))
			draw_line(Vector2(-12.0, -10.0), Vector2(12.0, -10.0), Color("fff5de"), 4.0)
		"DOT":
			draw_circle(Vector2(0.0, -13.0), 12.0, tower_color.lightened(0.28))
			draw_circle(Vector2(0.0, -13.0), 5.0, Color("2a1738"))
		"STUN":
			draw_line(Vector2(-6.0, -30.0), Vector2(4.0, -19.0), Color("e9f5ff"), 5.0)
			draw_line(Vector2(4.0, -19.0), Vector2(-4.0, -10.0), Color("e9f5ff"), 5.0)
			draw_line(Vector2(-4.0, -10.0), Vector2(7.0, -2.0), Color("e9f5ff"), 5.0)
		"SLOW":
			draw_line(Vector2(0.0, -31.0), Vector2(0.0, -3.0), Color("eaffff"), 4.0)
			draw_line(Vector2(-12.0, -24.0), Vector2(12.0, -10.0), Color("eaffff"), 4.0)
			draw_line(Vector2(12.0, -24.0), Vector2(-12.0, -10.0), Color("eaffff"), 4.0)
		_:
			draw_rect(Rect2(-7.0, -33.0, 14.0, 31.0), tower_color.lightened(0.35), true)
			draw_circle(Vector2.ZERO, 7.0, tower_color.darkened(0.42))
	var hp_ratio := hp / max_hp
	draw_rect(Rect2(-25.0, -39.0, 50.0, 6.0), Color("1a202b"), true)
	draw_rect(Rect2(-25.0, -39.0, 50.0 * hp_ratio, 6.0), Color("75e69a"), true)
	if beam_visible_sec > 0.0:
		draw_line(Vector2(0.0, -22.0), beam_end, tower_color.lightened(0.34), 4.0)
		draw_circle(beam_end, 6.0, tower_color.lightened(0.52))
