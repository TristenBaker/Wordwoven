class_name PartyMember
extends Node2D
## One drawn letter shown as a chibi on the combat stage. It walks in
## and out as the word is typed, plays its class action when the word
## is cast, and then removes itself.

## Emitted at the action's key moment: a warrior's hit, a healer's
## cast, or a rogue's theft.
signal struck()
## Emitted once the action is over, right before the member frees.
signal finished()
signal cue_requested(cue: PartySfx.Cue)

# Height of the warrior's leap arc, in pixels.
const LEAP_HEIGHT: float = 90.0
# How far short of the target a warrior lands and a rogue stops.
const WARRIOR_LANDING_OFFSET: Vector2 = Vector2(-44.0, 20.0)
const ROGUE_GRAB_OFFSET: float = -44.0

@export var warrior_frames: SpriteFrames = null
@export var healer_frames: SpriteFrames = null
@export var rogue_frames: SpriteFrames = null
## Speed in pixels per second while lining up or leaving.
@export var walk_speed: float = 520.0
## Speed in pixels per second of a rogue's dash.
@export var run_speed: float = 1400.0

var stats: LetterStats = null

var _motion: Tween = null
var _performing: bool = false
# Scene-authored body scale; squash and stretch are relative to it.
var _body_scale: Vector2 = Vector2.ONE

@onready var body: Node2D = $Body
@onready var sprite: AnimatedSprite2D = $Body/Sprite
@onready var coin: Sprite2D = $Body/Coin
@onready var shadow: Sprite2D = $Shadow
@onready var dust: CPUParticles2D = $Dust
@onready var heal_ring: Sprite2D = $HealRing
@onready var heal_sparkles: CPUParticles2D = $HealSparkles
@onready var impact_burst: Sprite2D = $ImpactBurst
@onready var impact_sparks: CPUParticles2D = $ImpactSparks
@onready var coin_sparkle: CPUParticles2D = $CoinSparkle


func _ready() -> void:
	_body_scale = body.scale
	sprite.frame_changed.connect(_on_frame_changed)


func setup(new_stats: LetterStats) -> void:
	stats = new_stats
	sprite.sprite_frames = _frames_for(stats.element)
	sprite.play(&"idle")
	sprite.frame = randi() % 2


func is_performing() -> bool:
	return _performing


## Walks along the ground to a new x position, then idles.
func walk_to(x: float) -> void:
	if _performing:
		return
	var duration: float = absf(x - position.x) / walk_speed
	if duration < 0.01:
		_stop_motion()
		_idle()
		return
	_restart_motion()
	sprite.flip_h = x < position.x
	sprite.play(&"walk")
	_motion.tween_property(self, "position:x", x, duration)
	_motion.tween_callback(_idle)


## Walks back off the stage and frees itself.
func walk_out(x: float) -> void:
	if _performing:
		return
	_restart_motion()
	var duration: float = maxf(absf(x - position.x) / walk_speed, 0.1)
	sprite.flip_h = true
	sprite.play(&"walk")
	_motion.tween_property(self, "position:x", x, duration)
	_motion.parallel().tween_property(
		self, "modulate:a", 0.0, duration * 0.4
	).set_delay(duration * 0.6)
	_motion.tween_callback(queue_free)


## Plays this member's class action against the stage-space target,
## starting after the given delay. Rogues escape off to exit_x.
func perform(target: Vector2, exit_x: float, delay: float) -> void:
	_performing = true
	_restart_motion()
	sprite.flip_h = false
	if delay > 0.0:
		_motion.tween_interval(delay)
	match stats.element:
		LetterStats.Element.FIRE, LetterStats.Element.EARTH:
			_queue_warrior_action(target)
		LetterStats.Element.WATER, LetterStats.Element.NATURE:
			_queue_healer_action()
		LetterStats.Element.LIGHTNING, LetterStats.Element.ICE:
			_queue_rogue_action(target, exit_x)
	_motion.tween_callback(_finish)


# --- Class actions ---------------------------------------------------

# Crouch, leap onto the target, strike, then tumble away and fade like
# a spent particle.
func _queue_warrior_action(target: Vector2) -> void:
	var start: Vector2 = position
	var landing: Vector2 = target + WARRIOR_LANDING_OFFSET
	var fall_end: Vector2 = landing + Vector2(-50.0, 110.0)
	_motion.tween_callback(sprite.play.bind(&"crouch"))
	_motion.tween_property(
		body, "scale", _body_scale * Vector2(1.25, 0.75), 0.06
	)
	_motion.tween_callback(_on_warrior_leap)
	_motion.tween_method(
		_move_along_arc.bind(start, landing), 0.0, 1.0, 0.22
	)
	_motion.parallel().tween_property(body, "scale", _body_scale, 0.12)
	_motion.tween_callback(_on_warrior_strike.bind(target))
	# A brief hit-stop sells the impact.
	_motion.tween_interval(0.07)
	_motion.tween_property(self, "position", fall_end, 0.42) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion.parallel().tween_property(body, "rotation", -2.6, 0.42)
	_motion.parallel().tween_property(
		body, "scale", _body_scale * 0.4, 0.42
	)
	_motion.parallel().tween_property(self, "modulate:a", 0.0, 0.42)


