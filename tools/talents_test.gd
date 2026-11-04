extends Node
## In-memory smoke checks: never writes the player's profile.

func _ready() -> void:
	var catalog := preload("res://data/balance/talents.gd")
	assert(catalog.NODES.size() == 54)
	var previous := PlayerProfile.talent_allocations.duplicate()
	var points: int = PlayerProfile.star_coins
	PlayerProfile.talent_allocations = {}
	PlayerProfile.star_coins = 48
	assert(not PlayerProfile.can_allocate_talent("fire_7"))
	assert(PlayerProfile.can_allocate_talent("fire_0"))
	for id: String in catalog.NODES:
		assert(PlayerProfile.can_allocate_talent(id))
		PlayerProfile.talent_allocations[id] = true
	assert(is_equal_approx(PlayerProfile.talent_effect("fire_burn_ratio"), 0.40))
	PlayerProfile.talent_allocations["fire_mastery"] = 100
	assert(PlayerProfile.can_allocate_talent("fire_mastery"))
	assert(PlayerProfile.allocated_talent_points() == 153)
	assert(is_equal_approx(PlayerProfile.talent_effect("fire_damage_multiplier"), 3.41))
	var relics := RelicSystem.new()
	assert(relics.total_effect("fire_burn_ratio") >= 0.40)
	var overlay := PermanentUpgradesOverlay.new()
	add_child(overlay)
	overlay._refresh()
	var node_count := 0
	for child: Node in overlay._tree.get_children():
		if child is Button:
			node_count += 1
	assert(node_count == 54)
	overlay._panning = true
	overlay._pressed_node = "fire_0"
	await overlay._hold_node(overlay._gesture)
	assert(overlay._held)
	assert(is_instance_valid(overlay._inspector))
	assert(PlayerProfile.star_coins == 48)
	overlay._held = false
	overlay._dragged = true
	await overlay._hold_node(overlay._gesture)
	assert(not overlay._held)
	PlayerProfile.talent_allocations = previous
	PlayerProfile.star_coins = points
	print("TALENT TEST PASSED: 54 nodes, repeatable mastery, prerequisites, effects, and hold gestures")
	get_tree().quit()
