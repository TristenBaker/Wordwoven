class_name WordEffectivenessFormat
extends RefCounted
## One presentation rule for previews, resolved feedback and stored history.

static func classification(result: Dictionary) -> String:
	var counter: Dictionary = result.get("counter", {})
	var multiplier: float = float(result.get("semantic_multiplier", 0.0))
	var effective: bool = (
		counter.get("strategy", "none") in [
			"wordnet antonym", "thematic counter", "counter synonym",
		]
		and float(counter.get("score", 0.0)) > 0.0
		and not String(counter.get("tag", "")).is_empty()
		and multiplier > 1.0
	)
	if not effective:
		return "THE WORD FINDS NO WEAKNESS"
	return "SUPER EFFECTIVE!" if multiplier >= 2.0 else "EFFECTIVE!"
