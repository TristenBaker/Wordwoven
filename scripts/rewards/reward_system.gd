class_name RewardSystem
extends RefCounted
## Builds and grants rewards from data/rewards.json. A reward is a
## dictionary with a "kind": a modifier sticker to attach to a chosen
## letter ("id"), a letter upgrade ("levels"), punctuation ("mark",
## "count"), or a relic ("id"). Victories offer three mixed choices,
## favoring letter-building kinds in regular fights; exactly one is
## claimed per victory. Events grant rewards through the same path.

const DATA_PATH: String = "res://data/rewards.json"
const KINDS: Array[String] = ["modifier", "upgrade", "punctuation", "relic"]

static var _data: Dictionary = {}
static var _loaded: bool = false

var rng: RandomNumberGenerator = null
var _relic_system: RelicSystem = RelicSystem.new()


func _init(new_rng: RandomNumberGenerator = null) -> void:
	rng = new_rng
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()


static func data() -> Dictionary:
	if not _loaded:
		_load()
	return _data


## The retained victory choices, built once per pending victory.
func victory_choices() -> Array[Dictionary]:
	if RunState.pending_reward_choices.is_empty():
		RunState.pending_reward_choices = build_choices(
			RunState.is_boss_next()
		)
	return RunState.pending_reward_choices


## Three mixed choices: at least two different kinds, and in regular
## fights at least one letter-building reward.
func build_choices(boss: bool) -> Array[Dictionary]:
	var count: int = int(data().get("choice_count", 3))
	var weights: Dictionary = Dictionary(data().get("weights", {})).get(
		"boss" if boss else "regular", {}
	)
	var building: Array = data().get("letter_building", [])
	var kinds: Array[String] = []
	for index: int in count:
		kinds.append(_weighted_kind(weights))
	if not boss and not _has_any(kinds, building):
		kinds[0] = String(building[rng.randi_range(0, building.size() - 1)])
	if _distinct(kinds) < 2 and count > 1:
		kinds[count - 1] = _other_kind(kinds[0], weights)
	var choices: Array[Dictionary] = []
	for kind: String in kinds:
		choices.append(build_reward(kind, choices))
	return choices


## One reward of the kind, avoiding ids already in the list.
func build_reward(
	kind: String, taken: Array[Dictionary] = []
) -> Dictionary:
	match kind:
		"modifier":
			return {"kind": kind, "id": _fresh_id(
				ModifierCatalog.offered_ids(), taken
			)}
		"upgrade":
			var upgrade: Dictionary = data().get("upgrade", {})
			return {"kind": kind, "levels": int(upgrade.get("levels", 2))}
		"punctuation":
			var info: Dictionary = data().get("punctuation", {})
			return {
				"kind": kind,
				"mark": String(info.get("mark", "!")),
				"count": int(info.get("count", 1)),
			}
	return {"kind": "relic", "id": _fresh_id(
		_relic_system.relic_ids(), taken
	)}


## Short title for a choice button.
func title(reward: Dictionary) -> String:
	match String(reward.get("kind", "")):
		"modifier":
			return "%s Sticker" % ModifierCatalog.display_name(
				String(reward["id"])
			)
		"upgrade":
			return "Letter Training +%d" % int(reward["levels"])
		"punctuation":
			return "%d× %s" % [
				int(reward["count"]),
				PunctuationCatalog.display_name(String(reward["mark"])),
			]
		"relic":
			return String(_relic_system.relic_info(
				String(reward["id"])
			).get("name", reward["id"]))
		"gold":
			return "%d gold" % int(reward["amount"])
	return "Nothing"


## Exact effect text for previews and confirmations.
func describe(reward: Dictionary) -> String:
	match String(reward.get("kind", "")):
		"modifier":
			return "Attach to a letter you choose: %s" % \
					ModifierCatalog.describe(String(reward["id"]))
		"upgrade":
			return "One letter you choose gains %d levels." % \
					int(reward["levels"])
		"punctuation":
			return PunctuationCatalog.describe(String(reward["mark"]))
		"relic":
			return String(_relic_system.relic_info(
				String(reward["id"])
			).get("description", ""))
		"gold":
			return "Added to your purse at once."
	return ""


