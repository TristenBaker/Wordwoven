class_name Enemy
extends Control
## The enemy in a combat encounter: holds its stats and word tags,
## displays its sprite, health, and tags, and reports damage taken.

signal died()

var enemy_name: String = ""
var attack: int = 0
var gold_reward: int = 0
var tags: Array[String] = []

var _max_health: int = 1
var _health: int = 1
var _hit_tween: Tween = null
var _sprite_rest: Vector2 = Vector2.ZERO

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
	enemy_name = spawn_data["name"]
	attack = spawn_data["attack"]
	gold_reward = spawn_data["gold"]
	tags = spawn_data["tags"]
	_max_health = spawn_data["health"]
	_health = _max_health
	name_label.text = enemy_name
	tags_label.text = " • ".join(tags)
	_apply_texture(
		spawn_data["texture"], spawn_data["frame_width"]
	)
	_refresh_health()


func is_alive() -> bool:
	return _health > 0


## Global point where party members aim their attacks.
func strike_point() -> Vector2:
	var area: Rect2 = sprite.get_global_rect()
	return area.get_center() + Vector2(0.0, area.size.y * 0.12)


func take_damage(amount: float) -> void:
	clear_damage_preview()
	_health = maxi(_health - int(round(amount)), 0)
	_refresh_health()
	_play_hit()
	EventBus.emit_enemy_damaged(amount)
	if _health <= 0:
		died.emit()


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


# Sprite sheets from the monster pack hold idle frames in a strip;
# a frame width crops the first frame, zero means a full image.
func _apply_texture(
	texture_id: String, frame_width: int
) -> void:
	var texture: Texture2D = load(texture_id)
	if texture == null:
		push_error("Enemy: missing texture " + texture_id)
		return
	if frame_width > 0:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(
			0, 0, frame_width, texture.get_height()
		)
		sprite.texture = atlas
	else:
		sprite.texture = texture


func _refresh_health() -> void:
	health_bar.max_value = _max_health
	health_bar.value = _health
	health_label.text = "%d / %d" % [_health, _max_health]
