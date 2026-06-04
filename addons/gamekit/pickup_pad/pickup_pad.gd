extends Area3D
class_name GKPickupPad

## Generic pickup pad. An Area3D that hands an amount to a qualifying body on
## contact, then deactivates and respawns on a timer.
##
## When a body in `collector_group` enters while the pad is active, the pad emits
## collected(body, amount) AND, if the body has the method named by
## `collector_method` (default "collect"), calls body.collect(amount). Then the
## pad deactivates (hides its mesh, stops monitoring) until `respawn_s` elapses.
##
## Composition: the pad is self-contained — its mesh + collision are own children
## (see pickup_pad.tscn), so $Path here is fine. Pads join `pad_group` so a
## consumer can broadcast reset() to every pad via the group without node paths.

## Value handed to the collector on pickup.
@export var amount := 12.0
## Seconds before the pad re-activates after being collected.
@export var respawn_s := 4.0
## Only bodies in this group can collect the pad.
@export var collector_group: StringName = "gk_collector"
## Method called on the collecting body (if it has it), passed `amount`.
@export var collector_method: StringName = "collect"
## Group joined so consumers can broadcast reset() to all pads.
@export var pad_group: StringName = "gk_pickup_pad"
## Bigger visual + slower respawn — purely a scale hint applied in _ready.
@export var big := false:
	set(value):
		big = value
		if is_inside_tree():
			_apply_big()

## Emitted when a qualifying body collects the pad.
signal collected(body: Node, amount: float)

@onready var mesh: MeshInstance3D = $Mesh

var _respawn := 0.0   # remaining respawn time; 0 = active
var _active := true

func _ready() -> void:
	add_to_group(pad_group)
	body_entered.connect(_on_body_entered)
	_apply_big()

func _physics_process(delta: float) -> void:
	if _active:
		return
	_respawn -= delta
	if _respawn <= 0.0:
		_activate()

func _on_body_entered(body: Node) -> void:
	if not _active or not body.is_in_group(collector_group):
		return
	collected.emit(body, amount)
	if body.has_method(collector_method):
		body.call(collector_method, amount)
	_deactivate()

func _apply_big() -> void:
	if mesh == null:
		return
	mesh.scale = Vector3.ONE * (1.6 if big else 1.0)

## Go dormant until the respawn timer elapses. Hiding the mesh + disabling
## monitoring stops re-triggers.
func _deactivate() -> void:
	_active = false
	_respawn = respawn_s
	if mesh != null:
		mesh.visible = false
	# Deferred: runs from the body_entered callback, where Godot blocks
	# flipping monitoring directly ("Function blocked during in/out signal").
	set_deferred("monitoring", false)

func _activate() -> void:
	_active = true
	_respawn = 0.0
	if mesh != null:
		mesh.visible = true
	monitoring = true

## True while the pad is up for collection.
func is_active() -> bool:
	return _active

## Re-activate immediately. Call directly or via the pad_group broadcast.
func reset() -> void:
	_activate()
