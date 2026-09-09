extends Node
## Global signal hub. Systems that should stay decoupled communicate
## through these signals instead of holding references to each other.
## Emitters call the emit_* helpers; listeners connect in _ready.

# Combat flow
signal encounter_started(enemy_data: Dictionary)
signal word_submitted(text: String)
signal word_rejected(text: String, reason: String)
signal word_resolved(result: Dictionary)
signal enemy_damaged(amount: float)
signal enemy_defeated()
signal player_damaged(amount: float)
signal player_defeated()
signal encounter_won(gold_earned: int)

# Hand and deck
signal hand_drawn(letters: Array[LetterStats])
signal deck_changed()

# Economy and progression
signal gold_changed(new_total: int)
signal relic_gained(relic_id: String)

# Debug
signal debug_toggled(enabled: bool)


func emit_encounter_started(enemy_data: Dictionary) -> void:
	encounter_started.emit(enemy_data)


func emit_word_submitted(text: String) -> void:
	word_submitted.emit(text)


func emit_word_rejected(text: String, reason: String) -> void:
	word_rejected.emit(text, reason)


func emit_word_resolved(result: Dictionary) -> void:
	word_resolved.emit(result)


func emit_enemy_damaged(amount: float) -> void:
	enemy_damaged.emit(amount)


func emit_enemy_defeated() -> void:
	enemy_defeated.emit()


func emit_player_damaged(amount: float) -> void:
	player_damaged.emit(amount)


func emit_player_defeated() -> void:
	player_defeated.emit()


func emit_encounter_won(gold_earned: int) -> void:
	encounter_won.emit(gold_earned)


func emit_hand_drawn(letters: Array[LetterStats]) -> void:
	hand_drawn.emit(letters)


func emit_deck_changed() -> void:
	deck_changed.emit()


func emit_gold_changed(new_total: int) -> void:
	gold_changed.emit(new_total)


func emit_relic_gained(relic_id: String) -> void:
	relic_gained.emit(relic_id)


func emit_debug_toggled(enabled: bool) -> void:
	debug_toggled.emit(enabled)
