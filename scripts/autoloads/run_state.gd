extends Node
## Holds the state of the current roguelike run: player health,
## gold, the letter deck, relics, progress, and the word history
## that the tavern storyteller retells. Also carries the run-long
## gameplay state: Inspiration, punctuation, vows, the forgotten
## letter, pilgrimage loans, event progress, and reward claims.
## Survives scene changes; contains no combat or UI logic.

const STARTING_HEALTH: int = 50
const STARTING_GOLD: int = 0
const ENCOUNTERS_PER_RUN: int = 6

var player_max_health: int = STARTING_HEALTH
var player_health: int = STARTING_HEALTH
var gold: int = STARTING_GOLD

# The letter characters the player owns.
var deck: Array[LetterStats] = []
# The id the next owned letter instance receives.
var next_letter_id: int = 1

# Relic identifiers, resolved by the relic system.
var relics: Array[String] = []

# Completed fights and their chosen relics prevent repeated rewards.
var completed_encounters: Array[int] = []
var relic_rewards: Dictionary[int, String] = {}

# Transient post-fight presentation data. These values carry a completed
# encounter through the bard, reward, and loot screens before the run
# advances.
var pending_victory_enemy: String = ""
var pending_victory_gold: int = 0
# Lines such as pilgrims returning, shown with the victory tale.
var pending_victory_notes: Array[String] = []
# The three reward choices offered for the pending victory.
var pending_reward_choices: Array[Dictionary] = []
# Encounter -> the reward claimed there, so it can never repeat.
var reward_claims: Dictionary[int, Dictionary] = {}

# Shop stock survives leaving and reopening the tavern.
var recruitment_encounter: int = -1
var recruitment_stock: Array[Dictionary] = []

# 1-based index of the next encounter; the last one is the boss.
var encounter_index: int = 1

# Enemy chosen on the encounter-select screen; empty means the
# combat scene should roll one for the current stage.
var next_enemy_id: String = ""

# Menu selection only; gameplay does not consume this yet.
var selected_biome: String = ""
# Previewed encounter options, kept stable for one encounter index:
# entries of {"enemy_id": String, "environment": String}.
var encounter_options_index: int = -1
var encounter_options: Array[Dictionary] = []

# Confirmed setup consumed by combat without rerolling:
# {"encounter", "enemy_id", "tag", "environment"}.
var pending_encounter: Dictionary = {}

# History entries for the storyteller:
# Word, enemy, tags, damage, requested part of speech, and encounter.
var word_history: Array[Dictionary] = []

# The six-point meter, carried between fights.
var inspiration: int = 0
# Carried punctuation consumables: mark -> count.
var punctuation: Dictionary[String, int] = {}
# The run-long forbidden letter from The Price of Memory, if any.
var forgotten_letter: String = ""
# Accepted vows: {"encounter": int, "rule": Dictionary}.
var vows: Array[Dictionary] = []
# Pilgrimage loans: {"instance_id", "encounter", "upgrade", "returned"}.
var loans: Array[Dictionary] = []
# Encounter stage -> {"types": Array, "events": Array, "slot": int}.
var event_stages: Dictionary[int, Dictionary] = {}

var is_run_active: bool = false


## Starts a party containing each vowel and common consonant once.
func start_new_run() -> void:
	player_max_health = STARTING_HEALTH
	player_health = STARTING_HEALTH
	gold = STARTING_GOLD
	relics = []
	completed_encounters = []
	relic_rewards = {}
	pending_victory_enemy = ""
	pending_victory_gold = 0
	pending_victory_notes = []
	pending_reward_choices = []
	reward_claims = {}
	recruitment_encounter = -1
	recruitment_stock = []
	encounter_index = 1
	next_enemy_id = ""
	selected_biome = ""
	encounter_options_index = -1
	encounter_options = []
	pending_encounter = {}
	word_history = []
	inspiration = 0
	punctuation = {}
	forgotten_letter = ""
	vows = []
	loans = []
	event_stages = {}
	deck = []
	next_letter_id = 1
	var starters: String = (
		LetterStats.VOWELS + LetterStats.COMMON_CONSONANTS
	)
	for letter: String in starters:
		deck.append(create_letter(letter))
	is_run_active = true
	EventBus.emit_deck_changed()
	EventBus.emit_gold_changed(gold)


## A new owned instance with the next stable id. The caller decides
## whether it joins the deck.
func create_letter(
	letter: String, level: int = 1, modifier_ids: Array[String] = []
) -> LetterStats:
	var stats: LetterStats = LetterStats.create(letter)
	stats.level = maxi(level, 1)
	for modifier_id: String in modifier_ids:
		stats.add_modifier(modifier_id)
	stats.instance_id = next_letter_id
	next_letter_id += 1
	return stats


## Gives ids to deck letters created elsewhere, such as by tests.
func ensure_letter_ids() -> void:
	for stats: LetterStats in deck:
		stats.migrate_legacy_modifier()
		if stats.instance_id <= 0:
			stats.instance_id = next_letter_id
			next_letter_id += 1


