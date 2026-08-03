extends Node2D

# 프로토타입 전체 장면의 게임 루프와 UI를 조정하는 최상위 컨트롤러다.
# 개별 터렛/몬스터의 전투는 각 오브젝트 스크립트에 맡기고 여기서는 생성·경제·승패만 관리한다.

# 동적으로 생성하는 오브젝트, 데이터 로더, 한글 UI 폰트를 미리 로드한다.
const MonsterScript := preload("res://scripts/monster.gd")
const TowerScript := preload("res://scripts/tower.gd")
const TowerSlotScript := preload("res://scripts/tower_slot.gd")
const DatabaseScript := preload("res://scripts/prototype_database.gd")
const GAME_FONT := preload("res://assets/fonts/NotoSansKR.ttf")

# 모든 전투 좌표와 UI 배치는 이 논리 해상도를 기준으로 작성한다.
# Web 창의 가로세로 비율이 달라져도 이 영역 전체가 보이도록 Godot 스트레치가 먼저 배율을 정한다.
const REFERENCE_VIEWPORT_SIZE := Vector2(960.0, 860.0)

# READY는 정비, WAVE는 자동 전투, VICTORY/DEFEAT는 입력 대기 결과 화면이다.
enum Phase { READY, WAVE, VICTORY, DEFEAT }

# 지상 오른쪽→왼쪽, B1~B3 각각 오른쪽→왼쪽으로 이어지는 고정 웨이포인트다.
# 홀수 인덱스의 왼쪽 출구에서 다음 짝수 인덱스의 오른쪽 입구로 하강한다.
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

# 로드된 데이터베이스와 현재 장면 단계다.
var database: PrototypeDatabase
var phase: Phase = Phase.READY

# 현재 장면에 살아 있는 오브젝트와 15개 배치 슬롯 목록이다.
var monsters: Array[PrototypeMonster] = []
var towers: Array[PrototypeTower] = []
var tower_slots: Array[PrototypeTowerSlot] = []

# 하단 상점의 카드 UI, 카드별 구매 가능 여부, 실제 터렛 ID를 같은 인덱스로 관리한다.
var shop_cards: Array[Button] = []
var shop_card_available: Array[bool] = []
var shop_turret_ids: Array[String] = []
var selected_shop_card: int = -1

# 현재 웨이브의 SpawnTable 전개 결과와 생성/처치 진행도다.
var current_wave_number: int = 1
var current_wave_monster_ids: Array[String] = []
var next_spawn_index: int = 0
var spawned_count: int = 0
var defeated_count: int = 0

# 정비 단계 경제 및 스폰 타이머 상태다.
var gold: int = 0
var preparation_remaining_sec: float = 0.0
var reroll_count: int = 0
var spawn_cooldown_sec: float = 0.0

# 고정 시드 상점 RNG로 같은 입력에서 같은 카드 순서를 재현한다.
var shop_rng := RandomNumberGenerator.new()

# 헤드리스 정상/실패/경제 테스트를 한 장면 코드에서 실행하기 위한 플래그다.
var automated_test_mode: bool = false
var automated_test_expects_defeat: bool = false
var automated_test_expects_tower_destruction: bool = false
var automated_test_economy: bool = false
var automated_test_tower_was_destroyed: bool = false
var automated_test_elapsed_sec: float = 0.0

# 런타임에 생성하는 주요 HUD 참조다.
var phase_label: Label
var wave_label: Label
var gold_label: Label
var status_label: Label
var action_button: Button
var reroll_button: Button

# CanvasLayer는 Node2D 변환을 상속하지 않으므로 별도로 보관해 전장과 같은 중앙 오프셋을 적용한다.
var interface_canvas: CanvasLayer


# 명령줄 테스트 플래그를 해석하고, 데이터→UI→슬롯→첫 정비 단계 순서로 초기화한다.
func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	automated_test_mode = "--auto-test-victory" in user_args or "--auto-test-defeat" in user_args or "--auto-test-tower-destruction" in user_args or "--auto-test-economy" in user_args
	automated_test_expects_tower_destruction = "--auto-test-tower-destruction" in user_args
	automated_test_expects_defeat = "--auto-test-defeat" in user_args or automated_test_expects_tower_destruction
	automated_test_economy = "--auto-test-economy" in user_args
	database = DatabaseScript.new() as PrototypeDatabase
	if database == null or not database.load_all():
		push_error("Prototype database could not be loaded.")
		get_tree().quit(1)
		return
	shop_rng.seed = database.extension_int("rngSeed", 20260803)
	_build_interface()
	_create_tower_slots()
	# aspect=expand가 만든 여분의 논리 공간에 게임을 중앙 정렬하고, 이후 브라우저 크기 변화도 추적한다.
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	_begin_preparation(true)
	_update_interface()
	queue_redraw()
	if automated_test_mode:
		Engine.time_scale = 12.0
		call_deferred("_start_automated_test")


