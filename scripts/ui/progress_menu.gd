class_name ProgressMenu
extends Control
## Shared read-only overlay. Its host owns Escape and pause state.
signal closed

enum Content { ACHIEVEMENTS, HISTORY }
@export var content: Content = Content.ACHIEVEMENTS

@onready var title: Label = $Panel/Content/Title
@onready var entries: RichTextLabel = $Panel/Content/Scroll/Entries
@onready var close_button: Button = $Panel/Content/CloseButton


func _ready() -> void:
	close_button.pressed.connect(close)
	PlayerStats.achievements_changed.connect(_refresh_if_visible)
	hide()


func open() -> void:
	_refresh()
	show()
	close_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _refresh_if_visible() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	var lines: Array[String] = []
	if content == Content.HISTORY:
		title.text = "Combat Word History"
		var history: Array[Dictionary] = PlayerStats.encounter_history()
		for index: int in history.size():
			var entry: Dictionary = history[index]
			lines.append("[color=#ffe2a0][b]%d. %s[/b][/color]" % [
				index + 1, String(entry.word).to_upper(),
			])
			lines.append("%.1f damage  •  %s\n%s" % [
				float(entry.damage), WordNet.pos_name(String(entry.pos)),
				entry.get("effectiveness_label", "Unavailable"),
			])
		if history.is_empty():
			lines.append("No words submitted during this encounter yet.")
	else:
		title.text = "Achievements"
		for row: Dictionary in PlayerStats.achievement_snapshot():
			var status: String = "Unlocked" if row.unlocked else "Locked"
			lines.append("[color=#ffe2a0][b]%s — %s[/b][/color]" % [
				row.name, status,
			])
			var detail: String = String(row.description)
			if not row.unlocked:
				detail += "  (%.0f / %d)" % [row.progress, int(row.goal)]
			lines.append(detail)
	entries.text = "\n\n".join(lines)
	$Panel/Content/Scroll.scroll_vertical = 0
