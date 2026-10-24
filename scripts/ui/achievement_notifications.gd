extends CanvasLayer
## Persistent noninteractive notification queue, mounted under PlayerStats.
var _queue: Array[Dictionary] = []
var _seen: Array[String] = []
var _tween: Tween = null

@onready var panel: PanelContainer = $Toast
@onready var message: Label = $Toast/Message


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerStats.achievement_unlocked.connect(_enqueue)
	PlayerStats.achievement_notifications_cleared.connect(_clear)
	panel.hide()


func _enqueue(id: String, title: String) -> void:
	if _seen.has(id):
		return
	_seen.append(id)
	_queue.append({"id": id, "title": title})
	if not panel.visible:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		panel.hide()
		_tween = null
		return
	var entry: Dictionary = _queue.pop_front()
	message.text = "Achievement Unlocked\n%s" % entry.title
	panel.modulate.a = 1.0
	panel.show()
	_tween = create_tween()
	_tween.tween_interval(2.5)
	_tween.tween_property(panel, "modulate:a", 0.0, 0.35)
	_tween.tween_callback(_show_next)


func _clear() -> void:
	if _tween != null:
		_tween.kill()
	_tween = null
	_queue.clear()
	_seen.clear()
	panel.hide()
