class_name PartySfx
extends Node
## Plays the party's animation sound cues through a small pool of
## players. Every cue's stream is assigned in the inspector, so custom
## sounds can replace the generated placeholders without code changes.

enum Cue {
	STEP,
	JUMP,
	SLASH,
	IMPACT,
	HEAL,
	COIN,
	DASH,
}

# Many letters walking at once would otherwise stack footsteps.
const STEP_COOLDOWN: float = 0.07

@export var step_sound: AudioStream = null
@export var jump_sound: AudioStream = null
@export var slash_sound: AudioStream = null
@export var impact_sound: AudioStream = null
@export var heal_sound: AudioStream = null
@export var coin_sound: AudioStream = null
@export var dash_sound: AudioStream = null
@export var step_volume_db: float = -14.0
@export var effect_volume_db: float = -4.0
## Random pitch spread so repeated cues do not sound identical.
@export_range(0.0, 0.5) var pitch_variance: float = 0.08

var _next_voice: int = 0
var _last_step_msec: int = 0

@onready var voices: Array[Node] = $Voices.get_children()


func play(cue: Cue) -> void:
	var stream: AudioStream = _stream_for(cue)
	if stream == null or voices.is_empty():
		return
	var volume: float = effect_volume_db
	if cue == Cue.STEP:
		var now: int = Time.get_ticks_msec()
		if now - _last_step_msec < int(STEP_COOLDOWN * 1000.0):
			return
		_last_step_msec = now
		volume = step_volume_db
	var voice: AudioStreamPlayer = voices[_next_voice]
	_next_voice = (_next_voice + 1) % voices.size()
	voice.stream = stream
	voice.volume_db = volume
	voice.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	voice.play()


func _stream_for(cue: Cue) -> AudioStream:
	match cue:
		Cue.STEP:
			return step_sound
		Cue.JUMP:
			return jump_sound
		Cue.SLASH:
			return slash_sound
		Cue.IMPACT:
			return impact_sound
		Cue.HEAL:
			return heal_sound
		Cue.COIN:
			return coin_sound
		Cue.DASH:
			return dash_sound
	return null
