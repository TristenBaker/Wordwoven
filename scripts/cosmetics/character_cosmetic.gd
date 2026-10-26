class_name CharacterCosmetic
extends Resource
## A self-contained visual actor. Combat requests semantic actions such as
## "attack" or "walk"; this asset maps them to its own SpriteFrames names.

enum Archetype { WARRIOR, HEALER, ROGUE }

@export var display_name := "Unnamed Cosmetic"
@export var archetype: Archetype = Archetype.WARRIOR
@export var portrait: Texture2D
@export var sprite_frames: SpriteFrames
## Compensates for cosmetics authored at a larger native frame size.
@export_range(0.25, 4.0, 0.05) var render_scale := 1.0
@export var animation_map: Dictionary = {
	"idle": &"idle",
	"walk": &"walk",
	"crouch": &"crouch",
	"leap": &"leap",
	"attack": &"slash",
	"cast": &"cast",
	"run": &"run",
	"grab": &"grab",
}


func animation_for(action: StringName) -> StringName:
	return StringName(animation_map.get(String(action), action))


func has_action(action: StringName) -> bool:
	return sprite_frames != null and sprite_frames.has_animation(animation_for(action))
