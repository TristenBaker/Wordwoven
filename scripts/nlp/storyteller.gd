class_name Storyteller
extends RefCounted
## The tavern bard. Reads the run's word history and retells the
## journey, weaving in the exact words the player and the enemies
## used, with WordNet synonyms for color.

const OPENINGS: Array[String] = [
	"Gather close, friends, and hear how the tale unfolds.",
	"The bard strums once, and the room falls quiet.",
	"Another chapter, scrawled in ink and bruises.",
]

const CLOSINGS_STRONG: Array[String] = [
	"And so our hero drinks tonight, hale and unbowed.",
	"The road ahead darkens, but the pen is still sharp.",
]

const CLOSINGS_WEAK: Array[String] = [
	"Our hero nurses deep wounds. May the next word "
			+ "strike truer.",
	"Battered, bleeding, but not yet out of syllables.",
]

# Verbs describing a strike, indexed by how hard it landed.
const WEAK_STRIKES: Array[String] = [
	"grazed", "nicked", "prodded",
]
const STRONG_STRIKES: Array[String] = [
	"cleaved", "shattered", "silenced", "unmade",
]

# Damage at or above this counts as a mighty blow in the telling.
const STRONG_DAMAGE: float = 25.0

const MAD_LIB_SENTENCES: Dictionary = {
	"n": [
		"The hero summoned %s against the %s.",
		"With %s in hand, the hero faced the %s.",
		"The word %s became a bright weapon against the %s.",
		"A vision of %s guided the hero toward the %s.",
	],
	"v": [
		"The hero shouted \"%s!\" and struck the %s.",
		"The hero dared to \"%s\" before the %s.",
		"At the crucial moment, the hero commanded \"%s!\" against the %s.",
		"The hero chose to \"%s\", forcing the %s to retreat.",
	],
	"a": [
		"Their %s magic battered the %s.",
		"A %s spell flashed across the %s.",
		"The %s strike left the %s reeling.",
		"The hero's %s answer turned the %s's strength against it.",
	],
	"r": [
		"The hero moved %s and broke the %s's guard.",
		"%s, the hero slipped past the %s's claws.",
		"The hero struck %s, leaving the %s bewildered.",
		"%s, the final blow found the %s's weak point.",
	],
}


## Builds the tale of the run so far from RunState's history.
func generate() -> String:
	if RunState.word_history.is_empty():
		return "The bard clears his throat, but the tale has " \
				+ "not yet begun."
	var paragraphs: Array[String] = []
	paragraphs.append(OPENINGS.pick_random())
	for chapter: Dictionary in _chapters():
		paragraphs.append(_tell_chapter(chapter))
	paragraphs.append(_closing())
	return "\n\n".join(paragraphs)


## Builds a stable Mad Libs paragraph for one completed encounter.
func generate_for_encounter(encounter: int) -> String:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in RunState.word_history:
		if entry.get("encounter", encounter) == encounter:
			entries.append(entry)
	if entries.is_empty():
		return "The monster fell, but the tale has no words to remember."
	var foe: String = entries[0]["enemy"]
	var lines: Array[String] = []
	var grouped: Dictionary = {}
	for entry: Dictionary in entries:
		var pos: String = entry.get("pos", "n")
		if not grouped.has(pos):
			grouped[pos] = []
		grouped[pos].append(entry["word"])
	for pos: String in ["n", "v", "a", "r"]:
		if not grouped.has(pos):
			continue
		var words: Array = grouped[pos]
		var joined: String = ", ".join(words)
		var variants: Array = MAD_LIB_SENTENCES[pos]
		var variant_index: int = (encounter + pos.unicode_at(0)) \
				% variants.size()
		var sentence: String = variants[variant_index]
		lines.append(sentence % [joined, foe])
	lines.append("At last, the hero slew the %s and claimed the victory." % foe)
	return " ".join(lines)


# Groups consecutive history entries fought against one enemy.
# Each chapter: {"enemy": String, "tags": Array, "entries": Array}.
func _chapters() -> Array[Dictionary]:
	var chapters: Array[Dictionary] = []
	for entry: Dictionary in RunState.word_history:
		var enemy_name: String = entry["enemy"]
		if chapters.is_empty() \
				or chapters[-1]["enemy"] != enemy_name:
			chapters.append({
				"enemy": enemy_name,
				"tags": entry["tags"],
				"entries": [],
			})
		chapters[-1]["entries"].append(entry)
	return chapters


func _tell_chapter(chapter: Dictionary) -> String:
	var best: Dictionary = chapter["entries"][0]
	for entry: Dictionary in chapter["entries"]:
		if entry["damage"] > best["damage"]:
			best = entry
	var tags: Array = chapter["tags"]
	var foe: String = chapter["enemy"]
	if not tags.is_empty():
		foe = "%s, %s thing that it was" % [
			foe, " and ".join(tags)
		]
	var word: String = best["word"]
	var strike: String = WEAK_STRIKES.pick_random()
	if best["damage"] >= STRONG_DAMAGE:
		strike = STRONG_STRIKES.pick_random()
	var line: String = "Against the %s, the word " % foe \
			+ "[b]%s[/b] %s the foe" % [
				word.to_upper(), strike
			]
	var kin: Array[String] = WordNet.synonyms_of(word, 2)
	if not kin.is_empty():
		line += " — a word kin to '%s'" % kin[0]
	line += "."
	var count: int = chapter["entries"].size()
	if count > 1:
		line += " %d words were spent in that quarrel." % count
	return line


func _closing() -> String:
	var healthy: bool = RunState.player_health * 2 \
			>= RunState.player_max_health
	if healthy:
		return CLOSINGS_STRONG.pick_random()
	return CLOSINGS_WEAK.pick_random()
