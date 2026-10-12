class_name PartyStage
extends Control
## The combat stage where the letters being typed appear as chibi
## party members. Keeps one member per drawn letter lined up in word
## order and hands them their actions when the word is cast.

## Emitted once per cast, at the first member's key moment.
signal impact_landed()
signal gold_stolen(amount: int)
## Emitted when every member of the last cast has finished.
signal performance_finished()

## Delay between consecutive members starting their actions.
const PERFORM_STAGGER: float = 0.07

@export var member_scene: PackedScene = null
## Stage-space y of the ground line the party stands on.
@export var ground_y: float = 440.0
## Stage-space x of the first slot in the line.
@export var line_start_x: float = 80.0
@export var slot_spacing: float = 52.0
## Off-screen x where members enter from and leave to.
@export var offstage_left_x: float = -40.0
## How far past the right edge fleeing rogues run.
@export var offstage_right_margin: float = 60.0

var _members: Array[PartyMember] = []
var _performers: Array[PartyMember] = []
var _impact_pending: bool = false

@onready var members_root: Node2D = $Members
@onready var sfx: PartySfx = $PartySfx


func is_performing() -> bool:
	return not _performers.is_empty()


## Matches the lined-up members to the drawn letters of the word being
## typed: new letters walk in, removed letters walk out, and everyone
## else steps to their slot.
func sync_letters(drawn: Array[LetterStats]) -> void:
	for member: PartyMember in _members.duplicate():
		if not drawn.has(member.stats):
			_members.erase(member)
			member.walk_out(offstage_left_x)
	var ordered: Array[PartyMember] = []
	for stats: LetterStats in drawn:
		var member: PartyMember = _member_for(stats)
		if member == null:
			member = _spawn(stats)
		ordered.append(member)
	_members = ordered
	for index: int in range(_members.size()):
		_members[index].walk_to(_slot_x(index))


## Sends every lined-up member into its class action against a target
## in global coordinates. Returns false when nobody was on stage, in
## which case no signals follow.
func perform_word(target_global: Vector2) -> bool:
	if _members.is_empty():
		return false
	var target: Vector2 = get_global_transform().affine_inverse() \
			* target_global
	var exit_x: float = size.x + offstage_right_margin
	_impact_pending = true
	for index: int in range(_members.size()):
		var member: PartyMember = _members[index]
		_performers.append(member)
		member.struck.connect(_on_member_struck.bind(member), CONNECT_ONE_SHOT)
		member.finished.connect(_on_member_finished.bind(member))
		member.perform(target, exit_x, PERFORM_STAGGER * float(index))
	_members = []
	return true


func _spawn(stats: LetterStats) -> PartyMember:
	var member: PartyMember = member_scene.instantiate()
	members_root.add_child(member)
	member.position = Vector2(offstage_left_x, ground_y)
	member.setup(stats)
	member.cue_requested.connect(sfx.play)
	return member


func _member_for(stats: LetterStats) -> PartyMember:
	for member: PartyMember in _members:
		if member.stats == stats:
			return member
	return null


func _slot_x(index: int) -> float:
	return line_start_x + slot_spacing * float(index)


func _on_member_struck(member: PartyMember) -> void:
	if member.stats.element in [LetterStats.Element.LIGHTNING, LetterStats.Element.ICE]:
		gold_stolen.emit(1)
	if _impact_pending:
		_impact_pending = false
		impact_landed.emit()


func _on_member_finished(member: PartyMember) -> void:
	_performers.erase(member)
	if _performers.is_empty():
		performance_finished.emit()
