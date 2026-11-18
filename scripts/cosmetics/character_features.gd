class_name CharacterFeatures
extends RefCounted
## Modular portrait parts. Atlas cells are composited at matching neck anchors.
## Runtime animations remain authored SpriteFrames; these parts are portraits.

const BODY_NAMES := [
	["Steel defender", "Leather vanguard", "Bronze sentinel"],
	["Emerald cleric", "Traveling apothecary", "Moss pilgrim"],
	["Plum infiltrator", "Charcoal scout", "Midnight duelist"],
]
const FACE_NAMES := [
	["Auburn browband", "Curls and circlet", "Silver veteran"],
	["Braided herbalist", "Freckled copper", "White curls"],
	["Swept hair and hood", "Textured bandana", "Silver sidecut"],
]
const CLASS_NAMES := ["Warrior", "Healer", "Rogue"]
const ATLAS_PATHS := [
	"res://art/party/features/warrior_parts_v3.png",
	"res://art/party/features/healer_parts_v3.png",
	"res://art/party/features/rogue_parts_v3.png",
]
# Per-sheet neck locations measured in the original atlas coordinates.
const BODY_NECK_Y := [230, 210, 230]
const FACE_NECK_Y := [875, 823, 887]
const ROW_SPLIT := [550, 550, 580]
const PORTRAIT_PIXEL_SIZE := 64
static var _textures: Dictionary = {}


static func archetype(element: int) -> int:
	match element:
		LetterStats.Element.FIRE, LetterStats.Element.EARTH:
			return 0
		LetterStats.Element.LIGHTNING, LetterStats.Element.ICE:
			return 2
	return 1


static func choices(stats: LetterStats) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = stats.appearance_seed
	var body := rng.randi_range(0, 2)
	var face := rng.randi_range(0, 2)
	if stats.body_feature >= 0:
		body = clampi(stats.body_feature, 0, 2)
	if stats.face_feature >= 0:
		face = clampi(stats.face_feature, 0, 2)
	return Vector2i(body, face)


static func description(stats: LetterStats) -> String:
	var kind := archetype(stats.element)
	var selected := choices(stats)
	return "%s · %s" % [BODY_NAMES[kind][selected.x], FACE_NAMES[kind][selected.y]]


static func portrait(stats: LetterStats) -> Texture2D:
	var selected := choices(stats)
	return combination(archetype(stats.element), selected.x, selected.y)


static func combination(kind: int, body: int, face: int) -> Texture2D:
	kind = clampi(kind, 0, 2)
	body = clampi(body, 0, 2)
	face = clampi(face, 0, 2)
	var key := Vector3i(kind, body, face)
	if _textures.has(key):
		return _textures[key]
	var atlas: Texture2D = load(ATLAS_PATHS[kind])
	var source := atlas.get_image()
	var result := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var split: int = ROW_SPLIT[kind]
	var body_image := source.get_region(Rect2i(body * 512, 0, 512, split))
	body_image.resize(225, roundi(split * 225.0 / 512.0), Image.INTERPOLATE_NEAREST)
	result.blend_rect(body_image, Rect2i(Vector2i.ZERO, body_image.get_size()),
		Vector2i(16, 104 - roundi(BODY_NECK_Y[kind] * 225.0 / 512.0)))
	var face_image := source.get_region(Rect2i(face * 512, split, 512, 1024 - split))
	face_image.resize(184, roundi((1024 - split) * 184.0 / 512.0), Image.INTERPOLATE_NEAREST)
	result.blend_rect(face_image, Rect2i(Vector2i.ZERO, face_image.get_size()),
		Vector2i(36, 108 - roundi((FACE_NECK_Y[kind] - split) * 184.0 / 512.0)))
	# Unify the separately scaled parts on one coarse pixel grid. Nearest
	# sampling preserves hard pixels when the portrait is enlarged in the UI.
	result.resize(PORTRAIT_PIXEL_SIZE, PORTRAIT_PIXEL_SIZE, Image.INTERPOLATE_NEAREST)
	# Pixel silhouettes use a binary alpha edge, avoiding a faint matte from
	# the source atlas when displayed over bright snow or dark UI panels.
	for y in PORTRAIT_PIXEL_SIZE:
		for x in PORTRAIT_PIXEL_SIZE:
			var pixel := result.get_pixel(x, y)
			pixel.a = 1.0 if pixel.a >= 0.5 else 0.0
			result.set_pixel(x, y, pixel)
	result.resize(256, 256, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(result)
	_textures[key] = texture
	return texture
