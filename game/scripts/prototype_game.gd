extends Node2D

const MonsterScript := preload("res://scripts/monster.gd")
const TowerScript := preload("res://scripts/tower.gd")
const TowerSlotScript := preload("res://scripts/tower_slot.gd")
const GAME_FONT := preload("res://assets/fonts/NotoSansKR.ttf")
const CONFIG_PATH := "res://data/prototype_combat.json"

enum Phase { READY, WAVE, VICTORY, DEFEAT }

var movement_path := PackedVector2Array([
	Vector2(880.0, 135.0),
	Vector2(90.0, 135.0),
	Vector2(870.0, 255.0),
	Vector2(90.0, 255.0),
	Vector2(870.0, 390.0),
	Vector2(90.0, 390.0),
	Vector2(870.0, 525.0),
	Vector2(90.0, 525.0),
])

var combat_config: Dictionary = {}
var phase: Phase = Phase.READY
var monsters: Array[PrototypeMonster] = []
var towers: Array[PrototypeTower] = []
var tower_slots: Array[PrototypeTowerSlot] = []
var shop_cards: Array[Button] = []
var shop_card_available: Array[bool] = []
var selected_shop_card: int = -1
var spawned_count: int = 0
var defeated_count: int = 0
var gold: int = 0
var spawn_cooldown_sec: float = 0.0
var automated_test_mode: bool = false
var automated_test_expects_defeat: bool = false
var automated_test_expects_tower_destruction: bool = false
var automated_test_tower_was_destroyed: bool = false
var automated_test_elapsed_sec: float = 0.0

var phase_label: Label
var wave_label: Label
var gold_label: Label
var status_label: Label
var action_button: Button
var reroll_button: Button


func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	automated_test_mode = "--auto-test-victory" in user_args or "--auto-test-defeat" in user_args or "--auto-test-tower-destruction" in user_args
	automated_test_expects_tower_destruction = "--auto-test-tower-destruction" in user_args
	automated_test_expects_defeat = "--auto-test-defeat" in user_args or automated_test_expects_tower_destruction
	combat_config = _load_and_validate_config()
	_build_interface()
	_create_tower_slots()
	_reset_preparation_state()
	_update_interface()
	queue_redraw()
	if automated_test_mode:
		Engine.time_scale = 12.0
		call_deferred("_start_automated_test")


func _process(delta: float) -> void:
	if automated_test_mode:
		automated_test_elapsed_sec += delta
		if automated_test_elapsed_sec > 90.0:
			push_error("Automated wave test timed out.")
			Engine.time_scale = 1.0
			get_tree().quit(1)
			return

	if phase != Phase.WAVE:
		return

	var wave: Dictionary = combat_config["wave"]
	var total := int(wave["monster_count"])
	if spawned_count < total:
		spawn_cooldown_sec -= delta
		if spawn_cooldown_sec <= 0.0:
			_spawn_monster()
			spawn_cooldown_sec += float(wave["spawn_interval_sec"])

	if spawned_count >= total and monsters.is_empty():
		_set_phase(Phase.VICTORY)


func _load_and_validate_config() -> Dictionary:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("Prototype combat config is missing: %s" % CONFIG_PATH)
		return _fallback_config()

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Prototype combat config is not a JSON object.")
		return _fallback_config()

	var config := parsed as Dictionary
	for section in ["meta", "monster", "tower", "economy", "wave"]:
		if not config.has(section) or typeof(config[section]) != TYPE_DICTIONARY:
			push_error("Prototype combat config section is missing: %s" % section)
			return _fallback_config()

	if str(config["meta"].get("status", "")) != "PLACEHOLDER":
		push_warning("Prototype combat values should remain marked PLACEHOLDER.")
	return config