# 정비 카운트다운 또는 웨이브 몬스터 스폰/종료 조건을 매 프레임 처리한다.
func _process(delta: float) -> void:
	if automated_test_mode:
		automated_test_elapsed_sec += delta
		if automated_test_elapsed_sec > 90.0:
			push_error("Automated wave test timed out.")
			Engine.time_scale = 1.0
			get_tree().quit(1)
			return

	if phase == Phase.READY:
		if not automated_test_mode:
			var previous_second := ceili(preparation_remaining_sec)
			preparation_remaining_sec = maxf(0.0, preparation_remaining_sec - delta)
			if ceili(preparation_remaining_sec) != previous_second:
				_update_interface()
			if preparation_remaining_sec <= 0.0:
				_start_wave()
		return

	if phase != Phase.WAVE:
		return

	var total := current_wave_monster_ids.size()
	if spawned_count < total:
		spawn_cooldown_sec -= delta
		if spawn_cooldown_sec <= 0.0:
			_spawn_monster()
			spawn_cooldown_sec += database.define_float("monsterSpawnInterval", 0.7)

	if spawned_count >= total and monsters.is_empty():
		_complete_wave()


# 상단 정보, 하단 상점, 웨이브/리롤 버튼을 CanvasLayer에 생성한다.
func _build_interface() -> void:
	interface_canvas = CanvasLayer.new()
	add_child(interface_canvas)

	phase_label = _make_label(interface_canvas, Vector2(36.0, 26.0), Vector2(430.0, 38.0), 24)
	phase_label.text = "지상 진입 구간 · 전투 없음"

	wave_label = _make_label(interface_canvas, Vector2(36.0, 78.0), Vector2(190.0, 34.0), 20)
	gold_label = _make_label(interface_canvas, Vector2(242.0, 78.0), Vector2(190.0, 34.0), 20)

	status_label = _make_label(interface_canvas, Vector2(20.0, 625.0), Vector2(245.0, 42.0), 19)
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
	interface_canvas.add_child(action_button)

	var shop_title := _make_label(interface_canvas, Vector2(267.0, 626.0), Vector2(305.0, 38.0), 19)
	shop_title.text = "터렛 상점 · 카드 → 슬롯"
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	reroll_button = Button.new()
	reroll_button.position = Vector2(580.0, 624.0)
	reroll_button.size = Vector2(155.0, 44.0)
	reroll_button.text = "새로고침  %d G" % _current_reroll_cost()
	reroll_button.focus_mode = Control.FOCUS_NONE
	reroll_button.add_theme_font_override("font", GAME_FONT)
	reroll_button.add_theme_font_size_override("font_size", 17)
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	interface_canvas.add_child(reroll_button)
	_create_shop_cards(interface_canvas)


# Web 캔버스가 넓거나 높아질 때 960×860 게임 영역을 남는 축의 중앙으로 이동한다.
# 실제 확대·축소는 project.godot의 canvas_items + expand 설정이 담당하므로 여기서는 왜곡 없이 위치만 맞춘다.
func _update_responsive_layout() -> void:
	var visible_size := get_viewport_rect().size
	var center_offset := Vector2(
		maxf(0.0, (visible_size.x - REFERENCE_VIEWPORT_SIZE.x) * 0.5),
		maxf(0.0, (visible_size.y - REFERENCE_VIEWPORT_SIZE.y) * 0.5)
	)
	position = center_offset
	if is_instance_valid(interface_canvas):
		interface_canvas.offset = center_offset


