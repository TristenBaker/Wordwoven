extends Control

const TundraEventScript = preload("res://scripts/encounters/tundra_events.gd")
const Balance = preload("res://data/balance/tuning.gd")
const FISHING_ICON: Texture2D = preload("res://assets/Art/Items/dead fish.png")
const HANGMAN_ICON: Texture2D = preload("res://assets/Art/Items/scroll.png")
const LORE_ICON: Texture2D = preload("res://assets/Art/Items/scroll.png")
const ROUTE_ACTIVITY_ORDER: Array[String] = [
	"ice_fishing", "frozen_traveler", "icy_portal", "treasure_chest",
]
## Presents the run as a left-to-right expedition map. Completed
## encounters remain visible, the current stage branches into enemy
## choices, and every route converges on the final boss. Tundra runs
## expose every undefeated regular foe; other biomes offer two choices.

const CHOICE_COUNT: int = preload("res://data/balance/tuning.gd").ENCOUNTER_SELECT_CHOICE_COUNT

@onready var factory: EnemyFactory = $EnemyFactory
@onready var title_label: Label = $Header/TitleLabel
@onready var subtitle_label: Label = $Header/SubtitleLabel
@onready var progress_label: Label = $ProgressBadge/ProgressLabel
@onready var route_map: Control = \
		$MapPanel/Margin/Content/RouteMap


func _ready() -> void:
	var stage: int = RunState.encounter_index
	progress_label.text = "ENCOUNTER %d / %d" % [
		mini(stage, RunState.ENCOUNTERS_PER_RUN),
		RunState.ENCOUNTERS_PER_RUN,
	]
	route_map.enemy_selected.connect(_on_choice_pressed)
	route_map.activity_selected.connect(_on_activity_pressed)
	route_map.route_node_selected.connect(_on_route_node_selected)
	var detours := get_node_or_null("MapPanel/Margin/Content/OptionalChoices") as Control
	# Activities now live on the route itself instead of in a separate sidebar.
	if detours != null:
		detours.visible = false
	if RunState.selected_biome == "tundra":
		RunState.ensure_tundra_route_plan()
		progress_label.text = "ROOM %d / %d   •   %d FIGHTS WON" % [
			RunState.route_depth, RunState.route_graph_columns.size(),
			RunState.encounter_index - 1,
		]
		if RunState.is_boss_next():
			title_label.text = "The End of the Road"
			subtitle_label.text = \
					"One final gate remains. Defeat its guardian to finish the run."
		else:
			title_label.text = "Chart Your Course"
			subtitle_label.text = \
					"Each room advances the journey. Your route closes paths behind you."
		if DebugTools.free_map_select:
			title_label.text = "Free Encounter Select"
			subtitle_label.text = "Debug mode: choose any room on the map."
		route_map.setup_full(RunState.route_depth, _build_tundra_route())
		return
	if RunState.is_boss_next():
		title_label.text = "The End of the Road"
		subtitle_label.text = \
				"One final gate remains. Defeat its guardian to finish the run."
		var boss_data: Dictionary = factory.build_spawn_data(
			factory.boss_id()
		)
		var no_choices: Array[Dictionary] = []
		route_map.setup(stage, no_choices, boss_data)
		return
	var ids: Array[String] = factory.ids_for_stage(stage)
	ids.shuffle()
	var count: int = mini(CHOICE_COUNT, ids.size())
	var choices: Array[Dictionary] = []
	for i: int in count:
		choices.append(factory.build_spawn_data(ids[i]))
	choices.append_array(_route_activity_choices(stage))
	route_map.setup(stage, choices, {})


func _build_tundra_route() -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for column_index: int in RunState.route_graph_columns.size():
		var depth: int = column_index + 1
		var column_nodes: Array[Dictionary] = []
		for route_key: String in RunState.route_graph_columns[column_index]:
			if route_key == "boss":
				column_nodes.append(_boss_node(depth))
			elif route_key.begins_with("activity_"):
				column_nodes.append(_activity_node(
					route_key.trim_prefix("activity_"), depth
				))
			else:
				column_nodes.append(_combat_node(route_key, depth))
		_append_column(nodes, column_nodes, depth, "")
	for node: Dictionary in nodes:
		node["next_keys"] = RunState.route_edges.get(
				String(node.get("route_key", "")), []
		).duplicate()
	return nodes


