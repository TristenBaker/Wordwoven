class_name ElementArt
extends RefCounted
## One reusable art catalog for cards, talents, and animated combat effects.
## Atlas regions trim transparent margins at render time; source PNGs stay intact.

const DIRECTORY := "res://assets/Art/Elements/"
const ELEMENTS: Array[String] = ["fire", "lightning", "water", "ice", "nature", "earth"]
const KINDS: Array[String] = ["emblem", "spell", "flourish"]
static var _textures: Dictionary = {}


static func texture(element: String, kind: String = "emblem") -> Texture2D:
	if not element in ELEMENTS or not kind in KINDS:
		return null
	var key := element + "_" + kind
	if not _textures.has(key):
		var path := DIRECTORY + key + ".png"
		if not ResourceLoader.exists(path):
			return null
		var source := load(path) as Texture2D
		if source == null:
			return null
		var region := source.get_image().get_used_rect()
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = region
		_textures[key] = atlas
	return _textures[key]


static func image(element: String, kind: String = "emblem") -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture(element, kind)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art
