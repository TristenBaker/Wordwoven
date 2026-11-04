extends RefCounted
## Deterministic lookup only. Unsupported words never select a fate.
const VOCABULARY: Script = preload("uid://dlxn4nft028ba")
const MODIFIERS: Script = preload("uid://dubtvvoj1ve87")


static func classify(adjective: String) -> Dictionary:
	var word: String = adjective.strip_edges().to_lower()
	if not WordNet.is_ready:
		return {"modifier_id": "", "status": "loading"}
	if not WordNet.parts_of_speech(word).has("a"):
		return {"modifier_id": "", "status": "invalid"}
	for id: String in VOCABULARY.WORDS:
		if not VOCABULARY.WORDS[id].has(word):
			continue
		var modifier: Dictionary = MODIFIERS.definition(id)
		if not MODIFIERS.eligible(modifier, RunState.selected_biome):
			return {
				"modifier_id": "", "status": "restricted",
				"biome": modifier.biome, "name": modifier.name,
			}
		return {"modifier_id": id, "status": "supported"}
	return {"modifier_id": "", "status": "unsupported"}


static func select_modifier(adjective: String) -> Dictionary:
	var result: Dictionary = classify(adjective)
	return MODIFIERS.definition(result.modifier_id)
