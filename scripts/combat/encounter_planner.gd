class_name EncounterPlanner
extends RefCounted
## Encounter setup rules: stage-appropriate enemy options with one
## previewed environment each, the single chosen adjective tag, and
## the confirmed configuration that combat consumes.

const CHOICE_COUNT: int = 2

var rng: RandomNumberGenerator = null
var icy_chance: float = EnvironmentCatalog.DEFAULT_ICY_CHANCE


func _init(new_rng: RandomNumberGenerator = null) -> void:
	rng = new_rng
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()


## Options for the current encounter, rolled once and then reused
## until the run moves to another encounter.
func options_for_current(factory: EnemyFactory) -> Array[Dictionary]:
	if RunState.encounter_options_index == RunState.encounter_index \
			and not RunState.encounter_options.is_empty():
		return RunState.encounter_options
	RunState.encounter_options = build_options(
		factory, RunState.encounter_index
	)
	RunState.encounter_options_index = RunState.encounter_index
	return RunState.encounter_options


## Rolls enemy options for a stage; the boss stage offers only the boss.
func build_options(
	factory: EnemyFactory, stage: int
) -> Array[Dictionary]:
	var ids: Array[String] = []
	if stage >= RunState.ENCOUNTERS_PER_RUN:
		ids.append(factory.boss_id())
	else:
		var pool: Array[String] = factory.ids_for_stage(stage)
		while ids.size() < CHOICE_COUNT and not pool.is_empty():
			var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
			pool.erase(pick)
			ids.append(pick)
	var options: Array[Dictionary] = []
	for enemy_id: String in ids:
		options.append({
			"enemy_id": enemy_id,
			"environment": EnvironmentCatalog.roll(rng, icy_chance),
		})
	return options


## Normalizes typed text into one dictionary adjective tag.
## Returns {"valid": bool, "tag": String, "reason": String}.
static func normalize_tag(text: String) -> Dictionary:
	var tag: String = text.strip_edges().to_lower()
	if tag.is_empty():
		return _tag_verdict(false, "", "Type one adjective.")
	if tag.split(" ", false).size() > 1 or tag.contains("\t"):
		return _tag_verdict(false, "", "Use a single adjective.")
	var verdict: Dictionary = WordValidator.check_word(tag, "a")
	if not verdict["valid"]:
		return _tag_verdict(
			false, "", "'%s' is not a dictionary adjective." % tag
		)
	return _tag_verdict(true, tag, "")


## The confirmed setup stored in RunState for the current encounter,
## or an empty dictionary when the option or tag is invalid.
static func configure(option: Dictionary, typed_tag: String) -> Dictionary:
	var verdict: Dictionary = normalize_tag(typed_tag)
	if not verdict["valid"]:
		return {}
	var environment: String = String(option.get("environment", ""))
	if not EnvironmentCatalog.has_environment(environment):
		return {}
	return {
		"encounter": RunState.encounter_index,
		"enemy_id": String(option.get("enemy_id", "")),
		"tag": verdict["tag"],
		"environment": environment,
	}


static func _tag_verdict(
	valid: bool, tag: String, reason: String
) -> Dictionary:
	return {"valid": valid, "tag": tag, "reason": reason}
