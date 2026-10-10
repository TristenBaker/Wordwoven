class_name Enemy
extends Control
## The enemy in a combat encounter: holds its stats and word tags,
## displays its sprite, health, and tags, and reports damage taken.

signal died()
## Emitted on the attack animation's contact frame, or when it is cut short.
signal attack_landed()
signal animation_finished(anim_name: String)

const IDLE_SPEED_MULTIPLIER: float = 0.5

static var _matte_mask: ImageTexture

var enemy_id: String = ""
var enemy_name: String = ""
var _idle_atlas: AtlasTexture
var _idle_frames: int = 1
var _idle_fps: float = 5.0
var _idle_elapsed: float = 0.0
var _idle_width: float = 0.0
# Plays idle forward then back (0-1-2-3-2-1) without repeating the ends.
var _idle_ping_pong: bool = false
# Grid sheets: one row per animation, with "idle" on row 0.
var _animations: Dictionary = {}
var _cell_height: float = 0.0
var _region_top: float = 0.0
var _anim: String = "idle"
var _anim_elapsed: float = 0.0
var _attack_pending: bool = false
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
var _retaliation_offset: Vector2 = Vector2.ZERO:
	set(value):
		_retaliation_offset = value
		sprite.position = _sprite_rest + Vector2(_hit_offset, 0.0) + _retaliation_offset
