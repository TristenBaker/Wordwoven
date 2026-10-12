extends RefCounted
## A small local horizontal shake, independent of any parent screen shake.

var _target: Control
var _rest: Vector2
var _tween: Tween


func play(target: Control) -> void:
	cancel()
	_target = target
	_rest = target.position
	_tween = target.create_tween()
	for offset: float in [5.0, -4.0, 3.0, -2.0, 0.0]:
		_tween.tween_property(target, "position:x", _rest.x + offset, 0.035)
	_tween.tween_callback(cancel)


func cancel() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
		if is_instance_valid(_target):
			_target.position = _rest
	_target = null
