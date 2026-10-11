class_name TundraEvents
extends RefCounted
## Optional rewards use existing RunState APIs; combat-local systems remain untouched.
const DATA_PATH: String = "res://data/tundra_events.json"
const IDS: Array[String] = ["frozen_traveler", "treasure_chest", "icy_portal"]

static func definition(id: String) -> Dictionary:
	var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return catalogue.get(id, {}).duplicate(true)

static func frame_texture(data: Dictionary, frame: int) -> AtlasTexture:
	var sheet: Texture2D = load(String(data.texture))
	var width: int = int(data.frame_width)
	var start: int = frame * width
	var actual_width: int = mini(width, sheet.get_width() - start)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(start, 0, actual_width, sheet.get_height())
	# The chest's last cell is one pixel shorter; transparent padding keeps every
	# displayed frame the same size without resampling or editing the source PNG.
	atlas.margin = Rect2(0, 0, width - actual_width, 0)
	atlas.filter_clip = true
	return atlas

static func rules(id: String) -> GDScript:
	match id:
		"frozen_traveler": return preload("res://scripts/encounters/traveler_rescue.gd")
		"icy_portal": return preload("res://scripts/encounters/portal_stabilization.gd")
		"treasure_chest": return preload("res://scripts/encounters/chest_locks.gd")
	return null

static func progress(id: String) -> Dictionary:
	if not RunState.optional_encounter_progress.has(id):
		RunState.optional_encounter_progress[id] = rules(id).initial_state()
	return RunState.optional_encounter_progress[id]

## Validate at the service boundary as well as providing human-readable feedback.
static func submit_word(id: String, text: String, choice: int = -1) -> Dictionary:
	if not RunState.optional_encounter_available(id) or RunState.pending_optional_encounter != id:
		return {"valid": false, "reason": "This encounter is already complete."}
	if not WordNet.is_ready:
		return {"valid": false, "reason": "The lexicon is warming up. Try again in a moment."}
	var word: String = text.strip_edges().to_lower()
	var validator := WordValidator.new()
	var verdict: Dictionary = validator.validate(word, String(definition(id).pos))
	validator.free()
	if not verdict.valid:
		return verdict
	var state: Dictionary = progress(id)
	var game: GDScript = rules(id)
	if game.is_finished(state) or state.awaiting_next:
		return {"valid": false, "reason": "Continue to the next round first."}
	var choices: Array = game.presentation(state).choices
	if not choices.is_empty() and (choice < 0 or choice >= choices.size()):
		return {"valid": false, "reason": "Choose a portal action first."}
	game.play(state, word, choice)
	return {"valid": true, "reason": "", "result": complete(id) if game.is_finished(state) else {}}

static func next_round(id: String) -> void:
	if RunState.pending_optional_encounter == id and RunState.optional_encounter_available(id):
		progress(id).awaiting_next = false

## Rewards derive only from stored, completed gameplay; callers cannot supply a score.
static func complete(id: String, skipped: bool = false) -> Dictionary:
	if not RunState.optional_encounter_available(id) or RunState.pending_optional_encounter != id:
		return {}
	var state: Dictionary = progress(id)
	if not skipped and not rules(id).is_finished(state):
		return {}
	var result: Dictionary = {"skipped": skipped, "words": state.words.duplicate(), "word": "", "dialogue": "You leave the mystery for another adventurer.", "reward": "No reward.", "score": state.value}
	if not state.words.is_empty():
		result.word = state.words[-1]
	# Claim before emitting gold signals, preventing re-entrant and double rewards.
	RunState.optional_encounters[id] = result
	if not skipped:
		var earned: Dictionary = rules(id).outcome(state)
		result.dialogue = "%s\n%s" % [state.feedback, earned.dialogue]
		match String(earned.type):
			"heal":
				var before: int = RunState.player_health
				RunState.heal_player(int(earned.amount))
				var restored: int = RunState.player_health - before
				result.reward = "Restored %d HP." % restored if restored > 0 else ("Already at full health. Your toes appreciate the gesture." if int(earned.amount) > 0 else "No reward.")
			"gold":
				RunState.add_gold(int(earned.amount))
				result.reward = "Found %d gold." % int(earned.amount) if int(earned.amount) > 0 else "No reward."
	return result.duplicate(true)