var _hit_offset: float = 0.0:
	set(value):
		_hit_offset = value
		sprite.position = _sprite_rest + Vector2(_hit_offset, 0.0) + _retaliation_offset

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
	_retaliation_origin = sprite.position
	var center: Vector2 = sprite.get_global_rect().get_center()
	var global_offset: Vector2 = center.direction_to(target_global) * 32.0
	var inverse: Transform2D = sprite.get_parent().get_global_transform().affine_inverse()
	_retaliation_peak = _retaliation_origin + (inverse * (center + global_offset) - inverse * center)
	_retaliation_tween = create_tween()
	_retaliation_tween.tween_property(self, "_retaliation_offset", _retaliation_peak - _retaliation_origin, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func finish_retaliation_lunge() -> void:
	if _retaliation_tween == null:
		return
	# Instant attacks keep their original damage timing while the forward tween
	# finishes visually. Animated attacks recoil from the position already reached.
	if not _retaliation_tween.is_running():
		_retaliation_tween = create_tween()
	_retaliation_tween.tween_property(self, "_retaliation_offset", Vector2.ZERO, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_retaliation_tween.tween_callback(cancel_retaliation_lunge)


func cancel_retaliation_lunge() -> void:
	if _retaliation_tween != null:
		_retaliation_tween.kill()
		_retaliation_offset = Vector2.ZERO
		_retaliation_tween = null


## Plays the attack animation and resolves on its contact frame, so the
## retaliation lands with the blow. Enemies without one resolve at once.
func play_attack() -> void:
	if not _play_animation("attack"):
		return
	_attack_pending = true
	await attack_landed


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
	sprite.modulate = Color.WHITE
	if _play_animation("death") or (_anim == "hurt" and is_processing()):
		await animation_finished
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
	_hit_offset = 0.0
	sprite.position = _sprite_rest
	sprite.modulate = Color(2.5, 2.5, 2.5)
	_hit_tween = create_tween()
	for offset: float in [8.0, -6.0, 4.0, 0.0]:
		_hit_tween.tween_property(
			self, "_hit_offset", offset, 0.04
		)
	_hit_tween.parallel().tween_property(
		sprite, "modulate", Color.WHITE, 0.12
	)
	# The killing blow plays hurt too; its last pose holds for the dissolve.
	_play_animation("hurt")


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
	# Grid sheets are timed in Aseprite; only the legacy idles are slowed.
	var speed: float = 1.0 if int(data.get("cell_width", 0)) > 0 \
			else IDLE_SPEED_MULTIPLIER
	_idle_fps = float(data.get("idle_fps", 5.0)) * speed
	_idle_ping_pong = bool(data.get("idle_ping_pong", false))
	_idle_elapsed = 0.0
	_idle_atlas = null
	_animations = data.get("animations", {})
	_anim = "idle"
	_attack_pending = false
	if _idle_frames > 1:
		var cell_width: float = float(data.get("cell_width", 0))
		_idle_width = cell_width if cell_width > 0.0 \
				else float(texture.get_width()) / _idle_frames
		_cell_height = float(data.get("cell_height", 0))
		_region_top = float(data.get("idle_top", 0))
		_idle_atlas = AtlasTexture.new()
		_idle_atlas.atlas = texture
		_idle_atlas.filter_clip = true
		_idle_atlas.region = Rect2(0, _region_top,
			_idle_width, data.get("idle_height", texture.get_height()))
		sprite.texture = _idle_atlas
		var extent: float = data.get("display_size", 360.0)
		sprite.scale = Vector2.ONE
		sprite.size = Vector2(extent, extent)
		if cell_width > 0.0:
			# Grid sheets keep their cropped aspect so the feet meet the ground line.
			sprite.size.y = extent * _idle_atlas.region.size.y / _idle_width
		if enemy_id == "frost_wyrm":
			sprite.pivot_offset = sprite.size * 0.5
			sprite.scale = Vector2(1.5, 1.5)
		# Center below the existing name/health UI on the same ground line.
		sprite.position = Vector2(size.x * 0.5 + 20.0 - extent * 0.5, 470.0 - sprite.size.y)
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
		var y: int = floor(float(index) / width)
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
	if _idle_atlas == null or (not is_alive() and _anim == "idle"):
		return
	if _anim == "idle":
		_idle_elapsed = fmod(_idle_elapsed + delta, float(_idle_cycle()) / _idle_fps)
		_show_frame(0, _idle_frame())
		return
	var anim: Dictionary = _animations[_anim]
	var frames: int = int(anim["frames"])
	_anim_elapsed += delta
	var frame: int = int(_anim_elapsed * float(anim["fps"]))
	if _anim == "attack" and frame >= int(anim.get("hit_frame", 0)):
		_land_attack()
	if frame < frames:
		_show_frame(int(anim["row"]), frame)
		return
	var finished: String = _anim
	if finished == "death" or not is_alive():
		# Hold the final pose for the dissolve.
		_show_frame(int(anim["row"]), frames - 1)
		set_process(false)
	else:
		_anim = "idle"
		_show_frame(0, _idle_frame())
	animation_finished.emit(finished)


# Steps in one idle loop; a ping-pong turns around at each end frame.
func _idle_cycle() -> int:
	if _idle_ping_pong and _idle_frames > 2:
		return _idle_frames * 2 - 2
	return _idle_frames


func _idle_frame() -> int:
	var cycle: int = _idle_cycle()
	var step: int = int(_idle_elapsed * _idle_fps) % cycle
	return cycle - step if step >= _idle_frames else step


# Starts a one-shot row from a grid sheet; false if this enemy has none.
func _play_animation(anim_name: String) -> bool:
	if _idle_atlas == null or not _animations.has(anim_name):
		return false
	# An interrupted attack still resolves, so its awaiting turn continues.
	_land_attack()
	_anim = anim_name
	_anim_elapsed = 0.0
	_show_frame(int(_animations[anim_name]["row"]), 0)
	return true


func _land_attack() -> void:
	if _attack_pending:
		_attack_pending = false
		attack_landed.emit()


func _show_frame(row: int, frame: int) -> void:
	# Idle-only art can supply poses for existing one-shot timelines.
	var frame_indices: Array = _animations.get(_anim, {}).get("frame_indices", [])
	if not frame_indices.is_empty():
		frame = int(frame_indices[clampi(frame, 0, frame_indices.size() - 1)])
	var region: Rect2 = _idle_atlas.region
	region.position = Vector2(frame * _idle_width, row * _cell_height + _region_top)
	_idle_atlas.region = region


func _refresh_health() -> void:
	health_bar.max_value = _max_health
	health_bar.value = _health
	health_label.text = "%d / %d" % [_health, _max_health]
