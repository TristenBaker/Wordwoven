extends Node
## Uses progression only in memory: no word registration or profile writes.
var failures := 0
var checks := 0


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	RunState.start_new_run()
	PlayerProfile.talent_allocations = {}
	var calculator := DamageCalculator.new()
	add_child(calculator)
	var powers := RelicSystem.new()
	var empty := DamageCalculator.elemental_secondary_effects({})
	for value: int in empty.values():
		check(value == 0, "Absent elements never trigger effects")
	var keys := {"fire": "fire_burn", "water": "water_heal", "ice": "ice_slow", "nature": "nature_poison", "earth": "earth_guard"}
	for element: String in keys:
		var tiny := DamageCalculator.elemental_secondary_effects({element: 0.1})
		check(tiny[keys[element]] == 1, "Weak %s tiles retain their signature effect" % element)
		var strong := DamageCalculator.elemental_secondary_effects({element: 100.0})
		check(strong[keys[element]] > tiny[keys[element]], "%s effects scale with damage" % element)
	var drawn: Array[LetterStats] = []
	for element: int in LetterStats.Element.size():
		var tile := LetterStats.create_item("z", element, 1)
		drawn.append(tile)
		var single: Array[LetterStats] = [tile]
		var low := calculator.calculate("z", single, [], [], "n")
		tile.level = 30
		var high := calculator.calculate("z", single, [], [], "n")
		var name := tile.element_name_text().to_lower()
		check(high.elemental_damage[name] > low.elemental_damage[name], "%s level raises actual elemental damage" % name)
		if keys.has(name):
			check(high[keys[name]] > low[keys[name]], "%s level raises actual signature effect" % name)
		var detail := tile.element_detail_text()
		check(not detail.is_empty() and detail.contains("%"), "%s tooltip explains its calculation" % name)
	var baseline := powers.total_effect("fire_burn_ratio")
	RunState.relics = ["ember_pact", "ember_pact"]
	PlayerProfile.talent_allocations = {"fire_0": 1, "fire_2": 1}
	check(is_equal_approx(powers.total_effect("fire_burn_ratio"), baseline + 0.5 + PlayerProfile.talent_effect("fire_burn_ratio")), "Base, stacked powers, and talents combine additively")
	RunState.relics = []
	PlayerProfile.talent_allocations = {}
	var echo := DamageCalculator.lightning_echo_parameters()
	check(echo.chance > 0.0 and echo.damage_ratio > 0.0, "Baseline lightning has both echo chance and damage")
	seed(314159)
	var found_echo := false
	for index: int in 200:
		if calculator._lightning_echo_damage(20.0).procs > 0:
			found_echo = true
			break
	check(found_echo, "Baseline lightning actually rolls echoes")
	RunState.relics = ["storm_chorus", "storm_chorus", "storm_chorus", "storm_chorus", "storm_chorus", "charged_verse"]
	var guaranteed := calculator._lightning_echo_damage(20.0)
	check(guaranteed.procs == preload("res://data/balance/tuning.gd").LIGHTNING_MAX_PROCS, "Guaranteed echo chains obey safety cap")
	check(is_equal_approx(guaranteed.damage, 20.0 * guaranteed.procs), "Echo damage includes base plus the acquired upgrade")
	RunState.relics = []
	RunState.next_enemy_id = "goblin"
	var combat: Control = load(ScenePaths.COMBAT).instantiate()
	add_child(combat)
	await get_tree().process_frame
	combat._state = combat.State.RESOLVING
	combat.enemy._health = 10000
	combat.enemy._max_health = 10000
	RunState.player_health = 1
	var cast := calculator.calculate("zzzzzz", drawn, [], [], "n")
	combat._apply_elemental_effects(cast)
	check(RunState.player_health == mini(1 + cast.water_heal, RunState.player_max_health), "Combat applies the calculated water healing")
	check(combat._guard == cast.earth_guard and combat._retaliation_reduction == cast.ice_slow, "Combat applies calculated Guard and Chill")
	check(is_equal_approx(combat.enemy.consume_burn(), cast.fire_burn), "Combat applies calculated Burn")
	check(is_equal_approx(combat.enemy.consume_poison(), cast.nature_poison), "Combat applies calculated Poison")
	if not "--logic-only" in OS.get_cmdline_user_args():
		for element: String in ElementArt.ELEMENTS:
			for kind: String in ElementArt.KINDS:
				check(ElementArt.texture(element, kind) != null, "%s %s art loads" % [element, kind])
		combat.queue_free()
		await get_tree().process_frame
		RunState.pending_victory_enemy = "goblin"
		RunState.pending_relic_choices = ["storm_chorus", "prismatic_refrain", "earthward_couplet"]
		var selection: Control = load("res://scenes/post_fight/power_select.tscn").instantiate()
		add_child(selection)
		await get_tree().process_frame
		await get_tree().process_frame
		var panel: Control = selection.get_node("CenterBox/PowerPanel")
		var screen := get_viewport().get_visible_rect()
		check(screen.encloses(panel.get_global_rect()), "Decorated power selection fits the viewport")
		for button: Button in selection.choice_buttons:
			check(button.get_child_count() > 0, "Elemental and universal power cards have art")
			check(panel.get_global_rect().encloses(button.get_global_rect()), "Power card stays inside panel")
		var tooltip := LetterTooltip.create_for(drawn[0])
		selection.add_child(tooltip)
		await get_tree().process_frame
		check(tooltip.size.x <= 360, "Decorated letter tooltip retains compact width")
	print("ELEMENT BASELINE TEST: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
