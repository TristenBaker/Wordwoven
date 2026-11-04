class_name ForgeLetterRecognizer
extends RefCounted
## Small EMNIST neural network, evaluated entirely in GDScript.
const MODEL_PATH := "res://data/models/forge_letters.json"
static var _model: Dictionary = {}
static var _w1 := PackedFloat32Array()
static var _w2 := PackedFloat32Array()

static func available() -> bool:
	if _model.is_empty():
		var file := FileAccess.open(MODEL_PATH, FileAccess.READ)
		if file == null:
			return false
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			return false
		_model = parsed
		_w1 = PackedFloat32Array(_model.get("weights_1", []))
		_w2 = PackedFloat32Array(_model.get("weights_2", []))
	return _w1.size() == 784 * 96 and _w2.size() == 96 * 26

static func recognize(pixels: PackedFloat32Array) -> String:
	if pixels.size() != 784 or not available():
		return ""
	var hidden := PackedFloat32Array()
	hidden.resize(96)
	for row: int in 96:
		var value: float = _model.bias_1[row]
		var offset := row * 784
		for column: int in 784:
			value += _w1[offset + column] * pixels[column]
		hidden[row] = maxf(value, 0.0)
	var winner := 0
	var best := -INF
	for row: int in 26:
		var value: float = _model.bias_2[row]
		for column: int in 96:
			value += _w2[row * 96 + column] * hidden[column]
		if value > best:
			best = value
			winner = row
	return String(_model.labels)[winner]
