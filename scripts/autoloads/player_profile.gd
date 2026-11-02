extends Node
## Persistent player progression, intentionally separate from one-run state.

signal star_coins_changed(total: int)

const PROFILE_PATH := "user://player_profile.cfg"
const TALENTS := preload("res://data/balance/talents.gd")
const ELEMENTS: Array[String] = ["fire", "lightning", "water", "ice", "nature", "earth"]
const COSMETICS: Dictionary[String, String] = {
	"warrior": "Warrior",
	"healer": "Healer",
	"rogue": "Rogue",
	"mage": "Mage",
}
const WARRIOR: Texture2D = preload("res://art/party/portraits/warrior_1.png")
const HEALER: Texture2D = preload("res://art/party/portraits/healer_1.png")
const ROGUE: Texture2D = preload("res://art/party/portraits/rogue_1.png")
const MAGE: Texture2D = preload("res://art/party/portraits/mage_1.png")
const WARRIOR_COSMETIC: CharacterCosmetic = preload("res://art/party/cosmetics/warrior_default.tres")
const HEALER_COSMETIC: CharacterCosmetic = preload("res://art/party/cosmetics/healer_default.tres")
const ROGUE_COSMETIC: CharacterCosmetic = preload("res://art/party/cosmetics/rogue_default.tres")
const MAGE_COSMETIC: CharacterCosmetic = preload("res://art/party/cosmetics/mage_default.tres")
const COSMETIC_RESOURCES: Dictionary[String, CharacterCosmetic] = {
	"warrior": WARRIOR_COSMETIC,
	"healer": HEALER_COSMETIC,
	"rogue": ROGUE_COSMETIC,
	"mage": MAGE_COSMETIC,
}

var star_coins := 0
var total_star_coins := 0
var talent_allocations: Dictionary = {}
var seen_words: Dictionary = {}
var element_upgrade_levels: Dictionary = {}
var letter_cosmetics: Dictionary = {}


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	star_coins = 0
	total_star_coins = 0
	talent_allocations.clear()
	seen_words.clear()
	element_upgrade_levels.clear()
	letter_cosmetics.clear()
	for element: String in ELEMENTS:
		element_upgrade_levels[element] = 0
	var config := ConfigFile.new()
	if config.load(PROFILE_PATH) != OK:
		return
	star_coins = maxi(0, int(config.get_value("profile", "star_coins", 0)))
	for word: String in config.get_value("profile", "seen_words", []):
		seen_words[word.to_lower()] = true
	var saved_levels: Dictionary = config.get_value("profile", "element_upgrade_levels", {})
	for element: String in ELEMENTS:
		element_upgrade_levels[element] = maxi(0, int(saved_levels.get(element, 0)))
	# Old ranks cost one coin each. Refund every rank when migrating to talents.
	var legacy_spent := 0
	for value: int in element_upgrade_levels.values():
		legacy_spent += value
	total_star_coins = maxi(0, int(config.get_value("profile", "total_star_coins", star_coins + legacy_spent)))
	var saved_talents: Dictionary = config.get_value("profile", "talent_allocations", {})
	# Catalog order is parent-first; reject orphaned or unaffordable saved nodes.
	for id: String in TALENTS.NODES:
		if saved_talents.has(id) and allocated_talent_points() < total_star_coins and _talent_parents_owned(id):
			var rank := maxi(0, int(saved_talents[id]))
			if not TALENTS.NODES[id].get("repeatable", false):
				rank = mini(rank, 1)
			rank = mini(rank, total_star_coins - allocated_talent_points())
			if rank > 0:
				talent_allocations[id] = rank
	star_coins = total_star_coins - allocated_talent_points()
	for element: String in ELEMENTS:
		element_upgrade_levels[element] = 0
	var saved_cosmetics: Dictionary = config.get_value("profile", "letter_cosmetics", {})
	for letter: String in saved_cosmetics:
		var cosmetic: String = saved_cosmetics[letter]
		if COSMETICS.has(cosmetic):
			letter_cosmetics[letter.to_lower()] = cosmetic


func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "star_coins", star_coins)
	config.set_value("profile", "total_star_coins", total_star_coins)
	config.set_value("profile", "talent_allocations", talent_allocations)
	config.set_value("profile", "seen_words", seen_words.keys())
	config.set_value("profile", "element_upgrade_levels", element_upgrade_levels)
	config.set_value("profile", "letter_cosmetics", letter_cosmetics)
	config.save(PROFILE_PATH)


