extends Node
## Integration coverage for relocated balance data without scene-layout assumptions.
var failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var run = RunState
	run.start_new_run()
	check(run.player_health == 50 and run.gold == 0, "Starting resources preserved")
	check(run.equipped_letters.size() == 10, "Starter inventory preserved")
	var heavy := LetterStats.create("z")
	heavy.level = 3
	heavy.modifier = LetterStats.Modifier.HEAVY
	check(is_equal_approx(heavy.power(), 19.0), "Letter power and modifier preserved")
	var economy := EconomySystem.new()
	check(economy.letter_dealer_price(heavy) == 15, "Dealer level pricing preserved")
	check(economy.recruit_price("a") == 10 and economy.recruit_price("z") == 20, "Recruit pricing preserved")
	economy.free()
	var factory := EnemyFactory.new()
	add_child(factory)
	run.selected_biome = "tundra"
	for stage: int in range(1, run.ENCOUNTERS_PER_RUN + 1):
		run.encounter_index = stage
		var ids: Array[String] = factory.ids_for_stage(stage)
		check(not ids.is_empty(), "Enemy roster exists for every stage")
		for id: String in ids:
			var spawn: Dictionary = factory.build_spawn_data(id)
			check(not spawn.is_empty() and int(spawn.get("health", 0)) > 0, "Enemy catalog resolves " + id)
	factory.free()
	var relics := RelicSystem.new()
	check(not relics.relic_ids().is_empty(), "Power catalog loaded")
	check(relics.roll_choices(3).size() == 3, "Power reward selection works")
	var ingredients: Array[LetterStats] = []
	for index: int in 3:
		ingredients.append(LetterStats.create_item("a", LetterStats.Element.FIRE, 2))
	var forge := ForgeSystem.new()
	check(forge.forge(ingredients, true).level == 3, "Successful forge preserves level gain")
	check(forge.forge(ingredients, false).level == 2, "Failed forge preserves level")
	for id: String in TundraEvents.IDS:
		check(not TundraEvents.definition(id).is_empty(), "Optional encounter catalog resolves " + id)
		check(TundraEvents.rules(id) != null, "Optional encounter rules resolve " + id)
	print("Balance integration: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
