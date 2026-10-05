class_name Enemy
extends Control
## The enemy in a combat encounter: holds its stats and word tags,
## displays its sprite, health, and tags, and reports damage taken.

signal died()

const IDLE_SPEED_MULTIPLIER: float = 0.5

static var _matte_mask: ImageTexture

var enemy_id: String = ""
var enemy_name: String = ""
var _idle_atlas: AtlasTexture
var _idle_frames: int = 1
var _idle_fps: float = 5.0
var _idle_elapsed: float = 0.0
var _idle_width: float = 0.0
var attack: int = 0
var gold_reward: int = 0
var tags: Array[String] = []
var affinities: Dictionary = {}

var _max_health: int = 1
var _health: int = 1
var _burn_damage: float = 0.0
var _poison_damage: float = 0.0
var _hit_tween: Tween = null
var _sprite_rest: Vector2 = Vector2.ZERO
var _retaliation_tween: Tween
var _retaliation_origin: Vector2
var _retaliation_peak: Vector2

@onready var sprite: TextureRect = $Sprite
@onready var name_label: Label = $InfoBox/NameLabel
@onready var health_bar: ProgressBar = $InfoBox/HealthBar
@onready var health_preview: ColorRect = \
		$InfoBox/HealthBar/DamagePreview
@onready var health_label: Label = $InfoBox/HealthBar/HealthLabel
@onready var tags_label: Label = $InfoBox/TagsLabel
@onready var info_box: VBoxContainer = $InfoBox
@onready var death_smoke: CPUParticles2D = $DeathSmoke
@onready var death_sound: AudioStreamPlayer = $DeathSound


func _ready() -> void:
	_sprite_rest = sprite.position


## Applies spawn data from the EnemyFactory to this display.
func setup(spawn_data: Dictionary) -> void:
	enemy_id = spawn_data["id"]
	enemy_name = spawn_data["name"]
	attack = spawn_data["attack"]
	gold_reward = spawn_data["gold"]
	tags = spawn_data["tags"]
	affinities = spawn_data.get("affinities", {})
	_max_health = spawn_data["health"]
	_health = _max_health
	_burn_damage = 0.0
	_poison_damage = 0.0
	name_label.text = enemy_name
	tags_label.text = " • ".join(tags) + _affinity_text()
	_apply_texture(
		spawn_data["texture"], spawn_data["frame_width"], spawn_data
	)
	_refresh_health()


func is_alive() -> bool:
	return _health > 0


## Global point where party members aim their attacks.
func strike_point() -> Vector2:
	var area: Rect2 = sprite.get_global_rect()
	return area.get_center() + Vector2(0.0, area.size.y * 0.12)


