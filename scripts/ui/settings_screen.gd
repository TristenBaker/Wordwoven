class_name SettingsScreen
extends Control
## Shared by the main menu and pause menu; edits are staged until Apply.
signal closed
@onready var mode_option: OptionButton = %DisplayMode
@onready var resolution_option: OptionButton = %Resolution
@onready var master: HSlider = %MasterVolume
@onready var music: HSlider = %MusicVolume
@onready var sfx: HSlider = %SfxVolume
@onready var status: Label = %Status
@onready var back_button: Button = %BackButton
var _resolutions: Array[Vector2i] = []

func _ready() -> void:
	back_button.pressed.connect(close)
	%ApplyButton.pressed.connect(_apply)
	mode_option.item_selected.connect(func(_index: int): _refresh_display_hint())
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

func _apply() -> void:
	var error: Error = AppSettings.save_and_apply({
		"display_mode": mode_option.selected,
		"resolution": _resolutions[resolution_option.selected],
		"master_volume": master.value, "music_volume": music.value, "sfx_volume": sfx.value,
	})
	status.text = "Settings applied and saved." if error == OK else "Could not save settings. Please try again."
	status.modulate = Color("ead69b") if error == OK else Color("dda59a")

func close() -> void:
	hide()
	closed.emit()