func _append_column(
	nodes: Array[Dictionary], column_nodes: Array[Dictionary],
	column: int, label: String
) -> void:
	for lane: int in column_nodes.size():
		column_nodes[lane]["column"] = column
		column_nodes[lane]["column_count"] = RunState.route_graph_columns.size()
		column_nodes[lane]["column_label"] = label
		column_nodes[lane]["lane"] = lane
		column_nodes[lane]["lane_count"] = column_nodes.size()
		nodes.append(column_nodes[lane])


func _combat_node(route_key: String, depth: int) -> Dictionary:
	var slot: int = int(route_key.get_slice("_", 2))
	if DebugTools.free_map_select:
		var enemy_id: String = Balance.TUNDRA_STARTER_ENEMY if depth == 1 else \
			RunState.route_enemy_order[(depth + slot) % RunState.route_enemy_order.size()]
		var debug_node: Dictionary = factory.build_spawn_data(enemy_id)
		debug_node.merge({
			"type": "enemy", "stage": depth, "slot": slot,
			"route_key": route_key, "state": "available",
		}, true)
		return debug_node
	var node: Dictionary = {
		"type": "enemy", "stage": depth, "slot": slot,
		"route_key": route_key,
		"id": "", "name": "Unknown Foe", "tags": ["Combat"],
		"state": "locked",
	}
	if depth < RunState.route_depth:
		var chosen_key: String = String(RunState.route_chosen_nodes.get(
				depth, ""
		))
		var history_index: int = _combat_history_index(depth)
		if route_key == chosen_key and history_index < RunState.defeated_enemy_history.size():
			var enemy_id: String = RunState.defeated_enemy_history[history_index]
			node = factory.build_spawn_data(enemy_id)
			node.merge({
				"type": "enemy", "stage": depth, "slot": slot,
				"route_key": route_key,
				"state": "completed",
			}, true)
		else:
			node["name"] = "Path Not Taken"
			node["tags"] = ["Bypassed"]
			node["state"] = "bypassed"
		return node
	if depth > RunState.route_depth:
		return node
	var ids: Array[String]
	if depth == 1:
		ids = factory.ids_for_stage(1)
	else:
		ids = RunState.available_route_enemies(CHOICE_COUNT)
	if slot >= ids.size():
		node["name"] = "Path Closed"
		node["tags"] = ["No foe remains"]
		node["state"] = "bypassed"
		return node
	node = factory.build_spawn_data(ids[slot])
	node.merge({
		"type": "enemy", "stage": depth, "slot": slot,
		"route_key": route_key,
		"state": "available",
	}, true)
	if not RunState.route_key_available(route_key):
		node["state"] = "locked"
	return node


func _combat_history_index(depth: int) -> int:
	var index: int = 0
	for previous_depth: int in range(1, depth):
		if String(RunState.route_chosen_nodes.get(previous_depth, "")).begins_with("combat_"):
			index += 1
	return index


func _boss_node(depth: int) -> Dictionary:
	var data: Dictionary = factory.build_spawn_data(factory.boss_id())
	var available: bool = DebugTools.free_map_select or (depth == RunState.route_depth \
			and RunState.route_key_available("boss"))
	data.merge({
		"type": "boss", "stage": depth, "slot": 0,
		"route_key": "boss", "state": "available" if available else "locked",
	}, true)
	return data


