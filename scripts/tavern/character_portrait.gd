class_name CharacterPortrait
extends PanelContainer
## Shows the selected party member's full character sprite with its
## level. Each class lists one texture per level tier in the inspector;
## levels past the end of a list reuse its last texture, so new tiers
## can be added without code changes.

@export var warrior_tiers: Array[Texture2D] = []
@export var healer_tiers: Array[Texture2D] = []
@export var rogue_tiers: Array[Texture2D] = []

var _pop_tween: Tween = null
var _idle_tween: Tween = null

@onready var portrait: TextureRect = %Portrait
@onready var level_label: Label = %LevelLabel
@onready var name_label: Label = %NameLabel
@onready var empty_label: Label = %EmptyLabel


func _ready() -> void:
	portrait.resized.connect(_center_pivot)
	_start_idle_bob()
	show_member(null)


## Displays a party member, or an empty prompt when stats is null.
func show_member(stats: LetterStats) -> void:
	var has_member: bool = stats != null
	portrait.visible = has_member
	level_label.visible = has_member
	name_label.visible = has_member
	empty_label.visible = not has_member
	if not has_member:
		return
	portrait.texture = texture_for(stats)
	# Placeholder level readout until per-level art exists.
	level_label.text = str(stats.level)
	name_label.text = "%s · %s" % [
		stats.letter.to_upper(), stats.element_name_text()
	]
	_play_pop()


## The texture for a member's class at its current level tier.
func texture_for(stats: LetterStats) -> Texture2D:
	var tiers: Array[Texture2D] = _tiers_for(stats.element)
	if tiers.is_empty():
		return null
	return tiers[clampi(stats.level - 1, 0, tiers.size() - 1)]


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
