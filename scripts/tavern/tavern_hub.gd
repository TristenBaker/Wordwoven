extends Control
## The atmospheric tavern hub. The existing management screen remains the
## Tavern Page, opened from here by the room interaction or the B shortcut.

const TAVERN_PAGE: String = "res://scenes/tavern/tavern.tscn"
var panorama: TavernPanorama

@onready var tavern_page_button: Button = $TavernPageButton
@onready var leave_button: Button = $LeaveButton
@onready var left_arrow: Button = $GoLeftButton
@onready var right_arrow: Button = $RightArrow
@onready var forge_button: Button = $ForgeButton
@onready var leaderboard_button: Button = $LeaderboardButton
@onready var minigames_button: Button = $MinigamesButton
@onready var minigames_popup: Control = $MinigamesPopup
@onready var word_game_button: Button = $MinigamesPopup/Center/Panel/Menu/WordGameButton
@onready var handwriting_button: Button = $MinigamesPopup/Center/Panel/Menu/HandwritingButton
@onready var handwriting_lab_button: Button = $MinigamesPopup/Center/Panel/Menu/HandwritingLabButton
@onready var minigames_close_button: Button = $MinigamesPopup/Center/Panel/Menu/CloseButton
@onready var ice_fishing_button := get_node_or_null("DebugIceFishingButton") as Button
@onready var health_label: Label = $StatusPanel/HealthLabel
@onready var gold_label: Label = $StatusPanel/GoldLabel


func _ready() -> void:
	tavern_page_button.pressed.connect(_open_tavern_page)
	leave_button.pressed.connect(_leave_tavern)
	left_arrow.pressed.connect(_open_left_room)
	right_arrow.pressed.connect(_open_right_room)
	forge_button.pressed.connect(_open_forge)
	leaderboard_button.pressed.connect(_open_leaderboard)
	minigames_button.pressed.connect(_open_minigames)
	word_game_button.pressed.connect(_open_word_game)
	handwriting_button.pressed.connect(_open_handwriting_game)
	handwriting_lab_button.pressed.connect(func(): get_tree().change_scene_to_file(ScenePaths.HANDWRITING_LAB))
	minigames_close_button.pressed.connect(minigames_popup.hide)
	minigames_popup.hide()
	if ice_fishing_button != null:
		ice_fishing_button.visible = OS.is_debug_build()
		ice_fishing_button.pressed.connect(_open_ice_fishing)
	EventBus.gold_changed.connect(_on_gold_changed)
	_refresh_status()
	_build_panorama()


func _build_panorama() -> void:
	panorama = TavernPanorama.new()
	panorama.name = "Panorama"
	add_child(panorama)
	move_child(panorama, 1)
	var backdrop: Texture2D = $Background.texture
	$Background.hide()
	panorama.add_background(backdrop)
	panorama.portrait("res://art/characters/bartender.png", Rect2(0.51, 0.14, 0.14, 0.24), 0.56)
	panorama.portrait("res://art/characters/dealer.png", Rect2(0.045, 0.30, 0.15, 0.27), 0.62)
	# Reuse foreground strips so the existing characters sit behind the bar/table.
	panorama.foreground(backdrop, Rect2(0.325, 0.332, 0.485, 0.15))
	panorama.foreground(backdrop, Rect2(0.0, 0.48, 0.205, 0.12))
	panorama.prop("LOCAL LEGENDS\n──────────\nLEADERBOARD\nRun Records", Rect2(0.82, 0.13, 0.10, 0.15), Color("251b12"), 19)
	for index: int in 3:
		var tile := panorama.prop("ABC"[index], Rect2(0.855 + index * 0.028, 0.635, 0.024, 0.037), Color("d5b784"), 28)
		tile.rotation = -0.15 + index * 0.15
	panorama.prop("TAVERN\nJOURNAL", Rect2(0.67, 0.32, 0.065, 0.055), Color("312537"), 17)
	panorama.prop("FORGE", Rect2(0.155, 0.235, 0.105, 0.04), Color("302019"), 23)
	panorama.add_poi("bartender", "Bartender", Rect2(0.49, 0.14, 0.19, 0.29), left_arrow)
	panorama.add_poi("dealer", "Letter Dealer", Rect2(0.025, 0.29, 0.19, 0.30), right_arrow)
	panorama.add_poi("minigames", "Minigames", Rect2(0.82, 0.59, 0.15, 0.14), minigames_button)
	panorama.add_poi("leaderboard", "Leaderboard", Rect2(0.805, 0.115, 0.135, 0.20), leaderboard_button)
	panorama.add_poi("forge", "Forge", Rect2(0.145, 0.23, 0.13, 0.22), forge_button)
	panorama.add_poi("journal", "Tavern Journal", Rect2(0.65, 0.305, 0.10, 0.11), tavern_page_button)
	panorama.blocked = _room_menu_open
	$Subtitle.text = "Click and drag to look around. Click a marker to turn toward it."
	$Subtitle.add_theme_font_size_override("font_size", 16)
	$Title.add_theme_font_size_override("font_size", 34)


func _room_menu_open() -> bool:
	return minigames_popup.visible or get_node_or_null("LeaderboardOverlay") != null \
		or get_node_or_null("TavernShopOverlay") != null \
		or $EquipmentOverlay/EquipmentPanel.visible \
		or get_tree().get_first_node_in_group("letter_inspector") != null


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _room_menu_open():
		return
	if event.keycode == KEY_B:
		get_viewport().set_input_as_handled()
		_open_tavern_page()


func _open_tavern_page() -> void:
	get_tree().change_scene_to_file(TAVERN_PAGE)


func _leave_tavern() -> void:
	get_tree().change_scene_to_file(
		ScenePaths.COMBAT if RunState.is_endless() else ScenePaths.ENCOUNTER_SELECT
	)


func _open_left_room() -> void:
	TavernShopOverlay.open_in(self, ScenePaths.TAVERN_LEFT)


func _open_right_room() -> void:
	TavernShopOverlay.open_in(self, ScenePaths.TAVERN_RIGHT)


func _open_forge() -> void:
	get_tree().change_scene_to_file(ScenePaths.FORGE)


func _open_leaderboard() -> void:
	LeaderboardOverlay.open_in(self)


func _open_word_game() -> void:
	get_tree().change_scene_to_file(ScenePaths.WORD_GAME)


func _open_minigames() -> void:
	minigames_popup.show()


func _open_handwriting_game() -> void:
	get_tree().change_scene_to_file(ScenePaths.HANDWRITING_GAME)


func _open_ice_fishing() -> void:
	get_tree().change_scene_to_file(ScenePaths.ICE_FISHING)
func _on_gold_changed(_new_total: int) -> void:
	# Purchases may heal after spending gold; update after the transaction ends.
	_refresh_status.call_deferred()


func _refresh_status() -> void:
	health_label.text = "Health  %d / %d" % [
		RunState.player_health, RunState.player_max_health
	]
	gold_label.text = "Gold  %d" % RunState.gold
