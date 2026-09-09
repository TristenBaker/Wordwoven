# GDScript style guide

Rules are grouped by how firmly established they are.
Follow all of them when writing new code; see "Applying to existing code" before reformatting anything that already works.

---

## 1. Specified rules

These come directly from the project owner. 
They are not negotiable and they override general Godot community convention where the two disagree.

### 1.1 Type every declaration explicitly

Do not use `:=`.
The editor does not reliably resolve inferred types, so every variable, parameter, and return gets a written-out type annotation.

```gdscript
# Correct
var speed: float = 5.0
var target: Node3D = null
var waypoints: Array[Vector3] = []
@export var mouse_sensitivity: float = 0.2 # radians/pixel
@onready var pivot: Node3D = $Pivot

func take_damage(amount: float, source: Node) -> void:
```

```gdscript
# Wrong — inferred
var speed := 5.0

# Wrong — untyped
var speed = 5.0

# Wrong — unannotated parameter and return
func take_damage(amount):
```

The rule is *explicit types*, not merely *avoid the walrus*.
Bare `var x = ...` is equally out, since it produces the same unresolved type.

Notes:

- `@onready` node references need the node's real type, not `Node`. Check the scene before writing the annotation — `$Pivot` is a `Node3D`,
- When something genuinely has no fixed type, annotate `: Variant` on purpose rather than leaving it bare. That records the decision.
- Typed arrays and dictionaries carry their element types: `Array[Node3D]`, `Dictionary[String, int]`.

### 1.2 Lines stay at or under 80 columns

Count a tab as 4 columns. 
A line at three levels of indentation therefore has 68 columns of room left.

Wrap inside brackets, parentheses, or braces — GDScript continues the statement implicitly there, so no backslash is needed:

```gdscript
var result: Dictionary = space.intersect_ray(
  	global_position,
	global_position + -transform.basis.z * 3.0
)

if event is InputEventMouseMotion \
		and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
	pass
```

Use backslash continuation only for boolean conditions, which have no natural bracket to wrap inside. 
Indent the continued line by two tabs so it does not line up with the body.

When a line will not fit gracefully, that is usually a signal to extract a local variable or a helper function rather than to keep wrapping:

```gdscript
var mouse_captured: bool = (
	Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
)
if event is InputEventMouseMotion and mouse_captured:
	pass
```

Trailing comments count toward the 80. 
Move a comment to its own line above the statement rather than shortening it into uselessness.

**These two rules pull against each other.** 
Explicit annotations lengthen declarations, and 80 columns is tight. 
When they collide, prefer a shorter identifier or an extracted variable — never drop the annotation to fit.

### 1.3 References

Use the UID of a resource instead of its path.

Similarly, use an absolute path for node references unless reordering is simple or unlikely.

### 1.4 Comments

Comments should be on their own line.
Comments should appear regularly to explain WHAT a section does, not HOW.
The code should be structured in such a way that acertaining how it works is no mystery and comments speed up that process rather than take the burden of explanation.

### 1.5 Node structure

Build nodes in the editor when appropriate.
Programatically generating nodes and assets is difficult to maintain.

---

## 2. Godot convention

Follow Godot convention unless otherwise stated.

**Naming**

| Kind | Case | Example |
| --- | --- | --- |
| Variables, functions | `snake_case` | `move_speed`, `take_damage` |
| Private members | `_snake_case` | `_elapsed` |
| Classes, nodes, scenes | `PascalCase` | `FloatingCube`, `Pivot` |
| Constants, enum members | `CONSTANT_CASE` | `MAX_HEALTH` |
| Signals | past-tense `snake_case` | `health_depleted` |
| Files | `snake_case.gd` | `floating_cube.gd` |

Names should be clear and shouldn't be acronymns.
Slightly longer names are acceptable to help limit confusion and help facilitate comprehension.

**Declaration order within a file**

```
class_name
extends
## docstring
signals
enums
constants
@export vars
public vars
private vars
@onready vars
_init()
_ready()
_process() / _physics_process()
_input() / _unhandled_input()
public methods
private methods
```

**Other**

- One class per file; the filename matches the `class_name` in snake_case.
- Always `signal` up and call down.
- Avoid `get_node()` chains in `_process`; cache in `@onready`.

---

## 3. Applying to existing code

**Default: leave working code alone.** 
Reformat a file when you are already editing it for a real reason, not as a standalone sweep. 
A pure-style commit across a live file makes the next real diff harder to read, and every reformatted line is a chance to introduce a bug in code that currently works.

When you do touch a file, bring the whole file up to standard rather than leaving it half-converted — mixed style within one file is worse than either style consistently applied.
