extends Node
## Holds the state of the current roguelike run: player health,
## gold, the letter deck, relics, progress, and the word history
## that the tavern storyteller retells. Survives scene changes;
## contains no combat or UI logic.

const STARTING_HEALTH: int = 50
const STARTING_GOLD: int = 0
const ENCOUNTERS_PER_RUN: int = 6

# Set false to return to the original shared-deck and use-level system.
var use_itemized_letters: bool = true

var player_max_health: int = STARTING_HEALTH
var player_health: int = STARTING_HEALTH
var gold: int = STARTING_GOLD

# The letter characters the player owns.
var deck: Array[LetterStats] = []

# ARPG letter mode: acquired items are separate from the 26 matching letter
# slots. A slot holds at most one item whose character matches that slot.
var letter_inventory: Array[LetterStats] = []
var equipped_letters: Dictionary[String, LetterStats] = {}

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
var pending_victory_letter: LetterStats = null

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

# History entries for the storyteller:
# Word, enemy, tags, damage, requested part of speech, and encounter.
var word_history: Array[Dictionary] = []

var is_run_active: bool = false


## Starts either the legacy shared deck or ten randomly equipped ARPG letters.
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
	pending_victory_letter = null
	recruitment_encounter = -1
	recruitment_stock = []
	encounter_index = 1
	next_enemy_id = ""
	selected_biome = ""
	word_history = []
	deck = []
	letter_inventory = []
	equipped_letters = {}
	if use_itemized_letters:
		_setup_itemized_starters()
	else:
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


## Records a victory once before its relic can be claimed.
func complete_encounter() -> void:
	if not completed_encounters.has(encounter_index):
		completed_encounters.append(encounter_index)


func begin_victory(enemy_name: String, gold_earned: int) -> void:
	pending_victory_enemy = enemy_name
	pending_victory_gold = gold_earned
	pending_relic_choices = []
	pending_victory_letter = null


func begin_victory_with_drop(
	enemy_name: String, gold_earned: int, dropped_letter: LetterStats
) -> void:
	begin_victory(enemy_name, gold_earned)
	pending_victory_letter = dropped_letter


func clear_pending_victory() -> void:
	pending_victory_enemy = ""
	pending_victory_gold = 0
	pending_relic_choices = []
	pending_victory_letter = null


func combat_letters() -> Array[LetterStats]:
	if not use_itemized_letters:
		return deck
	var letters: Array[LetterStats] = []
	for stats: LetterStats in equipped_letters.values():
		letters.append(stats)
	return letters


func add_letter_item(item: LetterStats) -> void:
	if item == null:
		return
	letter_inventory.append(item)
	EventBus.emit_deck_changed()


func equip_letter_item(item: LetterStats) -> bool:
	if item == null or not letter_inventory.has(item):
		return false
	var slot := item.letter.to_lower()
	var previous: LetterStats = equipped_letters.get(slot, null)
	letter_inventory.erase(item)
	if previous != null:
		letter_inventory.append(previous)
	equipped_letters[slot] = item
	EventBus.emit_deck_changed()
	return true


func unequip_letter(slot: String) -> bool:
	var normalized := slot.to_lower()
	var item: LetterStats = equipped_letters.get(normalized, null)
	if item == null:
		return false
	equipped_letters.erase(normalized)
	letter_inventory.append(item)
	EventBus.emit_deck_changed()
	return true


func rolled_letter_drop() -> LetterStats:
	var letters: Array[String] = []
	for letter: String in LetterStats.BASE_POWER:
		letters.append(letter)
	var letter: String = letters.pick_random()
	var classes: Array[int] = [
		LetterStats.LetterClass.HEALER,
		LetterStats.LetterClass.WARRIOR,
		LetterStats.LetterClass.ROGUE,
	]
	var item_class: int = classes.pick_random()
	var maximum_level := mini(5, 1 + encounter_index)
	var item_level := randi_range(1, maximum_level)
	return LetterStats.create_item(letter, item_class, item_level)


func _setup_itemized_starters() -> void:
	var letters: Array[String] = []
	for letter: String in LetterStats.BASE_POWER:
		letters.append(letter)
	letters.shuffle()
	for index: int in range(10):
		var letter: String = letters[index]
		var classes: Array[int] = [
			LetterStats.LetterClass.HEALER,
			LetterStats.LetterClass.WARRIOR,
			LetterStats.LetterClass.ROGUE,
		]
		var item_class: int = classes.pick_random()
		equipped_letters[letter] = LetterStats.create_item(letter, item_class, 1)


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
