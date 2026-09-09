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

@onready var sprite: TextureRect = $Sprite
@onready var name_label: Label = $InfoBox/NameLabel
@onready var health_bar: ProgressBar = $InfoBox/HealthBar
@onready var health_label: Label = $InfoBox/HealthBar/HealthLabel
@onready var tags_label: Label = $InfoBox/TagsLabel


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


func take_damage(amount: float) -> void:
	_health = maxi(_health - int(round(amount)), 0)
	_refresh_health()
	EventBus.emit_enemy_damaged(amount)
	if _health <= 0:
		died.emit()


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
