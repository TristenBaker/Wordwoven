extends RichTextLabel
## Presentation uses a detached snapshot and never changes run counters.

func refresh() -> void:
	var stats: Dictionary = PlayerStats.run_snapshot()
	var lines: Array[String] = [
		"[center][color=#ffe2a0][b]Run Statistics[/b][/color][/center]",
		"Word Damage Dealt: %.1f" % float(stats.damage),
		"Damage Received: %.0f" % float(stats.received),
		"Enemies Defeated: %d" % int(stats.kills),
		"Combat Encounters Completed: %d" % int(stats.encounters),
		"Accepted Combat Words: %d" % int(stats.words),
		"Highest Word Damage: %.1f" % float(stats.highest_damage),
	]
	if not String(stats.best_word).is_empty():
		lines.append("Mightiest Word: %s" % String(stats.best_word).to_upper())
	lines.append("Most Used Letter: %s" % stats.most_used_letter)
	lines.append("\n[color=#ffe2a0][b]Word Categories[/b][/color]")
	lines.append("Nouns: %d    Verbs: %d    Adjectives: %d    Adverbs: %d" % [
		int(stats.n), int(stats.v), int(stats.a), int(stats.r),
	])
	lines.append("\n[color=#ffe2a0][b]Letter Frequencies[/b][/color]")
	var group: Array[String] = []
	for letter: String in PlayerStats.ALPHABET:
		group.append("%s: %d" % [letter.to_upper(), stats.letters[letter]])
		if group.size() == 6:
			lines.append("    ".join(group))
			group.clear()
	if not group.is_empty():
		lines.append("    ".join(group))
	lines.append("\nDamage Received includes lethal incoming damage.")
	if stats.debug_assisted:
		lines.append("Developer-assisted run: achievement progress excluded.")
	text = "\n".join(lines)
