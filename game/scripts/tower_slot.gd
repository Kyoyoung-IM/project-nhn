class_name PrototypeTowerSlot
extends Area2D

# 전투층의 고정 배치 칸 하나를 담당한다.
# 슬롯은 터렛을 직접 생성하지 않고, 클릭 신호와 점유 상태만 관리한다.

# 프로토타입 게임 컨트롤러가 구매한 터렛을 배치할 때 받는 신호다.
signal pressed(slot: PrototypeTowerSlot)

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


# 슬롯 인덱스를 기록하고 마우스 판정용 사각 충돌 영역을 만든다.
func setup(new_floor_index: int, new_slot_index: int) -> void:
	floor_index = new_floor_index
	slot_index = new_slot_index
	input_pickable = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(82.0, 52.0)
	collision.shape = shape
	add_child(collision)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	queue_redraw()


# 터렛 배치가 완료되면 점유자를 연결하고 슬롯 표시를 갱신한다.
func set_occupant(new_occupant: PrototypeTower) -> void:
	occupant = new_occupant
	queue_redraw()


# 터렛 파괴 또는 게임 초기화 시 점유 연결을 해제한다.
func clear_occupant() -> void:
	occupant = null
	queue_redraw()


# 삭제 예약된 터렛도 빈 슬롯으로 처리해 재배치가 막히지 않게 한다.
func is_empty() -> bool:
	return occupant == null or not is_instance_valid(occupant)


# 드래그 가능한 같은 층의 빈 슬롯·머지 슬롯과 현재 커서 아래 드롭 슬롯의 강조 상태를 갱신한다.
func set_drag_state(eligible: bool, targeted: bool) -> void:
	drag_eligible = eligible
	drag_targeted = targeted
	queue_redraw()


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
	queue_redraw()


# 호버 종료 시 기본 테두리로 복원한다.
func _on_mouse_exited() -> void:
	hovered = false
	queue_redraw()


# 빈 슬롯의 + 기호, 점유 상태, 호버 테두리를 코드 도형으로 그린다.
func _draw() -> void:
	var fill := Color("314152") if is_empty() else Color("222b38")
	if drag_eligible:
		fill = Color("294b43")
	var border := Color("60778a")
	if drag_targeted:
		border = Color("ffe278")
	elif drag_eligible:
		border = Color("7fe6a3")
	elif hovered and interaction_enabled:
		border = Color("9fe8dc")
	draw_rect(Rect2(-41.0, -24.0, 82.0, 48.0), fill, true)
	draw_rect(Rect2(-41.0, -24.0, 82.0, 48.0), border, false, 4.0 if drag_targeted else 2.0)
	if is_empty():
		draw_line(Vector2(-9.0, 0.0), Vector2(9.0, 0.0), Color("8ca2b5"), 3.0)
		draw_line(Vector2(0.0, -9.0), Vector2(0.0, 9.0), Color("8ca2b5"), 3.0)