func _activity_node(id: String, depth: int) -> Dictionary:
	var data: Dictionary
	var completed: bool = RunState.route_activity_completed(id)
	if id == "ice_fishing":
		data = {
			"name": "Ice Fishing",
			"subtitle": "Warm-word challenge",
			"tooltip": "Catch a fish for a letter reward.",
			"preview_texture": FISHING_ICON,
			"accent": Color("78c9ec"),
		}
	elif id == "lore_room":
		data = {
			"name": "Voice in the Ice",
			"subtitle": "A frozen memory",
			"tooltip": "Listen to a memory left inside the glacier.",
			"preview_texture": LORE_ICON,
			"accent": Color("9edcf2"),
		}
	else:
		data = TundraEventScript.definition(id)
		data["subtitle"] = String(data.get("mini_game", "Side Quest"))
		data["tooltip"] = String(data.get("description", ""))
		data["preview_texture"] = HANGMAN_ICON if id == "hangman" else TundraEventScript.frame_texture(data, 0)
		data["accent"] = Color("a98de0")
	var state: String = "locked"
	var route_key: String = "activity_" + id
	var chosen: bool = String(RunState.route_chosen_nodes.get(depth, "")) == route_key
	if completed and chosen:
		state = "completed"
	elif depth < RunState.route_depth:
		state = "bypassed"
	elif depth == RunState.route_depth:
		var available: bool
		if id == "ice_fishing":
			available = RunState.fishing_route_available()
		elif id == "lore_room":
			available = RunState.lore_room_available()
		else:
			available = RunState.optional_encounter_available(id)
		if not RunState.route_key_available(route_key):
			available = false
		state = "available" if available else "locked"
	data.merge({
		"type": "activity", "activity_id": id, "stage": depth,
		"slot": 0, "route_key": route_key,
		"state": "available" if DebugTools.free_map_select else state,
	}, true)
	return data


func _on_choice_pressed(enemy_id: String) -> void:
	RunState.next_enemy_id = enemy_id
	get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_MODIFIER)


func _on_route_node_selected(route_key: String) -> void:
	if DebugTools.free_map_select:
		var depth: int = RunState.route_graph_columns.size() if route_key == "boss" else \
			int(route_key.get_slice("_", 1))
		if not RunState.debug_jump_to_route_node(route_key, depth):
			return
	RunState.record_route_choice(RunState.route_depth, route_key)


func _on_activity_pressed(id: String) -> void:
	var route_key: String = "activity_" + id
	if DebugTools.free_map_select:
		var depth: int = int(RunState.route_activity_stages.get(id, -1))
		if not RunState.debug_jump_to_route_node(route_key, depth):
			return
	if id == "ice_fishing":
		if RunState.begin_fishing_route(route_key):
			get_tree().change_scene_to_file(ScenePaths.ICE_FISHING)
		return
	if id == "lore_room":
		if RunState.begin_lore_room(route_key):
			get_tree().change_scene_to_file(ScenePaths.LORE_ROOM)
		return
	if RunState.begin_optional_encounter(id, route_key):
		get_tree().change_scene_to_file(ScenePaths.HANGMAN if id == "hangman" else ScenePaths.TUNDRA_EVENT)


func _route_activity_choices(stage: int) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if RunState.selected_biome != "tundra" or stage <= 1 \
			or RunState.is_boss_next():
		return choices
	# Rotate the four detours between stages and show at most two alongside
	# combat. Completed activities disappear, revealing another branch.
	var offset: int = ((stage - 2) * 2) % ROUTE_ACTIVITY_ORDER.size()
	for step: int in ROUTE_ACTIVITY_ORDER.size():
		var id: String = ROUTE_ACTIVITY_ORDER[
			(offset + step) % ROUTE_ACTIVITY_ORDER.size()
		]
		if id == "ice_fishing":
			if RunState.fishing_route_available():
				choices.append({
					"type": "activity",
					"activity_id": id,
					"name": "Ice Fishing",
					"subtitle": "Warm-word challenge · letter reward",
					"tooltip": "A safe detour. Catch a fish without skipping the next battle.",
					"preview_texture": FISHING_ICON,
					"accent": Color("78c9ec"),
				})
		elif RunState.optional_encounter_available(id):
			var data: Dictionary = TundraEventScript.definition(id)
			data["type"] = "activity"
			data["activity_id"] = id
			data["subtitle"] = String(data.get("mini_game", "Side Quest"))
			data["tooltip"] = "%s This detour does not skip the next battle." % \
					String(data.get("description", ""))
			data["preview_texture"] = TundraEventScript.frame_texture(data, 0)
			data["accent"] = Color("a98de0")
			choices.append(data)
		if choices.size() >= 2:
			break
	return choices