## Returns true only for a word that has never rewarded a StarCoin before.
func record_unique_word(word: String) -> bool:
	var normalized := word.strip_edges().to_lower()
	if normalized.is_empty() or seen_words.has(normalized):
		return false
	seen_words[normalized] = true
	total_star_coins += 1
	star_coins += 1
	save_profile()
	star_coins_changed.emit(star_coins)
	return true


func element_potency_multiplier(element: String) -> float:
	# Talent potency joins acquired powers through RelicSystem.total_effect.
	return 1.0


func add_dev_star_coin() -> void:
	total_star_coins += 1
	star_coins += 1
	save_profile()
	star_coins_changed.emit(star_coins)


func talent_effect(effect: String) -> float:
	var amount := 0.0
	for id: String in talent_allocations:
		amount += float(TALENTS.NODES.get(id, {}).get("effects", {}).get(effect, 0.0)) * talent_rank(id)
	return amount


func talent_rank(id: String) -> int:
	return int(talent_allocations.get(id, 0))


func allocated_talent_points() -> int:
	var total := 0
	for id: String in talent_allocations:
		total += talent_rank(id)
	return total


func _talent_parents_owned(id: String) -> bool:
	for parent: String in TALENTS.NODES[id].requires:
		if not talent_allocations.has(parent):
			return false
	return true


func can_allocate_talent(id: String) -> bool:
	return TALENTS.NODES.has(id) and (not talent_allocations.has(id) or TALENTS.NODES[id].get("repeatable", false)) and star_coins > 0 and _talent_parents_owned(id)


func allocate_talent(id: String) -> bool:
	if not can_allocate_talent(id):
		return false
	talent_allocations[id] = talent_rank(id) + 1
	_commit_talents()
	return true


func refund_talent(id: String) -> void:
	if talent_rank(id) > 1:
		talent_allocations[id] = talent_rank(id) - 1
	else:
		talent_allocations.erase(id)
	# Removing a prerequisite refunds its descendants as well.
	var changed := true
	while changed:
		changed = false
		for owned: String in talent_allocations.keys():
			if not _talent_parents_owned(owned):
				talent_allocations.erase(owned)
				changed = true
	_commit_talents()


func reset_talents() -> void:
	talent_allocations.clear()
	_commit_talents()


func _commit_talents() -> void:
	star_coins = total_star_coins - allocated_talent_points()
	save_profile()
	star_coins_changed.emit(star_coins)


func cosmetic_for_letter(letter: String) -> String:
	return String(letter_cosmetics.get(letter.to_lower(), ""))


func set_letter_cosmetic(letter: String, cosmetic: String) -> void:
	if not COSMETICS.has(cosmetic):
		return
	letter_cosmetics[letter.to_lower()] = cosmetic
	save_profile()


func clear_letter_cosmetic(letter: String) -> void:
	letter_cosmetics.erase(letter.to_lower())
	save_profile()


func cosmetic_texture(letter: String, fallback: Texture2D = null) -> Texture2D:
	var cosmetic := cosmetic_resource(cosmetic_for_letter(letter))
	if cosmetic != null and cosmetic.portrait != null:
		return cosmetic.portrait
	return fallback


func cosmetic_resource(cosmetic_id: String) -> CharacterCosmetic:
	return COSMETIC_RESOURCES.get(cosmetic_id, null)


func default_combat_cosmetic(element: int) -> CharacterCosmetic:
	match element:
		LetterStats.Element.FIRE, LetterStats.Element.EARTH:
			return WARRIOR_COSMETIC
		LetterStats.Element.LIGHTNING, LetterStats.Element.ICE:
			return ROGUE_COSMETIC
	return HEALER_COSMETIC


func combat_cosmetic_for(stats: LetterStats) -> CharacterCosmetic:
	var fallback := default_combat_cosmetic(stats.element)
	var selected := cosmetic_resource(cosmetic_for_letter(stats.letter))
	if selected != null:
		return selected
	return fallback


func cosmetic_works_in_combat(letter: String, cosmetic_id: String) -> bool:
	return cosmetic_id.is_empty() or cosmetic_resource(cosmetic_id) != null
