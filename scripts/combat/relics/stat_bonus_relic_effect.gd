class_name StatBonusRelicEffect
extends RelicEffect
## Adds its amount to one passive stat that other systems total,
## such as victory gold, hand size, or the damage multiplier.

var stat_name: String = ""


func _init(new_stat_name: String) -> void:
	stat_name = new_stat_name


func stat_bonus(stat: String, params: Dictionary) -> float:
	if stat != stat_name:
		return 0.0
	return float(params.get("amount", 0.0))
