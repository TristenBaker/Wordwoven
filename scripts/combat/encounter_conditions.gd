class_name EncounterConditions
extends RefCounted
## Temporary letter conditions for one combat encounter. Conditions
## belong to individual letter instances, so duplicate copies stay
## independent, and permanent letter stats are never modified.

# Poison halves an instance's damage, healing, and gold contributions.
const POISON_FACTOR: float = 0.5

var rng: RandomNumberGenerator = null

var _poisoned: Array[LetterStats] = []
var _frozen: Array[LetterStats] = []
var _stolen: Array[LetterStats] = []


func _init(new_rng: RandomNumberGenerator = null) -> void:
	rng = new_rng
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()


func is_poisoned(stats: LetterStats) -> bool:
	return _poisoned.has(stats)


func is_frozen(stats: LetterStats) -> bool:
	return _frozen.has(stats)


func is_stolen(stats: LetterStats) -> bool:
	return _stolen.has(stats)


## Poisons an instance; returns false when it was already poisoned.
func poison(stats: LetterStats) -> bool:
	if stats == null or is_poisoned(stats):
		return false
	_poisoned.append(stats)
	return true


func freeze(stats: LetterStats) -> void:
	if stats != null and not is_frozen(stats):
		_frozen.append(stats)


## Thaws every tile frozen during the previous turn.
func clear_frozen() -> void:
	_frozen = []


func frozen_letters() -> Array[LetterStats]:
	return _frozen.duplicate()


func poisoned_letters() -> Array[LetterStats]:
	return _poisoned.duplicate()


## Marks an instance as taken out of circulation this encounter.
func steal(stats: LetterStats) -> void:
	if stats != null and not is_stolen(stats):
		_stolen.append(stats)


func stolen_letters() -> Array[LetterStats]:
	return _stolen.duplicate()


## Clears and returns every stolen instance so it can re-enter play.
func release_stolen() -> Array[LetterStats]:
	var released: Array[LetterStats] = _stolen.duplicate()
	_stolen = []
	return released


## One random candidate chosen with this encounter's generator.
func pick_random(candidates: Array[LetterStats]) -> LetterStats:
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## Up to count distinct random candidates.
func pick_several(
	candidates: Array[LetterStats], count: int
) -> Array[LetterStats]:
	var pool: Array[LetterStats] = candidates.duplicate()
	var picked: Array[LetterStats] = []
	while picked.size() < count and not pool.is_empty():
		var choice: LetterStats = pick_random(pool)
		pool.erase(choice)
		picked.append(choice)
	return picked


## Player-facing explanation of the instance's current conditions.
func describe(stats: LetterStats) -> String:
	var lines: Array[String] = []
	if is_frozen(stats):
		lines.append(
			"Frozen: this turn it gives only 20% base power, with no"
			+ " class effect or level gain."
		)
	if is_poisoned(stats):
		lines.append(
			"Poisoned: damage, healing, and gold are halved until"
			+ " combat ends."
		)
	return "\n".join(lines)
