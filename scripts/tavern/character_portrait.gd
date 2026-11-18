class_name CharacterPortrait
extends PanelContainer
## Shows the selected party member's modular portrait or custom cosmetic.
## Tier textures remain exported for compatibility with existing scenes.

@export var warrior_tiers: Array[Texture2D] = []
@export var healer_tiers: Array[Texture2D] = []
@export var rogue_tiers: Array[Texture2D] = []

var _stats: LetterStats
var _inspect_button: Button
var _pop_tween: Tween = null
var _idle_tween: Tween = null
var _appearance: Control

@onready var portrait: TextureRect = %Portrait
@onready var level_label: Label = %LevelLabel
@onready var name_label: Label = %NameLabel
@onready var empty_label: Label = %EmptyLabel


func _ready() -> void:
	_appearance = preload("res://scripts/ui/letter_appearance.gd").new()
	_appearance.set("history_only", true)
	_appearance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(_appearance)
	_appearance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.resized.connect(_center_pivot)
	_start_idle_bob()
	_inspect_button = LetterInspector.add_inspect_button($Margin/Stage)
	_inspect_button.pressed.connect(func() -> void: LetterInspector.open_for(_stats))
	show_member(null)


## Displays a party member, or an empty prompt when stats is null.
func show_member(stats: LetterStats) -> void:
	_stats = stats
	_appearance.set("stats", stats)
	_appearance.queue_redraw()
	var has_member: bool = stats != null
	_inspect_button.visible = has_member
	portrait.visible = has_member
	level_label.visible = has_member
	name_label.visible = has_member
	empty_label.visible = not has_member
	if not has_member:
		return
	portrait.texture = texture_for(stats)
	portrait.self_modulate = stats.appearance_color()
	# Placeholder level readout until per-level art exists.
	level_label.text = str(stats.level)
	name_label.text = "%s · %s" % [
		stats.letter.to_upper(), stats.element_name_text()
	]
	_play_pop()


## Stable body/face pairing; a selected cosmetic takes priority.
func texture_for(stats: LetterStats) -> Texture2D:
	return PlayerProfile.cosmetic_texture(stats.letter, CharacterFeatures.portrait(stats))


func _tiers_for(element: int) -> Array[Texture2D]:
	match element:
		LetterStats.Element.FIRE, LetterStats.Element.EARTH:
			return warrior_tiers
		LetterStats.Element.LIGHTNING, LetterStats.Element.ICE:
			return rogue_tiers
	return healer_tiers


func _center_pivot() -> void:
	portrait.pivot_offset = Vector2(portrait.size.x * 0.5, portrait.size.y)


# A small squash-and-settle whenever the selection changes.
func _play_pop() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	portrait.scale = Vector2(1.08, 0.92)
	_pop_tween = create_tween()
	_pop_tween.tween_property(portrait, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Gentle breathing so the character feels alive while idle.
func _start_idle_bob() -> void:
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(portrait, "position:y", -4.0, 1.1) \
			.as_relative().set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(portrait, "position:y", 4.0, 1.1) \
			.as_relative().set_trans(Tween.TRANS_SINE)
