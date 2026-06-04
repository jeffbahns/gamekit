extends GPUParticles3D
class_name GKMotionTrail

## Speed-reactive motion trail.
##
## Attach this script to a GPUParticles3D that is a child of a RigidBody3D. It
## modulates amount_ratio so the trail is off/minimal when slow and a visible
## streak at speed. Cheap: a fixed particle pool whose active fraction scales with
## the parent body's linear_velocity.length() — no per-frame allocation.
##
## Contract: the parent MUST be a RigidBody3D (read for linear_velocity). The body
## is a self-owned parent in the same scene, so get_parent() is fine here. Set the
## GPUParticles3D's own process material / draw pass in the editor or scene as
## usual; this script only drives amount_ratio + emitting.

## Speed (m/s) below which the trail is fully off.
@export var min_speed := 6.0
## Speed (m/s) at which the trail reaches full intensity.
@export var max_speed := 30.0
## How quickly the emit ratio follows speed changes (higher = snappier).
@export var response := 8.0

var _body: RigidBody3D
var _ratio := 0.0

func _ready() -> void:
	var p := get_parent()
	if p is RigidBody3D:
		_body = p as RigidBody3D
	emitting = true
	amount_ratio = 0.0

func _physics_process(delta: float) -> void:
	if _body == null:
		return
	var speed := _body.linear_velocity.length()
	var target := clampf((speed - min_speed) / maxf(max_speed - min_speed, 0.001), 0.0, 1.0)
	# Smooth so brief contacts don't strobe the trail.
	_ratio = lerpf(_ratio, target, clampf(response * delta, 0.0, 1.0))
	amount_ratio = _ratio
	# Stop spawning entirely when effectively idle to save the draw.
	emitting = _ratio > 0.01
