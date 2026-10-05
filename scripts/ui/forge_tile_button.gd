class_name ForgeTileButton
extends LetterInfoButton
## Reusable draggable tile control for the forge inventory and board.

var forge_owner: Node
var item: LetterStats = null
var accepts_forge_drop: bool = false


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null or forge_owner == null:
		return null
	var preview := Label.new()
	preview.text = "%s · Lv%d" % [item.letter.to_upper(), item.level]
	preview.add_theme_font_size_override("font_size", 22)
	preview.add_theme_color_override("font_color", Color("fff7df"))
	set_drag_preview(preview)
	return {"forge_item": item}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return accepts_forge_drop and data is Dictionary and data.has("forge_item")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	forge_owner.call("add_item_to_board", data["forge_item"])
