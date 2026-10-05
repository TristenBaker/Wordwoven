class_name LayeredBackground
extends Control
## A pixel-art backdrop drawn from stacked layers, back to front. Layers
## can drift sideways and wrap (clouds), and jolt by depth when shaken:
## near layers move further than far ones. Offsets snap to whole art
## pixels so the art stays crisp at any integer scale.

# A half-second jolt that swings back and forth and settles. Also drives
# the combat UI shake so the two stay in step.
const SHAKE_STEP: float = 0.05
const SHAKE_PATTERN: Array[Vector2] = [
	Vector2(1.0, -0.4), Vector2(-0.9, 0.4), Vector2(0.8, -0.3),
	Vector2(-0.7, 0.3), Vector2(0.55, -0.2), Vector2(-0.45, 0.2),
	Vector2(0.35, -0.15), Vector2(-0.25, 0.1), Vector2(0.15, 0.0),
	Vector2.ZERO,
]

# Each: {"texture": Texture2D, "shake": art px, "scroll": art px per second}.
var _layers: Array[Dictionary] = []
var _art_size: Vector2 = Vector2.ONE
var _shake_elapsed: float = -1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


## Builds the layers from definitions with a "texture" path and optional
## "shake" and "scroll" amounts, all in art pixels.
func setup(definitions: Array[Dictionary]) -> void:
	_layers.clear()
	for definition: Dictionary in definitions:
		var texture: Texture2D = load(definition["texture"])
		if texture == null:
			push_error("LayeredBackground: missing layer " + definition["texture"])
			continue
		_art_size = Vector2(texture.get_size())
		_layers.append({
			"texture": texture,
			"shake": float(definition.get("shake", 0.0)),
			"scroll": float(definition.get("scroll", 0.0)),
			"offset": 0.0,
		})
	queue_redraw()


## Jolts every layer by its own depth-scaled amount.
func shake() -> void:
	_shake_elapsed = 0.0


func _process(delta: float) -> void:
	for layer: Dictionary in _layers:
		if layer["scroll"] != 0.0:
			layer["offset"] = fposmod(layer["offset"] + layer["scroll"] * delta, _art_size.x)
	if _shake_elapsed >= 0.0:
		_shake_elapsed += delta
		if _shake_elapsed >= SHAKE_STEP * SHAKE_PATTERN.size():
			_shake_elapsed = -1.0
	queue_redraw()


func _draw() -> void:
	if _layers.is_empty():
		return
	# Cover the control at a whole-number scale, centered.
	var pixel: float = maxf(floorf(maxf(size.x / _art_size.x, size.y / _art_size.y)), 1.0)
	var origin: Vector2 = ((size - _art_size * pixel) * 0.5).floor()
	var jolt: Vector2 = Vector2.ZERO
	if _shake_elapsed >= 0.0:
		jolt = SHAKE_PATTERN[mini(int(_shake_elapsed / SHAKE_STEP), SHAKE_PATTERN.size() - 1)]
	for layer: Dictionary in _layers:
		var texture: Texture2D = layer["texture"]
		var shift: Vector2 = (jolt * float(layer["shake"])).round()
		if layer["scroll"] != 0.0:
			# Drifting layers repeat side by side and wrap.
			shift.x -= floorf(layer["offset"])
			for copy: int in 2:
				var at: Vector2 = origin + (shift + Vector2(copy * _art_size.x, 0.0)) * pixel
				draw_texture_rect(texture, Rect2(at, _art_size * pixel), false)
			continue
		# Pad past the screen edge so a jolt never reveals a gap; the
		# padding samples clamp to the layer's own edge pixels.
		var pad: float = absf(float(layer["shake"])) + 1.0
		var source := Rect2(-pad - shift.x, -pad - shift.y, _art_size.x + pad * 2.0, _art_size.y + pad * 2.0)
		var dest := Rect2(origin - Vector2(pad, pad) * pixel, source.size * pixel)
		draw_texture_rect_region(texture, dest, source)
