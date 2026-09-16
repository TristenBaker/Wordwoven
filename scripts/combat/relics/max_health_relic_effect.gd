class_name MaxHealthRelicEffect
extends StatBonusRelicEffect
## Raises maximum health and heals the same amount when granted.


func _init() -> void:
	super("max_health")


func on_granted(params: Dictionary) -> void:
	var amount: int = int(params.get("amount", 0))
	RunState.player_max_health += amount
	RunState.heal_player(amount)
