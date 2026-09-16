class_name RelicEffect
extends RefCounted
## Base behavior for one relic effect type. Each owned copy of a
## relic applies its effects again, so copies stack naturally.


## Contribution of one effect entry to a named passive stat.
func stat_bonus(_stat: String, _params: Dictionary) -> float:
	return 0.0


## One-time consequence applied when the relic is granted.
func on_granted(_params: Dictionary) -> void:
	pass


## Problems with an entry's parameters; empty when valid.
func validate(params: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var amount: Variant = params.get("amount")
	if typeof(amount) != TYPE_INT and typeof(amount) != TYPE_FLOAT:
		problems.append("amount must be a number")
	return problems