# 모든 HUD Label에 동일한 한글 폰트와 기본 색상을 적용하는 생성 도우미다.
func _make_label(parent: Node, label_position: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.add_theme_font_override("font", GAME_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f5f7ff"))
	parent.add_child(label)
	return label


# B1~B3 각 5개, 총 15개의 고정 터렛 슬롯을 만든다.
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


# PDF/AGENTS에 확정된 5칸 TFT형 상점 카드 버튼을 만든다.
# 카드의 실제 내용은 매 정비 단계마다 _refresh_shop_cards에서 채운다.
func _create_shop_cards(canvas: CanvasLayer) -> void:
	var card_count := database.extension_int("shopCardCount", 5)
	for card_index in card_count:
		var card := Button.new()
		card.position = Vector2(20.0 + card_index * 185.0, 690.0)
		card.size = Vector2(180.0, 150.0)
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_font_override("font", GAME_FONT)
		card.text = "상점 준비 중"
		card.add_theme_font_size_override("font_size", 16)
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
		shop_turret_ids.append("")


# 정비 단계에서는 웨이브를 조기 시작하고, 결과 단계에서는 전체 게임을 초기화한다.
func _on_action_button_pressed() -> void:
	if phase == Phase.WAVE:
		return
	if phase == Phase.READY:
		_start_wave()
	else:
		_reset_game()


# 구매할 카드를 선택하되 골드는 실제 슬롯 배치가 성공할 때 차감한다.
func _on_shop_card_pressed(card_index: int) -> void:
	if phase != Phase.READY or not shop_card_available[card_index]:
		return
	var tower_data := database.get_turret_data(shop_turret_ids[card_index])
	var tower_cost := int(tower_data.get("base_price", -1))
	if gold < tower_cost:
		status_label.text = "골드가 부족합니다"
		return
	selected_shop_card = card_index
	status_label.text = "배치할 빈 슬롯을 선택하세요"
	_update_shop_cards()


# 현재 누적 비용을 차감하고 카드 5장을 다시 추첨한 뒤 리롤 횟수를 증가시킨다.
func _on_reroll_button_pressed() -> void:
	if phase != Phase.READY:
		return
	var reroll_cost := _current_reroll_cost()
	if gold < reroll_cost:
		status_label.text = "새로고침 골드가 부족합니다"
		return
	gold -= reroll_cost
	reroll_count += 1
	selected_shop_card = -1
	_refresh_shop_cards()
	status_label.text = "상점이 새로고침됐습니다"
	_update_interface()
	_update_shop_cards()


# 빈 슬롯과 선택된 상점 카드가 모두 있을 때만 배치를 요청한다.
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


# 터렛 ID를 데이터로 변환해 오브젝트를 생성하고 슬롯과 파괴 신호를 연결한다.
# 자동 테스트는 use_shop_card=false와 override ID로 경제 차감 없이 배치할 수 있다.
func _place_tower(slot: PrototypeTowerSlot, use_shop_card: bool, turret_id_override: String = "") -> void:
	var turret_id := turret_id_override
	if use_shop_card:
		turret_id = shop_turret_ids[selected_shop_card]
	elif turret_id.is_empty():
		turret_id = database.first_shop_turret_id()
	var tower_data := database.get_turret_data(turret_id)
	if tower_data.is_empty():
		push_error("Cannot place unknown turret: %s" % turret_id)
		return
	var tower_cost := int(tower_data.get("base_price", 0))
	if use_shop_card:
		gold -= tower_cost
		shop_card_available[selected_shop_card] = false
		selected_shop_card = -1
	var tower := TowerScript.new() as PrototypeTower
	tower.position = slot.position
	tower.setup(tower_data, slot.floor_index)
	tower.tower_destroyed.connect(_on_tower_destroyed.bind(slot))
	add_child(tower)
	towers.append(tower)
	slot.set_occupant(tower)
	_update_interface()
	_update_shop_cards()


# 파괴된 터렛을 활성 목록과 슬롯에서 제거하고 관련 자동 테스트 상태를 기록한다.
func _on_tower_destroyed(tower: PrototypeTower, slot: PrototypeTowerSlot) -> void:
	towers.erase(tower)
	slot.clear_occupant()
	if automated_test_expects_tower_destruction:
		automated_test_tower_was_destroyed = true


# 현재 SpawnTable이 유효한지 확인하고 카운터/터렛 쿨다운을 초기화해 전투를 시작한다.
func _start_wave() -> void:
	if current_wave_monster_ids.is_empty():
		push_error("Current wave has no SpawnTable entries: wave%d" % current_wave_number)
		return
	_clear_monsters()
	next_spawn_index = 0
	spawned_count = 0
	defeated_count = 0
	spawn_cooldown_sec = 0.15
	selected_shop_card = -1
	for tower in towers:
		if is_instance_valid(tower):
			tower.reset_for_wave()
	_set_phase(Phase.WAVE)


# 테스트 종류에 필요한 터렛을 자동 배치한 뒤 정비 시간을 건너뛰고 웨이브를 시작한다.
func _start_automated_test() -> void:
	if automated_test_economy:
		_run_economy_automated_test()
		return
	if automated_test_expects_tower_destruction:
		_place_tower(tower_slots[0], false, "TURRET_MELEE_T1")
	elif not automated_test_expects_defeat:
		for slot_index in 5:
			_place_tower(tower_slots[slot_index], false, "TURRET_RANGED_T1")
	_start_wave()
	if automated_test_expects_tower_destruction:
		for tower in towers:
			tower.enabled = false


# 리롤 비용 10→15 증가와 다음 정비 단계의 기본 비용 초기화를 검증한다.
func _run_economy_automated_test() -> void:
	var starting_gold := gold
	var base_cost := database.define_int("rerollCost", 10)
	var plus_cost := database.define_int("rerollPlusCost", 5)
	var first_cost := _current_reroll_cost()
	_on_reroll_button_pressed()
	var second_cost := _current_reroll_cost()
	_on_reroll_button_pressed()
	var expected_gold := starting_gold - base_cost - (base_cost + plus_cost)
	var passed := first_cost == base_cost and second_cost == base_cost + plus_cost and gold == expected_gold
	_begin_preparation(false)
	passed = passed and _current_reroll_cost() == base_cost and gold == expected_gold
	if passed:
		print("Automated economy test passed: REROLL_10_15_RESET")
	else:
		push_error("Automated economy test failed.")
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)


# 펼쳐진 SpawnTable 순서에서 다음 ID를 꺼내 데이터 기반 몬스터를 생성한다.
func _spawn_monster() -> void:
	if next_spawn_index >= current_wave_monster_ids.size():
		return
	var monster_id := current_wave_monster_ids[next_spawn_index]
	next_spawn_index += 1
	var monster_data := database.get_monster_data(monster_id)
	if monster_data.is_empty():
		push_error("Cannot spawn unknown monster: %s" % monster_id)
		return
	var monster := MonsterScript.new() as PrototypeMonster
	monster.setup(monster_data, movement_path)
	monster.defeated.connect(_on_monster_defeated)
	monster.reached_deepest_floor.connect(_on_monster_reached_deepest_floor)
	add_child(monster)
	monsters.append(monster)
	spawned_count += 1
	_update_interface()


# 처치된 몬스터를 목록에서 제거하고 Monster.rewardGold를 지급한다.
func _on_monster_defeated(monster: PrototypeMonster) -> void:
	monsters.erase(monster)
	defeated_count += 1
	gold += monster.reward_gold
	_update_interface()


# failAllowedMonster 대신 확정 규칙인 B3 최심부 코어 도달만 패배로 처리한다.
func _on_monster_reached_deepest_floor(monster: PrototypeMonster) -> void:
	monsters.erase(monster)
	if phase == Phase.WAVE:
		_set_phase(Phase.DEFEAT)


# 다음 웨이브가 있으면 정비 단계로 돌아가고 마지막 웨이브면 승리한다.
func _complete_wave() -> void:
	if current_wave_number >= database.define_int("totalWaveCount", 1):
		_set_phase(Phase.VICTORY)
		return
	current_wave_number += 1
	_begin_preparation(false)


# 단계에 맞춰 터렛 공격, 슬롯 입력, 몬스터 진행, HUD를 일괄 전환한다.
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


# 기대 단계와 터렛 파괴 여부를 비교해 헤드리스 테스트 종료 코드를 결정한다.
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


# 장면에 남은 몬스터를 안전하게 삭제하고 추적 배열을 비운다.
func _clear_monsters() -> void:
	for monster in monsters:
		if is_instance_valid(monster):
			monster.queue_free()
	monsters.clear()


# 결과 화면에서 새 게임을 시작할 때 몬스터·터렛·슬롯·RNG를 초기 상태로 되돌린다.
func _reset_game() -> void:
	_clear_monsters()
	for tower in towers:
		if is_instance_valid(tower):
			tower.queue_free()
	towers.clear()
	for slot in tower_slots:
		slot.clear_occupant()
	current_wave_number = 1
	shop_rng.seed = database.extension_int("rngSeed", 20260803)
	_begin_preparation(true)


# 게임 시작 또는 웨이브 사이 정비 시간을 설정하고 상점/리롤 상태를 초기화한다.
# reset_run=false일 때는 기존 골드와 살아 있는 터렛을 보존한다.
func _begin_preparation(reset_run: bool) -> void:
	if reset_run:
		gold = database.define_int("initialGold", 100)
	reroll_count = 0
	preparation_remaining_sec = database.define_float("prepareTimeSec", 20.0)
	current_wave_monster_ids = database.get_wave_monster_ids("wave%d" % current_wave_number)
	selected_shop_card = -1
	_set_phase(Phase.READY)
	_refresh_shop_cards()
	status_label.text = "터렛을 구매해 배치하세요"
	_update_interface()


# ShopGacha 확률로 카드 ID를 새로 뽑고 카드에 타입·능력치·가격을 표시한다.
func _refresh_shop_cards() -> void:
	shop_turret_ids = database.roll_shop_turret_ids(shop_rng, shop_cards.size())
	shop_card_available.clear()
	for card_index in shop_cards.size():
		shop_card_available.append(true)
		var tower_data := database.get_turret_data(shop_turret_ids[card_index])
		var card := shop_cards[card_index]
		card.text = "%s  [%s]\nHP %.0f · ATK %.0f\n주기 %.2fs · 사거리 %.0f\n● %d G" % [
			str(tower_data.get("display_name", "터렛")),
			str(tower_data.get("type", "")),
			float(tower_data.get("max_hp", 0.0)),
			float(tower_data.get("damage", 0.0)),
			float(tower_data.get("attack_interval_sec", 0.0)),
			float(tower_data.get("range_px", 0.0)),
			int(tower_data.get("base_price", 0)),
		]
	_update_shop_cards()


# 현재 정비 단계에서 지불할 비용을 기본값 + 증가값 × 실행 횟수로 계산한다.
func _current_reroll_cost() -> int:
	return database.define_int("rerollCost", 10) + database.define_int("rerollPlusCost", 5) * reroll_count


# 골드·단계·카드 소모 상태에 따라 상점과 리롤 버튼의 활성화를 갱신한다.
func _update_shop_cards() -> void:
	if shop_cards.is_empty() or shop_card_available.size() != shop_cards.size():
		return
	for card_index in shop_cards.size():
		var card := shop_cards[card_index]
		var tower_data := database.get_turret_data(shop_turret_ids[card_index])
		var tower_cost := int(tower_data.get("base_price", 0))
		card.disabled = phase != Phase.READY or not shop_card_available[card_index] or gold < tower_cost
		card.modulate = Color("fff2a8") if card_index == selected_shop_card else Color.WHITE
	if reroll_button != null:
		var reroll_cost := _current_reroll_cost()
		reroll_button.text = "새로고침  %d G" % reroll_cost
		reroll_button.disabled = phase != Phase.READY or gold < reroll_cost


# 웨이브/골드/정비시간/결과 문구를 현재 상태에 맞게 HUD에 반영한다.
func _update_interface() -> void:
	if wave_label == null:
		return
	var wave_total := current_wave_monster_ids.size()
	var total_wave_count := database.define_int("totalWaveCount", 1)
	wave_label.text = "WAVE  %d / %d" % [current_wave_number, total_wave_count]
	gold_label.text = "GOLD  %d" % gold
	match phase:
		Phase.READY:
			phase_label.text = "정비 시간  %d초 · 지상 진입 구간" % ceili(preparation_remaining_sec)
			status_label.text = "터렛을 구매해 배치하세요"
			action_button.text = "%d 웨이브 조기 시작" % current_wave_number
			action_button.disabled = false
		Phase.WAVE:
			phase_label.text = "지상 진입 구간 · 전투는 지하 3개 층"
			status_label.text = "방어 중  %d / %d 처치" % [defeated_count, wave_total]
			action_button.text = "웨이브 진행 중"
			action_button.disabled = true
		Phase.VICTORY:
			phase_label.text = "모든 웨이브 방어 완료"
			status_label.text = "방어 성공"
			action_button.text = "프로토타입 초기화"
			action_button.disabled = false
		Phase.DEFEAT:
			phase_label.text = "최심부 코어 침입"
			status_label.text = "최심부 침입 · 패배"
			action_button.text = "프로토타입 초기화"
			action_button.disabled = false


# 외부 배경 에셋 없이 지상 구간, 지하 3층, 진입구, 코어, 상점 배경을 그린다.
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


# 층별 오른쪽→왼쪽 진행 방향을 선과 삼각형 화살촉으로 표시한다.
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