## True when the reward must be attached to a chosen letter.
func needs_target(reward: Dictionary) -> bool:
	return String(reward.get("kind", "")) in ["modifier", "upgrade"]


## Owned instances the reward may be applied to.
func target_candidates(reward: Dictionary) -> Array[LetterStats]:
	var candidates: Array[LetterStats] = []
	if not needs_target(reward):
		return candidates
	for stats: LetterStats in RunState.deck:
		if stats.letter == RunState.forgotten_letter:
			continue
		if String(reward["kind"]) == "modifier" \
				and not stats.can_add_modifier():
			continue
		candidates.append(stats)
	return candidates


## What the instance becomes, such as "P Lv3 Warrior [Keen]".
func preview(reward: Dictionary, stats: LetterStats) -> String:
	return LetterUpgrade.preview(stats, _as_upgrade(reward))


## Applies a reward without any victory guard. Returns false and
## changes nothing when the reward or target is invalid.
func grant(reward: Dictionary, target: LetterStats = null) -> bool:
	match String(reward.get("kind", "")):
		"modifier", "upgrade":
			if target == null \
					or not target_candidates(reward).has(target):
				return false
			LetterUpgrade.apply(target, _as_upgrade(reward))
			EventBus.emit_deck_changed()
			return true
		"punctuation":
			var mark: String = String(reward.get("mark", ""))
			if not PunctuationCatalog.has_mark(mark):
				return false
			RunState.add_punctuation(mark, int(reward.get("count", 1)))
			return true
		"relic":
			return _relic_system.grant_relic(String(reward.get("id", "")))
		"gold":
			RunState.add_gold(int(reward.get("amount", 0)))
			return true
	return false


## Claims one of the pending victory choices exactly once.
func claim_victory(index: int, target: LetterStats = null) -> bool:
	var encounter: int = RunState.encounter_index
	if not RunState.completed_encounters.has(encounter) \
			or RunState.reward_claims.has(encounter):
		return false
	var choices: Array[Dictionary] = RunState.pending_reward_choices
	if index < 0 or index >= choices.size():
		return false
	var reward: Dictionary = choices[index]
	if String(reward["kind"]) == "relic":
		if not _relic_system.grant_reward(String(reward["id"]), encounter):
			return false
	elif not grant(reward, target):
		return false
	var claim: Dictionary = reward.duplicate()
	claim["index"] = index
	if target != null:
		claim["target"] = target.instance_id
	RunState.reward_claims[encounter] = claim
	return true


func claimed_for_current() -> Dictionary:
	return RunState.reward_claims.get(RunState.encounter_index, {})


func _as_upgrade(reward: Dictionary) -> Dictionary:
	if String(reward.get("kind", "")) == "modifier":
		return {"levels": 0, "modifier": String(reward.get("id", ""))}
	return {"levels": int(reward.get("levels", 0)), "modifier": ""}


func _weighted_kind(weights: Dictionary) -> String:
	var total: float = 0.0
	for kind: String in KINDS:
		total += float(weights.get(kind, 0))
	var roll: float = rng.randf() * total
	for kind: String in KINDS:
		roll -= float(weights.get(kind, 0))
		if roll < 0.0:
			return kind
	return KINDS[0]


func _other_kind(kind: String, weights: Dictionary) -> String:
	var others: Dictionary = weights.duplicate()
	others.erase(kind)
	return _weighted_kind(others)


func _fresh_id(ids: Array[String], taken: Array[Dictionary]) -> String:
	var pool: Array[String] = ids.duplicate()
	for reward: Dictionary in taken:
		pool.erase(String(reward.get("id", "")))
	if pool.is_empty():
		pool = ids.duplicate()
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]


func _has_any(kinds: Array[String], wanted: Array) -> bool:
	for kind: String in kinds:
		if wanted.has(kind):
			return true
	return false


func _distinct(kinds: Array[String]) -> int:
	var seen: Array[String] = []
	for kind: String in kinds:
		if not seen.has(kind):
			seen.append(kind)
	return seen.size()


static func _load() -> void:
	_loaded = true
	_data = {}
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("RewardSystem: cannot open reward data")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RewardSystem: reward data is not valid JSON")
		return
	_data = parsed
