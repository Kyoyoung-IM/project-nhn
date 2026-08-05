class_name PrototypeShopCard
extends Button

# 상점 카드의 데이터와 상호작용만 담당한다.
# 위치·크기·내부 텍스트 배치는 scenes/ui/shop_card.tscn에서 직접 편집한다.

const TowerVisualAssetsScript := preload("res://scripts/tower_visual_assets.gd")

var tower_data: Dictionary = {}
var game_font: Font
var card_available: bool = true
var card_selected: bool = false
var card_interactable: bool = true
var card_affordable: bool = true
var card_hovered: bool = false

@onready var frame: TextureRect = $Frame
@onready var tower_body: TextureRect = $TowerBody
@onready var tower_effect: TextureRect = $TowerEffect
@onready var name_label: Label = $NameLabel
@onready var price_dim: ColorRect = $PriceDim
@onready var price_label: Label = $PriceLabel
@onready var purchased_overlay: ColorRect = $PurchasedOverlay
@onready var purchased_label: Label = $PurchasedOverlay/PurchasedLabel
@onready var hover_overlay: ColorRect = $HoverOverlay
@onready var hover_name_label: Label = $HoverOverlay/NameLabel
@onready var hover_effect_label: Label = $HoverOverlay/EffectLabel
@onready var hover_damage_label: Label = $HoverOverlay/DamageLabel
@onready var hover_interval_label: Label = $HoverOverlay/IntervalLabel
@onready var hover_range_label: Label = $HoverOverlay/RangeLabel


func _ready() -> void:
	# 네이티브 Button 장식은 비워 생성형 프레임이 유일한 카드 테두리가 되게 한다.
	text = ""
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_visual_state()


func setup(font: Font) -> void:
	game_font = font
	modulate = Color.WHITE
	self_modulate = Color.WHITE
	for label in _all_labels():
		label.add_theme_font_override("font", game_font)
	_apply_visual_state()


func set_tower_data(config: Dictionary) -> void:
	tower_data = config.duplicate(true)
	_update_content()


func set_card_state(available: bool, selected: bool, interactable: bool, affordable: bool) -> void:
	card_available = available
	card_selected = selected
	card_interactable = interactable
	card_affordable = affordable
	disabled = not interactable
	_apply_visual_state()


func _on_mouse_entered() -> void:
	card_hovered = true
	_apply_visual_state()


func _on_mouse_exited() -> void:
	card_hovered = false
	_apply_visual_state()


func _update_content() -> void:
	if tower_data.is_empty():
		name_label.text = "상점 준비 중"
		price_label.text = ""
		tower_body.texture = null
		tower_effect.texture = null
		return

	var display_name := str(tower_data.get("display_name", "터렛"))
	var turret_type := str(tower_data.get("type", "RANGED"))
	name_label.text = display_name
	price_label.text = "%d G" % int(tower_data.get("base_price", 0))
	hover_name_label.text = display_name
	hover_effect_label.text = _effect_description()
	hover_damage_label.text = "공격력  %.0f" % float(tower_data.get("damage", 0.0))
	hover_interval_label.text = "공격 주기  %.2f초" % float(tower_data.get("attack_interval_sec", 0.0))
	hover_range_label.text = "사거리  %.0f" % float(tower_data.get("range_px", 0.0))
	tower_body.texture = TowerVisualAssetsScript.body_texture(turret_type, 1)
	tower_effect.visible = turret_type == "DOT"
	tower_effect.texture = TowerVisualAssetsScript.dot_flame_texture(1) if turret_type == "DOT" else null
	_apply_visual_state()


func _apply_visual_state() -> void:
	if not is_node_ready():
		return
	# 선택·호버 시에도 별도의 코드 테두리를 그리지 않고 프레임 밝기만 작게 바꾼다.
	frame.modulate = Color("fff5cf") if card_selected else Color.WHITE
	price_dim.visible = not card_affordable and card_available and not card_hovered
	price_label.add_theme_color_override("font_color", Color("f6c653") if card_affordable else Color("a0a0aa"))
	purchased_overlay.visible = not card_available and not card_hovered
	hover_overlay.visible = card_hovered


func _effect_description() -> String:
	var turret_type := str(tower_data.get("type", "RANGED"))
	match turret_type:
		"MELEE":
			return "효과 · 근거리 고화력 공격"
		"DOT":
			return "효과 · %.1f초 지속 피해" % float(tower_data.get("cc_duration", 0.0))
		"STUN":
			return "효과 · %.2f초 기절" % float(tower_data.get("cc_duration", 0.0))
		"SLOW":
			return "효과 · %.0f%% 이동 둔화" % (float(tower_data.get("cc_value", 0.0)) * 100.0)
		_:
			return "효과 · 장거리 단일 공격"


func _all_labels() -> Array[Label]:
	return [
		name_label,
		price_label,
		purchased_label,
		hover_name_label,
		hover_effect_label,
		hover_damage_label,
		hover_interval_label,
		hover_range_label,
	]
