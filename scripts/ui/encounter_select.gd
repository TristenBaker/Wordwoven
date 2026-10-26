extends Control

const TundraEventScript = preload("res://scripts/encounters/tundra_events.gd")
const Balance = preload("res://data/balance/tuning.gd")
const FISHING_ICON: Texture2D = preload("res://assets/Art/Items/dead fish.png")
const RELIC_TRIAL_ICON: Texture2D = preload("res://assets/Art/Items/route_relic_trial.png")
const FORGE_ICON: Texture2D = preload("res://assets/Art/Items/route_forge.png")
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
					"Plan ahead: every future room type is shown. Each choice closes other paths."
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
			var model: Dictionary = RunState.route_nodes[route_key]
			if String(model.node_type) in ["normal_combat", "elite_combat", "boss"]:
				column_nodes.append(_combat_node(route_key, depth))
			else:
				column_nodes.append(_activity_node(route_key, depth))
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
	var model: Dictionary = RunState.route_nodes[route_key]
	var slot: int = int(model.lane)
	var reveal: String = String(model.reveal_state)
	var state: String = "available" if DebugTools.free_map_select else String(model.visit_state)
	var node_type: String = String(model.node_type)
	var is_boss: bool = node_type == "boss"
	var node: Dictionary = {
		"type": "boss" if is_boss else "enemy", "stage": depth, "slot": slot,
		"route_key": route_key,
		"id": String(model.content_id), "name": "Unknown Route",
		"tags": [], "state": state,
		"node_type": node_type, "reward_tier": int(model.reward_tier),
		"threat_tier": int(model.threat_tier), "reveal_state": reveal,
	}
	if reveal == "hidden":
		node.name = "Unknown"
		node.tooltip = "This distant route has not been revealed."
		return node
	if reveal == "silhouette":
		# Show the foe and encounter class now so the route is strategically
		# readable; health, attack, and rewards remain hidden until nearby.
		node = factory.build_spawn_data(String(model.content_id))
		var future_name: String = String(node.get("name", "Combat"))
		if node_type == "elite_combat":
			future_name = "Elite " + future_name
		node.merge({
			"type": "boss" if is_boss else "enemy", "stage": depth,
			"slot": slot, "route_key": route_key, "state": state,
			"name": future_name,
			"tags": ["Elite" if node_type == "elite_combat" else "Combat"],
			"tooltip": "Future encounter · details revealed when you approach.",
			"node_type": node_type, "reward_tier": int(model.reward_tier),
			"threat_tier": int(model.threat_tier), "reveal_state": reveal,
		}, true)
		return node
	node = factory.build_spawn_data(String(model.content_id))
	node.merge({
		"type": "boss" if is_boss else "enemy", "stage": depth,
		"slot": slot, "route_key": route_key, "state": state,
		"node_type": node_type, "reward_tier": int(model.reward_tier),
		"threat_tier": int(model.threat_tier), "reveal_state": reveal,
	}, true)
	if node_type == "elite_combat":
		node.name = "Elite " + String(node.name)
		node.tags = ["Elite", "Threat %d" % int(model.threat_tier)]
		node.tooltip = "Elite combat · greater danger · reward tier %d" % int(model.reward_tier)
	return node


func _combat_history_index(depth: int) -> int:
	var index: int = 0
	for previous_depth: int in range(1, depth):
		if String(RunState.route_chosen_nodes.get(previous_depth, "")).begins_with("combat_"):
			index += 1
	return index


func _boss_node(depth: int) -> Dictionary:
	return _combat_node(RunState.route_boss_key, depth)


func _activity_node(route_key: String, depth: int) -> Dictionary:
	var model: Dictionary = RunState.route_nodes[route_key]
	var id: String = String(model.content_id)
	var node_type: String = String(model.node_type)
	var reveal: String = String(model.reveal_state)
	var data: Dictionary
	if reveal == "hidden":
		data = {"name": "Unknown", "tooltip": "This distant route has not been revealed."}
	elif reveal == "silhouette":
		data = _future_activity_preview(id, node_type)
		data["tooltip"] = "Future room · reward tier %d" % int(model.reward_tier)
	elif id == "ice_fishing":
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
	elif id == "forge":
		data = {
			"name": "Runic Forge", "subtitle": "Improve letters",
			"tooltip": "Use your loose letters to forge an upgrade.",
			"preview_texture": FORGE_ICON, "accent": Color("d88acb"),
		}
	else:
		data = TundraEventScript.definition(id)
		data["subtitle"] = String(data.get("mini_game", "Side Quest"))
		data["tooltip"] = String(data.get("description", ""))
		data["preview_texture"] = RELIC_TRIAL_ICON if id == "hangman" else TundraEventScript.frame_texture(data, 0)
		data["accent"] = Color("a98de0")
	var state: String = "available" if DebugTools.free_map_select else String(model.visit_state)
	data.merge({
		"type": "activity", "activity_id": route_key, "stage": depth,
		"slot": int(model.lane), "route_key": route_key, "state": state,
		"node_type": node_type, "reward_tier": int(model.reward_tier),
		"threat_tier": int(model.threat_tier), "reveal_state": reveal,
	}, true)
	return data


func _activity_category_name(node_type: String) -> String:
	match node_type:
		"treasure": return "Treasure"
		"letter_reward": return "Letter Reward"
		"relic_reward": return "Relic Trial"
		"recovery": return "Warmth"
		"forge": return "Forge"
		"lore": return "Lore"
	return "Tundra Event"


func _future_activity_preview(id: String, node_type: String) -> Dictionary:
	if id == "ice_fishing":
		return {"name": "Ice Fishing", "preview_texture": FISHING_ICON, "accent": Color("78c9ec")}
	if id == "lore_room":
		return {"name": "Voice in the Ice", "preview_texture": LORE_ICON, "accent": Color("9edcf2")}
	if id == "forge":
		return {"name": "Runic Forge", "preview_texture": FORGE_ICON, "accent": Color("d88acb")}
	if id == "hangman":
		return {"name": "Relic Trial", "preview_texture": RELIC_TRIAL_ICON, "accent": Color("a98de0")}
	var definition: Dictionary = TundraEventScript.definition(id)
	if not definition.is_empty():
		return {
			"name": String(definition.get("name", _activity_category_name(node_type))),
			"preview_texture": TundraEventScript.frame_texture(definition, 0),
			"accent": Color("a98de0"),
		}
	return {"name": _activity_category_name(node_type), "accent": Color("a98de0")}


func _on_choice_pressed(enemy_id: String) -> void:
	RunState.next_enemy_id = enemy_id
	get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_MODIFIER)


func _on_route_node_selected(route_key: String) -> void:
	if DebugTools.free_map_select:
		var depth: int = int(RunState.route_nodes.get(route_key, {}).get("column", 0)) + 1
		if not RunState.debug_jump_to_route_node(route_key, depth):
			return
		return
	if RunState.select_route_node(route_key):
		RunState.activate_pending_route_node()


func _on_activity_pressed(route_key: String) -> void:
	var id: String = RunState.route_activity_id(route_key)
	if id == "ice_fishing":
		if RunState.begin_fishing_route(route_key):
			get_tree().change_scene_to_file(ScenePaths.ICE_FISHING)
		return
	if id == "lore_room":
		if RunState.begin_lore_room(route_key):
			get_tree().change_scene_to_file(ScenePaths.LORE_ROOM)
		return
	if id == "forge":
		if RunState.begin_route_utility(id, route_key):
			get_tree().change_scene_to_file(ScenePaths.FORGE)
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
