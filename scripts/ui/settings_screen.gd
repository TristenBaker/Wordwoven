class_name SettingsScreen
extends Control
## Reusable settings screen. Hosts decide what sits behind it (title screen
## or a paused encounter), while settings content lives in one place.

signal closed

@onready var back_button: Button = $Center/Panel/Settings/BackButton


func _ready() -> void:
	back_button.pressed.connect(close)
	hide()


func open() -> void:
	show()
	back_button.call_deferred("grab_focus")


func close() -> void:
	hide()
	closed.emit()