func _fallback_config() -> Dictionary:
	# Safety-only values. Normal play must load the replaceable JSON data above.
	return {
		"meta": {"status": "PLACEHOLDER"},
		"monster": {"max_hp": 50.0, "move_speed_px_sec": 80.0, "attack_damage": 10.0, "attack_interval_sec": 0.8, "attack_range_px": 58.0, "reward_gold": 5},
		"tower": {"display_name": "더미 포탑", "max_hp": 100.0, "damage": 20.0, "attack_interval_sec": 0.4, "range_px": 280.0},
		"economy": {"starting_gold": 250, "tower_cost": 10, "reroll_cost": 10, "shop_card_count": 5},
		"wave": {"monster_count": 8, "spawn_interval_sec": 0.9},
	}


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	phase_label = _make_label(canvas, Vector2(36.0, 26.0), Vector2(430.0, 38.0), 24)
	phase_label.text = "지상 진입 구간 · 전투 없음"

	wave_label = _make_label(canvas, Vector2(36.0, 78.0), Vector2(190.0, 34.0), 20)
	gold_label = _make_label(canvas, Vector2(242.0, 78.0), Vector2(190.0, 34.0), 20)

	status_label = _make_label(canvas, Vector2(20.0, 625.0), Vector2(245.0, 42.0), 19)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	action_button = Button.new()
	action_button.position = Vector2(746.0, 624.0)
	action_button.size = Vector2(194.0, 44.0)
	action_button.text = "1 웨이브 시작"
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.add_theme_font_override("font", GAME_FONT)
	action_button.add_theme_font_size_override("font_size", 20)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color("f3c95f")
	normal_style.corner_radius_top_left = 9
	normal_style.corner_radius_top_right = 9
	normal_style.corner_radius_bottom_left = 9
	normal_style.corner_radius_bottom_right = 9
	action_button.add_theme_stylebox_override("normal", normal_style)
	action_button.add_theme_color_override("font_color", Color("2e2819"))
	action_button.pressed.connect(_on_action_button_pressed)
	canvas.add_child(action_button)

	var shop_title := _make_label(canvas, Vector2(267.0, 626.0), Vector2(305.0, 38.0), 19)
	shop_title.text = "터렛 상점 · 카드 → 슬롯"
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	reroll_button = Button.new()
	reroll_button.position = Vector2(580.0, 624.0)
	reroll_button.size = Vector2(155.0, 44.0)
	reroll_button.text = "새로고침  %d G" % int(combat_config["economy"]["reroll_cost"])
	reroll_button.focus_mode = Control.FOCUS_NONE
	reroll_button.add_theme_font_override("font", GAME_FONT)
	reroll_button.add_theme_font_size_override("font_size", 17)
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	canvas.add_child(reroll_button)
	_create_shop_cards(canvas)


