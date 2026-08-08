class_name PrototypeTowerSlot
extends Area2D

# 전투층의 고정 배치 칸 하나를 담당한다.
# 슬롯은 터렛을 직접 생성하지 않고, 클릭 신호와 점유 상태만 관리한다.

# 프로토타입 게임 컨트롤러가 구매한 터렛을 배치할 때 받는 신호다.
signal pressed(slot: PrototypeTowerSlot)

# 슬롯 표시는 평상시 30%, 배치·이동 드래그 중 유효한 위치는 60% 불투명도로 강조한다.
const BASE_SLOT_OPACITY := 0.30
const HIGHLIGHT_SLOT_OPACITY := 0.60

# 데이터상 위치: floor_index는 B1~B3(0~2), slot_index는 층 안의 0~4다.
var floor_index: int = 0
var slot_index: int = 0

# 현재 슬롯에 배치된 터렛과 입력/호버 표시 상태다.
var occupant: PrototypeTower = null
var interaction_enabled: bool = true
var hovered: bool = false

# 터렛 드래그 중 같은 층의 이동·머지 가능 슬롯인지, 현재 드롭 대상으로 선택됐는지 표시한다.
var drag_eligible: bool = false
var drag_targeted: bool = false

@export_group("슬롯 상태 색상")
@export var base_fill_color := Color(0.48, 0.78, 0.22, 1.0)
@export var eligible_fill_color := Color(0.36, 0.82, 0.30, 1.0)
@export var base_border_color := Color(0.70, 1.00, 0.38, 1.0)
@export var eligible_border_color := Color(0.70, 1.00, 0.42, 1.0)
@export var hover_border_color := Color(0.83, 1.00, 0.55, 1.0)
@export var targeted_border_color := Color(0.95, 1.00, 0.55, 1.0)

@onready var visual: Control = $Visual
@onready var fill_panel: Panel = $Visual/Fill
@onready var border_panel: Panel = $Visual/Border


func _ready() -> void:
	_update_visual()


# 슬롯 인덱스를 기록하고 tower_slot.tscn의 편집 가능한 시각 노드와 입력을 연결한다.
func setup(new_floor_index: int, new_slot_index: int) -> void:
	floor_index = new_floor_index
	slot_index = new_slot_index
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_visual()


# 터렛 배치가 완료되면 점유자를 연결하고 슬롯 표시를 갱신한다.
func set_occupant(new_occupant: PrototypeTower) -> void:
	occupant = new_occupant
	_update_visual()


# 터렛 파괴 또는 게임 초기화 시 점유 연결을 해제한다.
func clear_occupant() -> void:
	occupant = null
	_update_visual()


# 삭제 예약된 터렛도 빈 슬롯으로 처리해 재배치가 막히지 않게 한다.
func is_empty() -> bool:
	return occupant == null or not is_instance_valid(occupant)


# 드래그 가능한 같은 층의 빈 슬롯·머지 슬롯과 현재 커서 아래 드롭 슬롯의 강조 상태를 갱신한다.
func set_drag_state(eligible: bool, targeted: bool) -> void:
	drag_eligible = eligible
	drag_targeted = targeted
	_update_visual()


# 정비 단계에서 왼쪽 클릭을 받으면 게임 컨트롤러에 슬롯을 전달한다.
func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(self)
		get_viewport().set_input_as_handled()


# 호버 진입 시 테두리 강조를 켠다.
func _on_mouse_entered() -> void:
	hovered = true
	_update_visual()


# 호버 종료 시 기본 테두리로 복원한다.
func _on_mouse_exited() -> void:
	hovered = false
	_update_visual()


# 빈 슬롯의 +·테두리·그림자는 씬에서 편집하고 상태에 따른 색상만 갱신한다.
func _update_visual() -> void:
	if visual == null or fill_panel == null or border_panel == null:
		return
	# Area2D.self_modulate는 자식 Control에 전파되지 않으므로 실제 표시 루트의 알파를 갱신한다.
	var highlighted := drag_eligible or drag_targeted
	visual.modulate.a = HIGHLIGHT_SLOT_OPACITY if highlighted else BASE_SLOT_OPACITY
	visual.visible = true
	var fill_style := fill_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	fill_style.bg_color = eligible_fill_color if drag_eligible else base_fill_color
	fill_panel.add_theme_stylebox_override("panel", fill_style)
	var border_style := border_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	border_style.border_color = targeted_border_color if drag_targeted else eligible_border_color if drag_eligible else hover_border_color if hovered and interaction_enabled else base_border_color
	border_style.set_border_width_all(5 if drag_targeted else 3)
	border_panel.add_theme_stylebox_override("panel", border_style)
