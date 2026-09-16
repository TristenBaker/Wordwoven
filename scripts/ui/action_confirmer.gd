class_name ActionConfirmer
extends ConfirmationDialog
## Asks the player to approve one consequential action, such as
## spending gold or claiming a relic. Cancelling changes nothing.
## Only one request may be open, and an approval runs its action at
## most once; the action itself revalidates before changing state.

var _pending: Callable = Callable()


func _ready() -> void:
	dialog_autowrap = true
	min_size = Vector2i(420, 160)
	confirmed.connect(approve)
	canceled.connect(decline)


func is_pending() -> bool:
	return _pending.is_valid()


## Opens the dialog; returns false when another request is open.
func request(
	title_text: String, message: String, on_confirm: Callable
) -> bool:
	if is_pending():
		return false
	_pending = on_confirm
	title = title_text
	dialog_text = message
	popup_centered()
	return true


## Runs the pending action once and closes the dialog.
func approve() -> void:
	if not is_pending():
		return
	var action: Callable = _pending
	_pending = Callable()
	hide()
	action.call()


## Discards the pending action without running it.
func decline() -> void:
	_pending = Callable()
	if visible:
		hide()
