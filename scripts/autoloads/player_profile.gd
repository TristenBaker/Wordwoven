extends Node
## Persistent player progression, intentionally separate from one-run state.

signal star_coins_changed(total: int)

const PROFILE_PATH := "user://player_profile.cfg"
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
var seen_words: Dictionary = {}
var element_upgrade_levels: Dictionary = {}
var letter_cosmetics: Dictionary = {}


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	star_coins = 0
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
	var saved_cosmetics: Dictionary = config.get_value("profile", "letter_cosmetics", {})
	for letter: String in saved_cosmetics:
		var cosmetic: String = saved_cosmetics[letter]
		if COSMETICS.has(cosmetic):
			letter_cosmetics[letter.to_lower()] = cosmetic


func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "star_coins", star_coins)
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
	star_coins += 1
	save_profile()
	star_coins_changed.emit(star_coins)
	return true


func potency_level(element: String) -> int:
	return int(element_upgrade_levels.get(element.to_lower(), 0))


func element_potency_multiplier(element: String) -> float:
	# A deliberately modest permanent gain: +3% per rank.
	return 1.0 + float(potency_level(element)) * 0.03


func upgrade_cost(element: String) -> int:
	return 1


func buy_element_upgrade(element: String) -> bool:
	var key := element.to_lower()
	if not ELEMENTS.has(key):
		return false
	var cost := upgrade_cost(key)
	if star_coins < cost:
		return false
	star_coins -= cost
	element_upgrade_levels[key] = potency_level(key) + 1
	save_profile()
	star_coins_changed.emit(star_coins)
	return true


func refund_element_upgrade(element: String) -> bool:
	var key := element.to_lower()
	if not ELEMENTS.has(key) or potency_level(key) <= 0:
		return false
	element_upgrade_levels[key] = potency_level(key) - 1
	star_coins += 1
	save_profile()
	star_coins_changed.emit(star_coins)
	return true


func add_dev_star_coin() -> void:
	star_coins += 1
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