## Presentation only: texture-region idle playback continues during the lunge.
func begin_retaliation_lunge(target_global: Vector2) -> void:
	cancel_retaliation_lunge()
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
		sprite.position = _sprite_rest
		sprite.modulate = Color.WHITE
	_retaliation_origin = sprite.position
	var center: Vector2 = sprite.get_global_rect().get_center()
	var global_offset: Vector2 = center.direction_to(target_global) * 32.0
	var inverse: Transform2D = sprite.get_parent().get_global_transform().affine_inverse()
	_retaliation_peak = _retaliation_origin + (inverse * (center + global_offset) - inverse * center)
	_retaliation_tween = create_tween()
	_retaliation_tween.tween_property(sprite, "position", _retaliation_peak, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func finish_retaliation_lunge() -> void:
	if _retaliation_tween == null:
		return
	_retaliation_tween.kill()
	# Snap to the contact point at the authoritative damage event, then recoil.
	sprite.position = _retaliation_peak
	_retaliation_tween = create_tween()
	_retaliation_tween.tween_property(sprite, "position", _retaliation_origin, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_retaliation_tween.tween_callback(cancel_retaliation_lunge)


func cancel_retaliation_lunge() -> void:
	if _retaliation_tween != null:
		_retaliation_tween.kill()
		sprite.position = _retaliation_origin
		_retaliation_tween = null


func take_damage(amount: float) -> void:
	clear_damage_preview()
	_health = maxi(_health - int(round(amount)), 0)
	_refresh_health()
	_play_hit()
	EventBus.emit_enemy_damaged(amount)
	if _health <= 0:
		died.emit()


func add_burn(amount: float) -> void:
	_burn_damage += maxf(amount, 0.0)


func consume_burn() -> float:
	var damage: float = _burn_damage
	_burn_damage = 0.0
	if damage > 0.0 and is_alive():
		take_damage(damage)
	return damage


func add_poison(amount: float) -> void:
	_poison_damage += maxf(amount, 0.0)


func consume_poison() -> float:
	var damage: float = _poison_damage
	_poison_damage = 0.0
	if damage > 0.0 and is_alive():
		take_damage(damage)
	return damage


func _affinity_text() -> String:
	var weak: Array[String] = []
	var resistant: Array[String] = []
	for element_name: String in [
		"fire", "lightning", "water", "ice", "nature", "earth"
	]:
		var multiplier: float = float(affinities.get(element_name, 1.0))
		if multiplier > 1.0:
			weak.append(element_name.capitalize())
		elif multiplier < 1.0:
			resistant.append(element_name.capitalize())
	var lines: Array[String] = []
	if not weak.is_empty():
		lines.append("Weak: " + ", ".join(weak))
	if not resistant.is_empty():
		lines.append("Resists: " + ", ".join(resistant))
	return "\n" + " · ".join(lines) if not lines.is_empty() else ""


func set_projected_damage(amount: float) -> void:
	var projected_health: int = maxi(
		_health - int(round(amount)), 0
	)
	var current_ratio: float = float(_health) / float(_max_health)
	var projected_ratio: float = (
		float(projected_health) / float(_max_health)
	)
	health_preview.anchor_left = projected_ratio
	health_preview.anchor_right = current_ratio
	health_preview.visible = projected_health < _health


func clear_damage_preview() -> void:
	health_preview.hide()


## Flashes, then dissolves the enemy into smoke. Await it to know when
## the enemy has fully faded.
func play_death() -> void:
	cancel_retaliation_lunge()
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	sprite.position = _sprite_rest
	death_sound.play()
	death_smoke.global_position = strike_point()
	death_smoke.restart()
	var fade: Tween = create_tween()
	fade.tween_property(sprite, "modulate", Color(3.0, 3.0, 3.0), 0.06)
	fade.tween_property(sprite, "modulate", Color(1.0, 0.35, 0.3), 0.1)
	fade.tween_property(sprite, "modulate:a", 0.0, 0.55)
	fade.parallel().tween_property(
		sprite, "position:y", _sprite_rest.y - 24.0, 0.55
	)
	fade.parallel().tween_property(info_box, "modulate:a", 0.0, 0.35)
	await fade.finished
	# Let the last of the smoke drift before the scene changes.
	await get_tree().create_timer(0.15).timeout


# Brief white flash and shake whenever damage lands.
func _play_hit() -> void:
	cancel_retaliation_lunge()
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	sprite.position = _sprite_rest
	sprite.modulate = Color(2.5, 2.5, 2.5)
	_hit_tween = create_tween()
	for offset: float in [8.0, -6.0, 4.0, 0.0]:
		_hit_tween.tween_property(
			sprite, "position:x", _sprite_rest.x + offset, 0.04
		)
	_hit_tween.parallel().tween_property(
		sprite, "modulate", Color.WHITE, 0.12
	)


# Tundra sheets use four idle poses with per-sheet vertical framing.
# Legacy enemies retain their existing static image or first-frame crop.
func _apply_texture(
	texture_id: String, frame_width: int, data: Dictionary = {}
) -> void:
	var texture: Texture2D = load(texture_id)
	if texture == null:
		push_error("Enemy: missing texture " + texture_id)
		return
	sprite.material = null
	if data.get("black_matte", false):
		var matte_material := ShaderMaterial.new()
		matte_material.shader = preload("res://shaders/tundra_black_key.gdshader")
		matte_material.set_shader_parameter("matte_mask", _get_matte_mask(texture))
		sprite.material = matte_material
	_idle_frames = int(data.get("idle_frames", 1))
	_idle_fps = float(data.get("idle_fps", 5.0)) * IDLE_SPEED_MULTIPLIER
	_idle_elapsed = 0.0
	_idle_atlas = null
	if _idle_frames > 1:
		_idle_width = float(texture.get_width()) / _idle_frames
		_idle_atlas = AtlasTexture.new()
		_idle_atlas.atlas = texture
		_idle_atlas.filter_clip = true
		_idle_atlas.region = Rect2(0, data.get("idle_top", 0),
			_idle_width, data.get("idle_height", texture.get_height()))
		sprite.texture = _idle_atlas
		var extent: float = data.get("display_size", 360.0)
		sprite.scale = Vector2.ONE
		sprite.size = Vector2(extent, extent)
		if enemy_id == "frost_wyrm":
			sprite.pivot_offset = sprite.size * 0.5
			sprite.scale = Vector2(1.5, 1.5)
		# Center below the existing name/health UI on the same ground line.
		sprite.position = Vector2(size.x * 0.5 + 20.0 - extent * 0.5, 470.0 - extent)
		_sprite_rest = sprite.position
	elif frame_width > 0:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(
			0, 0, frame_width, texture.get_height()
		)
		sprite.texture = atlas
	else:
		sprite.texture = texture


# The supplied Behemoth has an opaque matte. Flood from the sheet border
# once, so black eyes/body details remain opaque; never modify the source PNG.
func _get_matte_mask(texture: Texture2D) -> ImageTexture:
	if _matte_mask != null:
		return _matte_mask
	var source: Image = texture.get_image()
	if source.is_compressed():
		source.decompress()
	var width: int = source.get_width()
	var height: int = source.get_height()
	var mask := PackedByteArray()
	mask.resize(width * height)
	mask.fill(255)
	var queue := PackedInt32Array()
	for x in width:
		queue.append(x)
		queue.append((height - 1) * width + x)
	for y in height:
		queue.append(y * width)
		queue.append(y * width + width - 1)
	var cursor: int = 0
	while cursor < queue.size():
		var index: int = queue[cursor]
		cursor += 1
		if mask[index] == 0:
			continue
		var x: int = index % width
		var y: int = index / width
		var pixel: Color = source.get_pixel(x, y)
		if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.10:
			continue
		mask[index] = 0
		if x > 0:
			queue.append(index - 1)
		if x < width - 1:
			queue.append(index + 1)
		if y > 0:
			queue.append(index - width)
		if y < height - 1:
			queue.append(index + width)
	_matte_mask = ImageTexture.create_from_image(
		Image.create_from_data(width, height, false, Image.FORMAT_R8, mask)
	)
	return _matte_mask


func _process(delta: float) -> void:
	if _idle_atlas == null or not is_alive():
		return
	_idle_elapsed = fmod(_idle_elapsed + delta, float(_idle_frames) / _idle_fps)
	var frame: int = int(_idle_elapsed * _idle_fps) % _idle_frames
	var region: Rect2 = _idle_atlas.region
	region.position.x = frame * _idle_width
	_idle_atlas.region = region


func _refresh_health() -> void:
	health_bar.max_value = _max_health
	health_bar.value = _health
	health_label.text = "%d / %d" % [_health, _max_health]
