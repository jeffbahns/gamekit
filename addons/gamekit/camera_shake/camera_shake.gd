extends Camera3D
class_name GKCameraShake

## Trauma-based screen shake for a Camera3D.
##
## Callers push impact strength via add_shake(0..1); trauma decays each frame and
## drives a random positional jolt that's offset^2 so small hits barely register
## but big ones really kick. The camera joins a group (default "gk_camera") so a
## consumer can shake all cameras with one group broadcast.
##
## Two ways to use it:
##  - Attach this script directly to a Camera3D: it shakes around its rest local
##    position automatically (see _process).
##  - Extend it for a follow/chase camera: do your own positioning in _process,
##    then add _shake_offset(delta) to the final position yourself. (Override
##    _process so the base rest-position path doesn't fight your follow code.)
##
## Group broadcast pattern (no hardcoded caller):
##   get_tree().call_group("gk_camera", "add_shake", 0.6)

@export var shake_decay := 5.0    ## trauma lost per second
@export var shake_strength := 0.6 ## metres of jolt at full trauma
@export var shake_max := 0.8      ## trauma cap so a pile-up can't blow it out
## Group joined on _ready so consumers can broadcast add_shake() to every camera.
@export var group_name: StringName = "gk_camera"

var _trauma := 0.0
var _rest := Vector3.ZERO  # local position to shake around

func _ready() -> void:
	add_to_group(group_name)
	_rest = position

## Add impact-scaled trauma (already normalised ~0..1 by the caller).
func add_shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, shake_max)

## Decay trauma and return the jolt offset for this frame (offset^2 falloff).
## Extenders call this from their own _process and add it to their position.
func _shake_offset(delta: float) -> Vector3:
	if _trauma <= 0.0:
		return Vector3.ZERO
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)
	var amount := _trauma * _trauma * shake_strength
	return Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amount

func _process(delta: float) -> void:
	# Direct-attach path: shake around the fixed rest position. Extenders override
	# _process and apply _shake_offset() after their own follow positioning.
	position = _rest + _shake_offset(delta)
