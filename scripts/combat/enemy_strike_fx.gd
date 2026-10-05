class_name EnemyStrikeFx
extends Control
## Full-screen flourish for an enemy's retaliation: claw slashes rake
## across the middle of the screen with a red flash, a spark burst, a
## screen shake, and the damage dealt. A blocked blow shows slashes only.

const CLAW_COUNT: int = 3
const CLAW_SPACING: float = 46.0
const SLASH_TIME: float = 0.12
const SLASH_STAGGER: float = 0.04
const FADE_TIME: float = 0.35
const FLASH_ALPHA: float = 0.28
# Peak UI jolt in pixels; the swing follows the backdrop's shake pattern.
const SHAKE_STRENGTH: float = 14.0
const SPARK_TEXTURE: Texture2D = preload("res://art/party/effects/spark.png")
const NUMBER_FONT: FontFile = preload("res://assets/Fonts/Junicode-Bold.ttf")

var glow_color: Color = Color(1.0, 0.32, 0.22)

var _elapsed: float = -1.0
var _flash: float = 0.0
var _sparks: CPUParticles2D
var _number: Label
var _number_tween: Tween
var _shake_target: Control
var _shake_rest: Vector2
var _shake_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 15
	_sparks = _build_sparks()
	add_child(_sparks)
	_number = Label.new()
	_number.add_theme_font_override("font", NUMBER_FONT)
	_number.add_theme_font_size_override("font_size", 72)
	_number.add_theme_color_override("font_color", Color(1.0, 0.3, 0.22))
	_number.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.02))
	_number.add_theme_constant_override("outline_size", 10)
	_number.hide()
	add_child(_number)
	set_process(false)


## Plays the strike over the screen center. Shakes `shake_target` when
## the blow deals damage.
func play(damage: int, shake_target: Control = null) -> void:
	var hit: bool = damage > 0
	_elapsed = 0.0
	_flash = FLASH_ALPHA if hit else 0.0
	_sparks.position = size * 0.5
	_sparks.restart()
	if hit:
		_shake(shake_target)
		_show_number(damage)
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	_flash = maxf(_flash - delta * 0.9, 0.0)
	var total: float = SLASH_STAGGER * (CLAW_COUNT - 1) + SLASH_TIME + FADE_TIME
	if _elapsed > total and _flash <= 0.0:
		_elapsed = -1.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.04, 0.02, _flash))
	if _elapsed < 0.0:
		return
	var center: Vector2 = size * 0.5
	# Rake from upper right to lower left, toward the party.
	var direction: Vector2 = Vector2(-1.0, 0.62).normalized()
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var reach: float = minf(size.x, size.y) * 0.62
	for i: int in CLAW_COUNT:
		var local: float = _elapsed - i * SLASH_STAGGER
		var reveal: float = clampf(local / SLASH_TIME, 0.0, 1.0)
		var fade: float = 1.0 - clampf((local - SLASH_TIME) / FADE_TIME, 0.0, 1.0)
		if reveal <= 0.0 or fade <= 0.0:
			continue
		# The middle claw reaches furthest, like a paw.
		var side: float = i - (CLAW_COUNT - 1) * 0.5
		var length: float = reach * (1.0 - absf(side) * 0.15)
		var start: Vector2 = center + normal * side * CLAW_SPACING \
				- direction * length * 0.5
		var tip: Vector2 = start + direction * length * reveal
		_draw_slash(start, tip, 24.0, Color(glow_color, 0.45 * fade))
		_draw_slash(start, tip, 9.0, Color(1.0, 0.97, 0.92, fade))


# A stroke that swells in the middle and tapers to points at both ends.
func _draw_slash(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	if from.distance_to(to) < 2.0:
		return
	var normal: Vector2 = (to - from).normalized().orthogonal()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps: int = 12
	for s: int in steps + 1:
		var t: float = float(s) / steps
		var point: Vector2 = from.lerp(to, t)
		var half: float = width * 0.5 * sin(PI * t)
		left.append(point + normal * half)
		right.append(point - normal * half)
	right.reverse()
	draw_colored_polygon(left + right, color)


func _shake(target: Control) -> void:
	if target == null:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		_shake_target.position = _shake_rest
	_shake_target = target
	_shake_rest = target.position
	_shake_tween = create_tween()
	for jolt: Vector2 in LayeredBackground.SHAKE_PATTERN:
		_shake_tween.tween_property(
			target, "position", _shake_rest + (jolt * SHAKE_STRENGTH).round(),
			LayeredBackground.SHAKE_STEP
		)


func _show_number(damage: int) -> void:
	if _number_tween != null and _number_tween.is_valid():
		_number_tween.kill()
	_number.text = "-%d" % damage
	_number.size = _number.get_minimum_size()
	_number.pivot_offset = _number.size * 0.5
	_number.position = size * 0.5 - _number.size * 0.5
	_number.scale = Vector2(0.5, 0.5)
	_number.modulate = Color.WHITE
	_number.show()
	_number_tween = create_tween().set_parallel(true)
	_number_tween.tween_property(_number, "scale", Vector2(1.2, 1.2), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_number_tween.tween_property(_number, "position:y", _number.position.y - 48.0, 0.9) \
			.set_ease(Tween.EASE_OUT)
	_number_tween.tween_property(_number, "modulate:a", 0.0, 0.5).set_delay(0.45)
	_number_tween.chain().tween_callback(_number.hide)


func _build_sparks() -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.amount = 28
	sparks.lifetime = 0.55
	sparks.explosiveness = 1.0
	sparks.texture = SPARK_TEXTURE
	sparks.spread = 180.0
	sparks.gravity = Vector2(0, 320)
	sparks.initial_velocity_min = 180.0
	sparks.initial_velocity_max = 460.0
	sparks.damping_min = 120.0
	sparks.damping_max = 220.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.5
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color.WHITE, Color(glow_color, 0.0)])
	sparks.color_ramp = ramp
	return sparks