func find_letter(instance_id: int) -> LetterStats:
	for stats: LetterStats in deck:
		if stats.instance_id == instance_id:
			return stats
	return null


## True when the next encounter is the final boss.
func is_boss_next() -> bool:
	return encounter_index >= ENCOUNTERS_PER_RUN


func advance_encounter() -> void:
	encounter_index += 1


## Returns and clears the confirmed setup for the current encounter;
## empty when none was confirmed for this encounter.
func take_pending_encounter() -> Dictionary:
	var setup: Dictionary = pending_encounter
	pending_encounter = {}
	if int(setup.get("encounter", -1)) != encounter_index:
		return {}
	return setup


## Records a victory once before its reward can be claimed.
func complete_encounter() -> void:
	if not completed_encounters.has(encounter_index):
		completed_encounters.append(encounter_index)


func begin_victory(
	enemy_name: String, gold_earned: int, notes: Array[String] = []
) -> void:
	pending_victory_enemy = enemy_name
	pending_victory_gold = gold_earned
	pending_victory_notes = notes.duplicate()
	pending_reward_choices = []


func clear_pending_victory() -> void:
	pending_victory_enemy = ""
	pending_victory_gold = 0
	pending_victory_notes = []
	pending_reward_choices = []


func add_gold(amount: int) -> void:
	gold += amount
	EventBus.emit_gold_changed(gold)


## Spends gold if affordable; returns whether it was.
func spend_gold(amount: int) -> bool:
	if amount < 0 or amount > gold:
		return false
	gold -= amount
	EventBus.emit_gold_changed(gold)
	return true


func damage_player(amount: int) -> void:
	player_health = maxi(player_health - amount, 0)
	EventBus.emit_player_damaged(float(amount))
	if player_health <= 0:
		is_run_active = false
		EventBus.emit_player_defeated()


func heal_player(amount: int) -> void:
	player_health = mini(
		player_health + amount, player_max_health
	)


## Records a played word for the storyteller and damage history.
func record_word(
	word: String,
	enemy_name: String,
	tags: Array[String],
	damage: float,
	pos: String = ""
) -> void:
	word_history.append({
		"word": word,
		"enemy": enemy_name,
		"tags": tags,
		"damage": damage,
		"pos": pos,
		"encounter": encounter_index,
	})


# --- Inspiration and punctuation -----------------------------------

func add_inspiration(points: int) -> void:
	inspiration = Inspiration.clamp_points(inspiration + points)


## Empties a full meter; false when it was not full.
func spend_inspiration() -> bool:
	if not Inspiration.is_full(inspiration):
		return false
	inspiration = 0
	return true


func punctuation_count(mark: String) -> int:
	return int(punctuation.get(mark, 0))


func add_punctuation(mark: String, count: int = 1) -> void:
	punctuation[mark] = punctuation_count(mark) + count


## Uses one carried mark; false when none is carried.
func consume_punctuation(mark: String) -> bool:
	if punctuation_count(mark) <= 0:
		return false
	punctuation[mark] = punctuation_count(mark) - 1
	return true


# --- Circulation, vows, and loans ----------------------------------

## True when an owned instance sits out of combat: its letter is
## forgotten, or it is away on pilgrimage for this encounter.
func is_out_of_circulation(stats: LetterStats) -> bool:
	if not forgotten_letter.is_empty() \
			and stats.letter == forgotten_letter:
		return true
	for loan: Dictionary in loans:
		if int(loan["instance_id"]) == stats.instance_id \
				and not bool(loan["returned"]) \
				and int(loan["encounter"]) == encounter_index:
			return true
	return false


## Owned instances that enter combat draw piles.
func circulating_deck() -> Array[LetterStats]:
	var letters: Array[LetterStats] = []
	for stats: LetterStats in deck:
		if not is_out_of_circulation(stats):
			letters.append(stats)
	return letters


## Rules that bind the whole current encounter: accepted vows and
## the run-long forgotten letter.
func fixed_combat_rules() -> Array[Dictionary]:
	var rules: Array[Dictionary] = []
	if not forgotten_letter.is_empty():
		rules.append(WordRules.amnesia(forgotten_letter))
	for vow: Dictionary in vows:
		if int(vow["encounter"]) == encounter_index:
			rules.append(Dictionary(vow["rule"]).duplicate(true))
	return rules


## Applies previewed upgrades to instances returning from pilgrimage
## after this encounter's victory. Returns one line per return.
func return_pilgrims() -> Array[String]:
	var lines: Array[String] = []
	for loan: Dictionary in loans:
		if bool(loan["returned"]) \
				or int(loan["encounter"]) != encounter_index:
			continue
		loan["returned"] = true
		var stats: LetterStats = find_letter(int(loan["instance_id"]))
		if stats == null:
			continue
		lines.append("%s returns from pilgrimage: %s." % [
			stats.tag_text(), LetterUpgrade.describe(loan["upgrade"]),
		])
		LetterUpgrade.apply(stats, loan["upgrade"])
	if not lines.is_empty():
		EventBus.emit_deck_changed()
	return lines
