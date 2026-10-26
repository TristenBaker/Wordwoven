extends Node

const Generator = preload("res://scripts/run/expedition_route_generator.gd")
const Balance = preload("res://data/balance/tuning.gd")

var failures: int = 0


func check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _ready() -> void:
	var first: Dictionary = Generator.generate(424242, "tundra")
	var replay: Dictionary = Generator.generate(424242, "tundra")
	var different: Dictionary = Generator.generate(424243, "tundra")
	check(_signature(first) == _signature(replay), "Same seed reproduces the graph")
	check(_signature(first) != _signature(different), "Different seeds normally differ")
	_validate_graph(first)
	for seed_value: int in range(1, 101):
		var graph: Dictionary = Generator.generate(seed_value, "tundra")
		_validate_graph(graph, false)
		check(_can_reach_boss(graph), "Seed %d reaches the boss" % seed_value)
		check(_all_paths_meet_constraints(graph), "Seed %d keeps every path valid" % seed_value)
	_test_run_state()
	print("Expedition route graph: %d failures" % failures)
	get_tree().quit(1 if failures else 0)


func _signature(graph: Dictionary) -> String:
	var rows: Array[String] = []
	for column: Array in graph.columns:
		for key: String in column:
			var node: Dictionary = graph.nodes[key]
			rows.append("%s:%s:%s:%s" % [
				key, node.node_type, node.content_id, ",".join(node.next_keys),
			])
	return "|".join(rows)


func _validate_graph(graph: Dictionary, verbose: bool = true) -> void:
	var nodes: Dictionary = graph.nodes
	var incoming: Dictionary = {}
	check(graph.columns.size() >= 3, "Route has enough layers to branch")
	check(graph.columns[1].size() == 3, "The first room immediately splits three ways")
	for key: String in nodes:
		incoming[key] = 0
	for key: String in nodes:
		var node: Dictionary = nodes[key]
		if key != graph.boss_key:
			check(not node.next_keys.is_empty(), "Nonterminal node has an exit")
			if int(node.column) < graph.columns.size() - 2:
				check(node.next_keys.size() >= 2, "Most rooms preserve onward route choice")
		for next_key: String in node.next_keys:
			check(nodes.has(next_key), "Edge target exists")
			if nodes.has(next_key):
				check(int(nodes[next_key].column) > int(node.column), "Edges only move forward")
				incoming[next_key] = int(incoming[next_key]) + 1
		var type: String = String(node.node_type)
		# Activities may intentionally repeat when they belong to different
		# branches; the route choice, not global uniqueness, supplies variety.
		for next_key: String in node.next_keys:
			var next_type: String = String(nodes[next_key].node_type)
			check(
				not (type in ["recovery", "forge"] and next_type in ["recovery", "forge"]),
				"Recovery and forge nodes are not consecutive"
			)
	for key: String in nodes:
		if key != graph.start_key:
			check(int(incoming[key]) > 0, "Every non-start node has an incoming edge")
	var from_start: Dictionary = _reachable(graph, String(graph.start_key))
	check(from_start.size() == nodes.size(), "Every node is reachable from the start")
	for key: String in nodes:
		check(_reachable(graph, key).has(graph.boss_key), "Every node can reach the boss")
	if verbose:
		check(_all_paths_meet_constraints(graph), "Every path has combat and build opportunities")


func _reachable(graph: Dictionary, start_key: String) -> Dictionary:
	var found: Dictionary = {}
	var pending: Array[String] = [start_key]
	while not pending.is_empty():
		var key: String = pending.pop_back()
		if found.has(key):
			continue
		found[key] = true
		for next_key: String in graph.nodes[key].next_keys:
			pending.append(next_key)
	return found


func _can_reach_boss(graph: Dictionary) -> bool:
	return _reachable(graph, String(graph.start_key)).has(graph.boss_key)


func _all_paths_meet_constraints(graph: Dictionary) -> bool:
	var pending: Array[Dictionary] = [{
		"key": graph.start_key, "combats": 0, "build": false,
	}]
	while not pending.is_empty():
		var path: Dictionary = pending.pop_back()
		var node: Dictionary = graph.nodes[path.key]
		var type: String = String(node.node_type)
		var combats: int = int(path.combats) + (1 if type in ["normal_combat", "elite_combat"] else 0)
		var build: bool = bool(path.build) or type in ["letter_reward", "relic_reward", "forge"]
		if path.key == graph.boss_key:
			if combats < Balance.ROUTE_MIN_COMBATS_PER_PATH or not build:
				return false
			continue
		for next_key: String in node.next_keys:
			pending.append({"key": next_key, "combats": combats, "build": build})
	return true


func _test_run_state() -> void:
	RunState.start_new_run()
	RunState.selected_biome = "tundra"
	RunState.initialize_tundra_route(99117)
	var signature: String = _signature({
		"columns": RunState.route_graph_columns,
		"nodes": RunState.route_nodes,
	})
	check(RunState.route_key_available(RunState.route_start_key), "Only the start is initially available")
	check(RunState.select_route_node(RunState.route_start_key), "Start can be selected")
	check(RunState.activate_pending_route_node(), "Pending start becomes current")
	check(RunState.complete_current_route_node(), "Current node completes once")
	check(not RunState.complete_current_route_node(), "A completed node cannot reward twice")
	var exits: Array = RunState.route_edges[RunState.route_current_key]
	for key: String in RunState.route_nodes:
		check(
			RunState.route_key_available(key) == exits.has(key),
			"Only outgoing neighbors are selectable"
		)
	var chosen: String = String(exits[0])
	check(RunState.select_route_node(chosen), "An outgoing branch can be selected")
	for sibling: String in exits:
		if sibling != chosen:
			check(String(RunState.route_nodes[sibling].visit_state) == "bypassed", "Incompatible sibling is bypassed")
	RunState.ensure_tundra_route_plan()
	check(signature == _signature({
		"columns": RunState.route_graph_columns,
		"nodes": RunState.route_nodes,
	}), "Reopening the map does not regenerate the graph")
	var graph_before_debug: String = signature
	var debug_key: String = String(RunState.route_graph_columns[-2][0])
	check(RunState.debug_jump_to_route_node(debug_key, 0), "Debug free-select can jump")
	check(graph_before_debug == _signature({
		"columns": RunState.route_graph_columns,
		"nodes": RunState.route_nodes,
	}), "Debug free-select does not mutate graph structure")
