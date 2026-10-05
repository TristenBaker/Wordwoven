class_name ForgeInventoryGrid
extends GridContainer
## Dropping a selected forge tile back here returns it to the loose list.

var forge_owner: Node


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("forge_item")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if forge_owner != null and _can_drop_data(_at_position, data):
		forge_owner.call("remove_item_from_board", data["forge_item"])
