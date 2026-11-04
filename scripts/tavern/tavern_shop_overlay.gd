class_name TavernShopOverlay
extends Control
## Reuses the existing shop menus and purchasing logic over the live tavern.

static func open_in(parent: Node, scene_path: String) -> void:
	if parent.get_node_or_null("TavernShopOverlay") != null:
		return
	var overlay := TavernShopOverlay.new()
	overlay.name = "TavernShopOverlay"
	parent.add_child(overlay)
	var room: Control = load(scene_path).instantiate()
	room.embedded = true
	overlay.add_child(room)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var menu: PanelContainer = room.menu_panel
	menu.reparent(center, false)
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	menu.custom_minimum_size = Vector2(640, 0)
	menu.show()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.01, 0.01, 0.55)
	add_child(shade)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
