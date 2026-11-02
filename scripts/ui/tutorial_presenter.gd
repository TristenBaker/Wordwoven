extends RefCounted

const SPOTLIGHT_SCENE: PackedScene = preload(
	"res://scenes/ui/combat_tutorial.tscn"
)


## Returns true when a tutorial was shown. Headless tests and tutorials already
## viewed during this app session continue immediately without an overlay.
static func show(
	parent: Control,
	tutorial_id: String,
	steps: Array[Dictionary],
	on_finished: Callable = Callable()
) -> bool:
	if DisplayServer.get_name() == "headless" \
			or PlayerProfile.has_seen_session_tutorial(tutorial_id):
		return false
	var spotlight = SPOTLIGHT_SCENE.instantiate()
	if spotlight == null:
		return false
	parent.add_child(spotlight)
	spotlight.finished.connect(func() -> void:
		PlayerProfile.mark_session_tutorial_seen(tutorial_id)
		if on_finished.is_valid():
			on_finished.call()
	)
	spotlight.begin(steps)
	return true
