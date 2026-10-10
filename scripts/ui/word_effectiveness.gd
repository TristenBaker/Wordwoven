extends PanelContainer
## Displays the calculator's existing counter result; never calculates damage.

const GOLD := Color("ffe2a0")
const MUTED := Color("aaa995")
var _fade: Tween
var _showing_result: bool = false
@onready var label: Label = $Label


func _ready() -> void:
	clear()


func _exit_tree() -> void:
	_stop_fade()


func clear(preserve_result: bool = false) -> void:
	if preserve_result and _showing_result:
		return
	_stop_fade()
	_showing_result = false
	label.text = ""
	modulate.a = 0.0


func show_preview(result: Dictionary) -> void:
	_stop_fade()
	_showing_result = false
	_display(result)


func show_result(result: Dictionary) -> void:
	_stop_fade()
	_showing_result = true
	_display(result)
	_fade = create_tween()
	_fade.tween_interval(1.5)
	_fade.tween_property(self, "modulate:a", 0.0, 0.3)
	_fade.tween_callback(_clear_result)


func _clear_result() -> void:
	_showing_result = false
	label.text = ""
	_fade = null


func _display(result: Dictionary) -> void:
	var counter: Dictionary = result.get("counter", {})
	var multiplier: float = float(result.get("semantic_multiplier", 0.0))
	# Preserve the original combat feedback qualification and thresholds.
	var effective: bool = counter.get("strategy", "none") in [
		"wordnet antonym", "thematic counter", "counter synonym",
	] and float(counter.get("score", 0.0)) > 0.0 and not String(counter.get("tag", "")).is_empty() and multiplier > 1.0
	label.text = ("SUPER EFFECTIVE!" if multiplier >= 2.0 else "EFFECTIVE!") if effective else "THE WORD FINDS NO WEAKNESS"
	label.add_theme_color_override("font_color", GOLD if effective else MUTED)
	tooltip_text = "Effectiveness %.2f • Semantic multiplier ×%.2f" % [float(result.get("effectiveness", 0.0)), multiplier]
	modulate.a = 1.0


func _stop_fade() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null
