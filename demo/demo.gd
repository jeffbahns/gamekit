extends Node3D

## Gamekit demo. Exercises every component:
##  - GKMotionTrail on a RigidBody3D sphere you shove with the arrow keys.
##  - GKPickupPad x3; the sphere's collect() prints, plays SFX, fires a burst,
##    and shakes the camera.
##  - GKImpactBurst one-shot at the collected pad.
##  - GKCameraShake on the camera (shaken on pickup).
##  - GKSynthSfx autoload (Sfx) for cues.
##  - GKTuningPanel pre-loaded with knobs (` toggles it).
##
## Cross-scene deps are injected via typed @export, wired in demo.tscn.

## Force (per unit mass) applied to the sphere on an arrow key.
@export var shove_force := 28.0

@export var ball: RigidBody3D            ## the shovable sphere
@export var trail: GKMotionTrail         ## sphere's trail (for tuning knobs)
@export var cam: GKCameraShake           ## the camera
@export var burst: GKImpactBurst         ## one-shot pickup burst
@export var panel: GKTuningPanel         ## tuning overlay
@export var help_label: Label            ## on-screen keyboard help

var _score := 0

func _ready() -> void:
	# Bind arrow-key movement actions at runtime (no InputMap asset).
	_ensure_action("gk_demo_up", KEY_UP)
	_ensure_action("gk_demo_down", KEY_DOWN)
	_ensure_action("gk_demo_left", KEY_LEFT)
	_ensure_action("gk_demo_right", KEY_RIGHT)

	# Pads call this group's members; the ball is the collector.
	if ball != null:
		ball.add_to_group("gk_collector")
		# Give the ball a collect() callback by connecting each pad's signal too,
		# but the ball implements collect() directly below, so pads call it.

	# Wire every pad's collected signal so the demo can place the burst + shake.
	for pad in get_tree().get_nodes_in_group("gk_pickup_pad"):
		(pad as GKPickupPad).collected.connect(_on_pad_collected)

	# Pre-load tuning knobs once the panel exists.
	if panel != null:
		panel.add_knob("Shove force", self, "shove_force", 5.0, 80.0, 1.0)
		if trail != null:
			panel.add_knob("Trail min speed", trail, "min_speed", 0.0, 20.0, 0.5)
			panel.add_knob("Trail max speed", trail, "max_speed", 5.0, 60.0, 0.5)
		if cam != null:
			panel.add_knob("Shake decay", cam, "shake_decay", 1.0, 20.0, 0.5)
			panel.add_knob("Shake strength", cam, "shake_strength", 0.0, 2.0, 0.05)

	if help_label != null:
		help_label.text = "Arrows: shove sphere   `: tuning panel   M: mute   (drive into the glowing pads)"

func _physics_process(_delta: float) -> void:
	if ball == null:
		return
	var dir := Vector3.ZERO
	dir.z -= Input.get_action_strength("gk_demo_up")
	dir.z += Input.get_action_strength("gk_demo_down")
	dir.x -= Input.get_action_strength("gk_demo_left")
	dir.x += Input.get_action_strength("gk_demo_right")
	if dir != Vector3.ZERO:
		# Per-unit-mass force so tuning stays stable if mass changes.
		ball.apply_central_force(dir.normalized() * shove_force * ball.mass)

## The sphere is the collector — pads call this with their amount.
func collect(value: float) -> void:
	_score += int(value)
	print("Collected %.0f (score %d)" % [value, _score])

func _on_pad_collected(_body: Node, _amount: float) -> void:
	# Move the burst to the ball and fire it; shake + sound the pickup.
	if burst != null and ball != null:
		burst.global_position = ball.global_position
		burst.burst()
	if cam != null:
		cam.add_shake(0.6)
	# Sfx autoload is globally accessible by name.
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").play("pickup")

func _ensure_action(action: StringName, keycode: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