func _make_label(parent: Node, label_position: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.add_theme_font_override("font", GAME_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f5f7ff"))
	parent.add_child(label)
	return label


func _create_tower_slots() -> void:
	var floor_y := [218.0, 353.0, 488.0]
	var slot_x := [190.0, 335.0, 480.0, 625.0, 770.0]
	for floor_index in 3:
		for slot_index in 5:
			var slot := TowerSlotScript.new() as PrototypeTowerSlot
			slot.position = Vector2(slot_x[slot_index], floor_y[floor_index])
			slot.setup(floor_index, slot_index)
			slot.pressed.connect(_on_tower_slot_pressed)
			add_child(slot)
			tower_slots.append(slot)


func _create_shop_cards(canvas: CanvasLayer) -> void:
	var economy: Dictionary = combat_config["economy"]
	var tower_data: Dictionary = combat_config["tower"]
	var card_count := int(economy["shop_card_count"])
	for card_index in card_count:
		var card := Button.new()
		card.position = Vector2(20.0 + card_index * 185.0, 690.0)
		card.size = Vector2(180.0, 150.0)
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_font_override("font", GAME_FONT)
		card.text = "%s\nHP %.0f  ·  ATK %.0f\n사거리 %.0f\n● %d G" % [
			str(tower_data["display_name"]),
			float(tower_data["max_hp"]),
			float(tower_data["damage"]),
			float(tower_data["range_px"]),
			int(economy["tower_cost"]),
		]
		card.add_theme_font_size_override("font_size", 18)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("34485a")
		style.border_color = Color("7fd9ce")
		style.set_border_width_all(2)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		card.add_theme_stylebox_override("normal", style)
		card.pressed.connect(_on_shop_card_pressed.bind(card_index))
		canvas.add_child(card)
		shop_cards.append(card)
		shop_card_available.append(true)


func _on_action_button_pressed() -> void:
	if phase == Phase.WAVE:
		return
	if phase == Phase.READY:
		_start_wave()
	else:
		_reset_game()


func _on_shop_card_pressed(card_index: int) -> void:
	if phase != Phase.READY or not shop_card_available[card_index]:
		return
	var tower_cost := int(combat_config["economy"]["tower_cost"])
	if gold < tower_cost:
		status_label.text = "골드가 부족합니다"
		return
	selected_shop_card = card_index
	status_label.text = "배치할 빈 슬롯을 선택하세요"
	_update_shop_cards()


func _on_reroll_button_pressed() -> void:
	if phase != Phase.READY:
		return
	var reroll_cost := int(combat_config["economy"]["reroll_cost"])
	if gold < reroll_cost:
		status_label.text = "새로고침 골드가 부족합니다"
		return
	gold -= reroll_cost
	selected_shop_card = -1
	for card_index in shop_card_available.size():
		shop_card_available[card_index] = true
	status_label.text = "상점이 새로고침됐습니다"
	_update_interface()
	_update_shop_cards()


func _on_tower_slot_pressed(slot: PrototypeTowerSlot) -> void:
	if phase != Phase.READY:
		return
	if not slot.is_empty():
		status_label.text = "이미 터렛이 배치된 슬롯입니다"
		return
	if selected_shop_card < 0:
		status_label.text = "먼저 상점 카드를 선택하세요"
		return
	_place_tower(slot, true)


func _place_tower(slot: PrototypeTowerSlot, use_shop_card: bool) -> void:
	var tower_cost := int(combat_config["economy"]["tower_cost"])
	if use_shop_card:
		gold -= tower_cost
		shop_card_available[selected_shop_card] = false
		selected_shop_card = -1
	var tower := TowerScript.new() as PrototypeTower
	tower.position = slot.position
	tower.setup(combat_config["tower"], slot.floor_index)
	tower.tower_destroyed.connect(_on_tower_destroyed.bind(slot))
	add_child(tower)
	towers.append(tower)
	slot.set_occupant(tower)
	_update_interface()
	_update_shop_cards()


func _on_tower_destroyed(tower: PrototypeTower, slot: PrototypeTowerSlot) -> void:
	towers.erase(tower)
	slot.clear_occupant()
	if automated_test_expects_tower_destruction:
		automated_test_tower_was_destroyed = true


func _start_wave() -> void:
	_clear_monsters()
	spawned_count = 0
	defeated_count = 0
	spawn_cooldown_sec = 0.15
	selected_shop_card = -1
	for tower in towers:
		if is_instance_valid(tower):
			tower.reset_for_wave()
	_set_phase(Phase.WAVE)


func _start_automated_test() -> void:
	if automated_test_expects_tower_destruction:
		_place_tower(tower_slots[0], false)
	elif not automated_test_expects_defeat:
		for slot_index in 5:
			_place_tower(tower_slots[slot_index], false)
	_start_wave()
	if automated_test_expects_tower_destruction:
		for tower in towers:
			tower.enabled = false


func _spawn_monster() -> void:
	var monster := MonsterScript.new() as PrototypeMonster
	monster.setup(combat_config["monster"], movement_path)
	monster.defeated.connect(_on_monster_defeated)
	monster.reached_deepest_floor.connect(_on_monster_reached_deepest_floor)
	add_child(monster)
	monsters.append(monster)
	spawned_count += 1
	_update_interface()


func _on_monster_defeated(monster: PrototypeMonster) -> void:
	monsters.erase(monster)
	defeated_count += 1
	gold += monster.reward_gold
	_update_interface()


func _on_monster_reached_deepest_floor(monster: PrototypeMonster) -> void:
	monsters.erase(monster)
	if phase == Phase.WAVE:
		_set_phase(Phase.DEFEAT)


func _set_phase(next_phase: Phase) -> void:
	phase = next_phase
	for tower in towers:
		if is_instance_valid(tower):
			tower.enabled = phase == Phase.WAVE
	for slot in tower_slots:
		slot.interaction_enabled = phase == Phase.READY
	_update_shop_cards()
	if phase == Phase.DEFEAT:
		for monster in monsters:
			if is_instance_valid(monster):
				monster.set_process(false)
	_update_interface()
	queue_redraw()
	if automated_test_mode and (phase == Phase.VICTORY or phase == Phase.DEFEAT):
		call_deferred("_finish_automated_test")


func _finish_automated_test() -> void:
	var expected_phase := Phase.DEFEAT if automated_test_expects_defeat else Phase.VICTORY
	var passed := phase == expected_phase
	if automated_test_expects_tower_destruction:
		passed = passed and automated_test_tower_was_destroyed
	if passed:
		var result_name := "TOWER_DESTROYED_THEN_DEFEAT" if automated_test_expects_tower_destruction else ("DEFEAT" if automated_test_expects_defeat else "VICTORY")
		print("Automated wave test passed: %s" % result_name)
	else:
		push_error("Automated wave test reached an unexpected result.")
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


func _clear_monsters() -> void:
	for monster in monsters:
		if is_instance_valid(monster):
			monster.queue_free()
	monsters.clear()


func _reset_game() -> void:
	_clear_monsters()
	for tower in towers:
		if is_instance_valid(tower):
			tower.queue_free()
	towers.clear()
	for slot in tower_slots:
		slot.clear_occupant()
	_reset_preparation_state()
	_set_phase(Phase.READY)


func _reset_preparation_state() -> void:
	gold = int(combat_config["economy"]["starting_gold"])
	selected_shop_card = -1
	shop_card_available.clear()
	for _card in shop_cards:
		shop_card_available.append(true)
	_update_shop_cards()


func _update_shop_cards() -> void:
	if shop_cards.is_empty() or shop_card_available.size() != shop_cards.size():
		return
	var tower_cost := int(combat_config["economy"]["tower_cost"])
	for card_index in shop_cards.size():
		var card := shop_cards[card_index]
		card.disabled = phase != Phase.READY or not shop_card_available[card_index] or gold < tower_cost
		card.modulate = Color("fff2a8") if card_index == selected_shop_card else Color.WHITE
	if reroll_button != null:
		var reroll_cost := int(combat_config["economy"]["reroll_cost"])
		reroll_button.disabled = phase != Phase.READY or gold < reroll_cost


func _update_interface() -> void:
	if wave_label == null:
		return
	var wave_total := int(combat_config["wave"].get("monster_count", 0))
	wave_label.text = "WAVE  1 / 1"
	gold_label.text = "GOLD  %d" % gold
	match phase:
		Phase.READY:
			status_label.text = "터렛을 구매해 배치하세요"
			action_button.text = "1 웨이브 시작"
			action_button.disabled = false
		Phase.WAVE:
			status_label.text = "방어 중  %d / %d 처치" % [defeated_count, wave_total]
			action_button.text = "웨이브 진행 중"
			action_button.disabled = true
		Phase.VICTORY:
			status_label.text = "방어 성공"
			action_button.text = "프로토타입 초기화"
			action_button.disabled = false
		Phase.DEFEAT:
			status_label.text = "최심부 침입 · 패배"
			action_button.text = "프로토타입 초기화"
			action_button.disabled = false


func _draw() -> void:
	# Header / ground staging area.
	draw_rect(Rect2(18.0, 16.0, 924.0, 596.0), Color("253044"), true)
	draw_rect(Rect2(24.0, 20.0, 912.0, 130.0), Color("6ca4cb"), true)
	draw_rect(Rect2(24.0, 113.0, 912.0, 37.0), Color("759b60"), true)
	draw_rect(Rect2(24.0, 142.0, 912.0, 12.0), Color("283342"), true)

	# Entrance skyline and the dedicated descent shaft.
	draw_rect(Rect2(805.0, 82.0, 91.0, 60.0), Color("39465c"), true)
	draw_rect(Rect2(827.0, 100.0, 47.0, 42.0), Color("182234"), true)
	draw_rect(Rect2(58.0, 105.0, 64.0, 70.0), Color("171d2b"), true)
	draw_rect(Rect2(73.0, 120.0, 34.0, 430.0), Color("202838"), true)
	draw_line(Vector2(90.0, 145.0), Vector2(90.0, 525.0), Color("90a1b7"), 5.0)

	# Three playable underground floors.
	var floor_colors := [Color("473f49"), Color("403943"), Color("39343f")]
	var floor_y := [162.0, 297.0, 432.0]
	for index in 3:
		draw_rect(Rect2(24.0, floor_y[index], 912.0, 125.0), floor_colors[index], true)
		draw_line(Vector2(26.0, floor_y[index] + 8.0), Vector2(934.0, floor_y[index] + 8.0), Color("655b65"), 4.0)
		draw_line(Vector2(34.0, floor_y[index] + 94.0), Vector2(926.0, floor_y[index] + 94.0), Color("171b25"), 8.0)

	# Each combat floor has a right-side entrance and a left-side transfer exit.
	for lane_y in [255.0, 390.0, 525.0]:
		draw_rect(Rect2(844.0, lane_y - 35.0, 50.0, 35.0), Color("202838"), true)
	for lane_y in [255.0, 390.0]:
		draw_rect(Rect2(70.0, lane_y - 35.0, 40.0, 35.0), Color("202838"), true)

	# All three combat lanes move from right to left.
	_draw_arrow(Vector2(835.0, 135.0), Vector2(145.0, 135.0), Color("d8e8f2"))
	_draw_arrow(Vector2(810.0, 255.0), Vector2(145.0, 255.0), Color("7fd9ce"))
	_draw_arrow(Vector2(810.0, 390.0), Vector2(145.0, 390.0), Color("7fd9ce"))
	_draw_arrow(Vector2(810.0, 525.0), Vector2(145.0, 525.0), Color("7fd9ce"))

	var font: Font = GAME_FONT
	for index in 3:
		draw_string(font, Vector2(34.0, 207.0 + index * 135.0), "B%d  전투층" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("d9d3dd"))
	draw_string(font, Vector2(34.0, 585.0), "최심부", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("ff9b9b"))

	# Deepest-floor breach core.
	draw_circle(Vector2(90.0, 525.0), 27.0, Color("5b2432"))
	draw_circle(Vector2(90.0, 525.0), 15.0, Color("ff6475"))
	draw_line(Vector2(82.0, 517.0), Vector2(98.0, 533.0), Color.WHITE, 3.0)
	draw_line(Vector2(98.0, 517.0), Vector2(82.0, 533.0), Color.WHITE, 3.0)

	# Bottom preparation deck and TFT-style five-card shop.
	draw_rect(Rect2(18.0, 612.0, 924.0, 248.0), Color("151c2a"), true)
	draw_line(Vector2(18.0, 612.0), Vector2(942.0, 612.0), Color("60708a"), 2.0)
	draw_line(Vector2(18.0, 680.0), Vector2(942.0, 680.0), Color("39475b"), 2.0)


func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, color, 3.0)
	var direction := (to - from).normalized()
	var side := direction.orthogonal()
	var head := PackedVector2Array([
		to,
		to - direction * 18.0 + side * 9.0,
		to - direction * 18.0 - side * 9.0,
	])
	draw_colored_polygon(head, color)
