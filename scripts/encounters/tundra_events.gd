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

static func complete(id: String, word: String, skipped: bool = false) -> Dictionary:
	if not RunState.optional_encounter_available(id) or RunState.pending_optional_encounter != id:
		return {}
	var data: Dictionary = definition(id)
	var result: Dictionary = {"skipped": skipped, "word": word, "dialogue": "You leave the mystery for another adventurer.", "reward": "No reward."}
	# Claim before emitting any gold/health signals, preventing re-entrant rewards.
	RunState.optional_encounters[id] = result
	if not skipped:
		result.dialogue = String(data.templates.pick_random()).format({"word": word})
		var reward: Dictionary = data.rewards.pick_random()
		var before: int = RunState.player_health
		match String(reward.type):
			"heal":
				RunState.heal_player(int(reward.amount))
				var restored: int = RunState.player_health - before
				result.reward = "Restored %d HP." % restored if restored > 0 else "Already at full health. Your toes appreciate the gesture."
			"gold":
				RunState.add_gold(int(reward.amount))
				result.reward = "Found %d gold." % int(reward.amount)
			"damage":
				# A silly optional mishap never ends a run outside the combat flow.
				var amount: int = mini(int(reward.amount), maxi(0, before - 1))
				if amount > 0:
					RunState.damage_player(amount)
				result.reward = "Lost %d HP to a magical hiccup. The portal apologizes." % amount
	return result.duplicate(true)
