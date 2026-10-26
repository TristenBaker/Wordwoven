class_name SettingsScreen
extends Control
## Shared by the main menu and pause menu; edits are staged until Apply.
signal closed
@onready var mode_option: OptionButton = %DisplayMode
@onready var resolution_option: OptionButton = %Resolution
@onready var master: HSlider = %MasterVolume
@onready var music: HSlider = %MusicVolume
@onready var sfx: HSlider = %SfxVolume
@onready var auto_equip_toggle: CheckButton = %AutoEquipToggle
@onready var same_element_toggle: CheckButton = %SameElementToggle
@onready var status: Label = %Status
@onready var back_button: Button = %BackButton
var _resolutions: Array[Vector2i] = []

func _ready() -> void:
	back_button.pressed.connect(close)
	%ApplyButton.pressed.connect(_apply)
	mode_option.item_selected.connect(func(_index: int): _refresh_display_hint())
	auto_equip_toggle.toggled.connect(_on_auto_equip_toggled)
	for pair: Array in [[master, %MasterPercent], [music, %MusicPercent], [sfx, %SfxPercent]]:
		pair[0].value_changed.connect(func(value: float): pair[1].text = "%d%%" % int(round(value)))
	hide()

func open() -> void:
	_resolutions = AppSettings.supported_resolutions()
	var saved: Dictionary = AppSettings.preferences
	# Keep an existing preference selectable after moving to a smaller monitor.
	if not _resolutions.has(saved.resolution):
		_resolutions.append(saved.resolution)
	resolution_option.clear()
	for resolution: Vector2i in _resolutions:
		resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
	resolution_option.select(_resolutions.find(saved.resolution))
	mode_option.select(saved.display_mode)
	master.value = saved.master_volume
	music.value = saved.music_volume
	sfx.value = saved.sfx_volume
	auto_equip_toggle.button_pressed = bool(saved.get("auto_equip_enabled", false))
	same_element_toggle.button_pressed = bool(saved.get("auto_equip_same_element_only", false))
	same_element_toggle.disabled = not auto_equip_toggle.button_pressed
	%MasterPercent.text = "%d%%" % int(round(master.value))
	%MusicPercent.text = "%d%%" % int(round(music.value))
	%SfxPercent.text = "%d%%" % int(round(sfx.value))
	status.text = ""
	_refresh_display_hint()
	show()
	mode_option.call_deferred("grab_focus")

func _refresh_display_hint() -> void:
	# Fullscreen and borderless use the monitor's native size, avoiding distortion.
	resolution_option.disabled = mode_option.selected != 2
	%DisplayHint.text = "Resolution applies to Windowed mode; other modes fill the display."


func _on_auto_equip_toggled(enabled: bool) -> void:
	same_element_toggle.disabled = not enabled

func _apply() -> void:
	var error: Error = AppSettings.save_and_apply({
		"display_mode": mode_option.selected,
		"resolution": _resolutions[resolution_option.selected],
		"master_volume": master.value, "music_volume": music.value, "sfx_volume": sfx.value,
		"auto_equip_enabled": auto_equip_toggle.button_pressed,
		"auto_equip_same_element_only": same_element_toggle.button_pressed,
	})
	RunState.set_auto_equip(auto_equip_toggle.button_pressed, same_element_toggle.button_pressed)
	status.text = "Settings applied and saved." if error == OK else "Could not save settings. Please try again."
	status.modulate = Color("ead69b") if error == OK else Color("dda59a")

func close() -> void:
	hide()
	closed.emit()
