class_name Enemy
extends Control
## The enemy in a combat encounter: holds its stats and word tags,
## displays its sprite, health, and tags, and reports damage taken.

signal died()

var enemy_name: String = ""
var attack: int = 0
var gold_reward: int = 0
var tags: Array[String] = []
var affinities: Dictionary = {}

var _max_health: int = 1
var _health: int = 1
var _burn_damage: float = 0.0
var _poison_damage: float = 0.0

@onready var sprite: TextureRect = $Sprite
@onready var name_label: Label = $InfoBox/NameLabel
@onready var health_bar: ProgressBar = $InfoBox/HealthBar
@onready var health_preview: ColorRect = \
		$InfoBox/HealthBar/DamagePreview
@onready var health_label: Label = $InfoBox/HealthBar/HealthLabel
@onready var tags_label: Label = $InfoBox/TagsLabel


## Applies spawn data from the EnemyFactory to this display.
func setup(spawn_data: Dictionary) -> void:
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
		spawn_data["texture"], spawn_data["frame_width"]
	)
	_refresh_health()


func is_alive() -> bool:
	return _health > 0


func take_damage(amount: float) -> void:
	clear_damage_preview()
	_health = maxi(_health - int(round(amount)), 0)
	_refresh_health()
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
	var current_ratio := float(_health) / float(_max_health)
	var projected_ratio := float(projected_health) / float(_max_health)
	health_preview.anchor_left = projected_ratio
	health_preview.anchor_right = current_ratio
	health_preview.visible = projected_health < _health


func clear_damage_preview() -> void:
	health_preview.hide()


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
