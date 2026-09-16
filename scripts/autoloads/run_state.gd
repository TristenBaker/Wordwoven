extends Node
## Holds the state of the current roguelike run: player health,
## gold, the letter deck, relics, progress, and the word history
## that the tavern storyteller retells. Survives scene changes;
## contains no combat or UI logic.

const STARTING_HEALTH: int = 50
const STARTING_GOLD: int = 0
const ENCOUNTERS_PER_RUN: int = 6

var player_max_health: int = STARTING_HEALTH
var player_health: int = STARTING_HEALTH
var gold: int = STARTING_GOLD

# The letter characters the player owns.
var deck: Array[LetterStats] = []

# Relic identifiers, resolved by the relic system.
var relics: Array[String] = []

# Completed fights and their chosen relics prevent repeated rewards.
var completed_encounters: Array[int] = []
var relic_rewards: Dictionary[int, String] = {}

# Transient post-fight presentation data. These values carry a completed
# encounter through the bard, power, and loot screens before the run advances.
var pending_victory_enemy: String = ""
var pending_victory_gold: int = 0
var pending_relic_choices: Array[String] = []

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
	pending_relic_choices = []
	recruitment_encounter = -1
	recruitment_stock = []
	encounter_index = 1
	next_enemy_id = ""
	selected_biome = ""
	encounter_options_index = -1
	encounter_options = []
	pending_encounter = {}
	word_history = []
	deck = []
	var starters: String = (
		LetterStats.VOWELS + LetterStats.COMMON_CONSONANTS
	)
	for letter: String in starters:
		deck.append(LetterStats.create(letter))
	is_run_active = true
	EventBus.emit_deck_changed()
	EventBus.emit_gold_changed(gold)


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


## Records a victory once before its relic can be claimed.
func complete_encounter() -> void:
	if not completed_encounters.has(encounter_index):
		completed_encounters.append(encounter_index)


func begin_victory(enemy_name: String, gold_earned: int) -> void:
	pending_victory_enemy = enemy_name
	pending_victory_gold = gold_earned
	pending_relic_choices = []


func clear_pending_victory() -> void:
	pending_victory_enemy = ""
	pending_victory_gold = 0
	pending_relic_choices = []


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
