class_name PrototypeTowerSlot
extends Area2D

signal pressed(slot: PrototypeTowerSlot)

var floor_index: int = 0
var slot_index: int = 0
var occupant: PrototypeTower = null
var interaction_enabled: bool = true
var hovered: bool = false


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


func set_occupant(new_occupant: PrototypeTower) -> void:
	occupant = new_occupant
	queue_redraw()


func clear_occupant() -> void:
	occupant = null
	queue_redraw()


func is_empty() -> bool:
	return occupant == null or not is_instance_valid(occupant)


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(self)
		get_viewport().set_input_as_handled()


func _on_mouse_entered() -> void:
	hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	hovered = false
	queue_redraw()


func _draw() -> void:
	var fill := Color("314152") if is_empty() else Color("222b38")
	var border := Color("9fe8dc") if hovered and interaction_enabled else Color("60778a")
	draw_rect(Rect2(-41.0, -24.0, 82.0, 48.0), fill, true)
	draw_rect(Rect2(-41.0, -24.0, 82.0, 48.0), border, false, 2.0)
	if is_empty():
		draw_line(Vector2(-9.0, 0.0), Vector2(9.0, 0.0), Color("8ca2b5"), 3.0)
		draw_line(Vector2(0.0, -9.0), Vector2(0.0, 9.0), Color("8ca2b5"), 3.0)
