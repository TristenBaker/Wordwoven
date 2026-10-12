extends Node

var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	var combat = load(ScenePaths.COMBAT).instantiate()
	add_child(combat)
	var letters: Array[LetterStats] = [LetterStats.create("k"), LetterStats.create_item("a", LetterStats.Element.ICE), LetterStats.create("b")]
	var empty: Array[String] = []
	var calculated: Dictionary = combat.calculator.calculate("kab", letters, empty, empty, "n")
	check(calculated.gold == 2, "preview includes both Rogue elements, excludes Warrior")
	var before: int = RunState.gold
	combat.party_stage.sync_letters(letters)
	combat.party_stage.perform_word(combat.enemy.strike_point())
	check(RunState.gold == before, "gold is not awarded before impact")
	await combat.party_stage.performance_finished
	check(RunState.gold == before + 2, "each Rogue awards one gold on impact")
	check(combat.gold_label.text == "Gold: %d" % RunState.gold, "gold display updates")
	for entry: Array in [["res://scripts/ui/equipment_overlay.gd", "_open_item_inspector_if_still_held"], ["res://scripts/tavern/dealer_room.gd", "_open_offer_inspector_if_still_held"]]:
		var owner: Control = load(entry[0]).new()
		var button := Button.new()
		var reference: WeakRef = weakref(button)
		get_tree().create_timer(0.01).timeout.connect(Callable(owner, entry[1]).bind(reference, letters[0], 1))
		button.free()
		await get_tree().create_timer(0.02).timeout
		owner.free()
	check(AppSettings.DEFAULTS.master_volume == 50.0 and AppSettings.DEFAULTS.music_volume == 50.0 and AppSettings.DEFAULTS.sfx_volume == 50.0, "sound defaults are 50 percent")
	combat.queue_free()
	await get_tree().process_frame
	print("Rogue/inspector regression tests: ", failures, " failures")
	get_tree().quit(1 if failures else 0)