# Raise the staff in a burst of light, then fade upward.
func _queue_healer_action() -> void:
	_motion.tween_callback(_on_heal_cast)
	_motion.tween_property(body, "position:y", -8.0, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_motion.parallel().tween_property(
		sprite, "modulate", Color(1.5, 2.0, 1.5), 0.12
	)
	_motion.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	_motion.tween_interval(0.12)
	_motion.tween_property(self, "modulate:a", 0.0, 0.25)
	_motion.parallel().tween_property(body, "position:y", -26.0, 0.25)


# Dash to the target, snatch a coin, and escape off the right edge.
func _queue_rogue_action(target: Vector2, exit_x: float) -> void:
	var grab_x: float = target.x + ROGUE_GRAB_OFFSET
	var dash_time: float = maxf(
		absf(grab_x - position.x) / run_speed, 0.08
	)
	var exit_time: float = absf(exit_x - grab_x) / run_speed
	_motion.tween_callback(_on_rogue_dash)
	_motion.tween_property(self, "position:x", grab_x, dash_time)
	_motion.tween_callback(_on_rogue_grab)
	_motion.tween_interval(0.14)
	_motion.tween_callback(sprite.play.bind(&"run"))
	_motion.tween_property(self, "position:x", exit_x, exit_time)
	_motion.parallel().tween_property(
		self, "modulate:a", 0.0, exit_time * 0.4
	).set_delay(exit_time * 0.6)


# --- Action beats ----------------------------------------------------

func _on_warrior_leap() -> void:
	sprite.play(&"leap")
	dust.restart()
	shadow.hide()
	cue_requested.emit(PartySfx.Cue.JUMP)


func _on_warrior_strike(target: Vector2) -> void:
	sprite.play(&"slash")
	cue_requested.emit(PartySfx.Cue.SLASH)
	cue_requested.emit(PartySfx.Cue.IMPACT)
	impact_burst.position = target - position
	impact_sparks.position = impact_burst.position
	impact_sparks.restart()
	_flash_effect(impact_burst, 0.5, 2.6, 0.18)
	struck.emit()


func _on_heal_cast() -> void:
	sprite.play(&"cast")
	heal_sparkles.restart()
	_flash_effect(heal_ring, 0.4, 3.0, 0.45)
	cue_requested.emit(PartySfx.Cue.HEAL)
	struck.emit()


func _on_rogue_dash() -> void:
	sprite.play(&"run")
	dust.restart()
	cue_requested.emit(PartySfx.Cue.DASH)


func _on_rogue_grab() -> void:
	sprite.play(&"grab")
	coin_sparkle.restart()
	cue_requested.emit(PartySfx.Cue.COIN)
	struck.emit()
	# The stolen coin pops up and is carried overhead.
	var rest: Vector2 = coin.position
	coin.position = rest + Vector2(8.0, 0.0)
	coin.show()
	var pop: Tween = create_tween()
	var peak: Vector2 = rest + Vector2(2.0, -10.0)
	pop.tween_property(coin, "position", peak, 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(coin, "position", rest, 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# Grows an effect sprite from one scale to another while fading it.
func _flash_effect(
	effect: Sprite2D, from_scale: float, to_scale: float, duration: float
) -> void:
	effect.scale = Vector2.ONE * from_scale
	effect.modulate.a = 1.0
	effect.show()
	var flash: Tween = create_tween().set_parallel(true)
	flash.tween_property(effect, "scale", Vector2.ONE * to_scale, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash.tween_property(effect, "modulate:a", 0.0, duration)
	flash.chain().tween_callback(effect.hide)


# --- Helpers ---------------------------------------------------------

func _move_along_arc(progress: float, start: Vector2, end: Vector2) -> void:
	var lift: float = LEAP_HEIGHT * 4.0 * progress * (1.0 - progress)
	position = start.lerp(end, progress) + Vector2(0.0, -lift)


func _restart_motion() -> void:
	_stop_motion()
	_motion = create_tween()


func _stop_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null


func _idle() -> void:
	sprite.flip_h = false
	sprite.play(&"idle")


func _finish() -> void:
	finished.emit()
	queue_free()


func _frames_for(element: int) -> SpriteFrames:
	match element:
		LetterStats.Element.FIRE, LetterStats.Element.EARTH:
			return warrior_frames
		LetterStats.Element.LIGHTNING, LetterStats.Element.ICE:
			return rogue_frames
	return healer_frames


func _on_frame_changed() -> void:
	var moving: bool = sprite.animation in [&"walk", &"run"]
	if moving and sprite.frame % 2 == 0:
		cue_requested.emit(PartySfx.Cue.STEP)
