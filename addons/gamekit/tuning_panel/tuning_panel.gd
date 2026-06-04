extends Control
class_name GKTuningPanel

## In-game tuning panel. A debug overlay docked on the left for live
## feel-tweaking from the UI — no editor round-trip. A toggle action (default a
## backtick `) shows/hides it.
##
## Unlike a hardcoded knob list, this is a generic, reusable panel: consumers
## register knobs at runtime with add_knob(label, target, property, min, max,
## step). Each knob drives a property on a live Object via a slider, showing the
## value next to it. A Reset button restores the values captured the first time
## the panel is shown. The panel sits on the side and does NOT pause — gameplay
## stays live while you tweak. mouse_filter is set so clicks outside an actual
## control fall through to the game.
##
## Usage:
##   var panel := GKTuningPanel.new()      # or instance a scene with this script
##   add_child(panel)
##   panel.add_knob("Shove force", player, "shove_force", 5.0, 60.0, 1.0)
##   # press ` to toggle.

## Action name that toggles the panel. If the action is not already registered,
## it is auto-bound to the backtick / grave key on _ready.
@export var toggle_action: StringName = "gk_tuning_toggle"

## One knob row: a property on a target Object, driven by a slider.
class Knob:
	var label: String
	var target: Object
	var prop: StringName
	var minimum: float
	var maximum: float
	var step: float

	func _init(p_label: String, p_target: Object, p_prop: StringName,
			p_min: float, p_max: float, p_step: float) -> void:
		label = p_label
		target = p_target
		prop = p_prop
		minimum = p_min
		maximum = p_max
		step = p_step

	func read() -> float:
		if target == null:
			return minimum
		return float(target.get(prop))

	func write(value: float) -> void:
		if target != null:
			target.set(prop, value)

var _knobs: Array[Knob] = []
var _rows: Array = []         # {knob, label, slider} per built row
var _defaults: Array = []     # value captured at first show, for Reset
var _vbox: VBoxContainer
var _captured := false        # defaults captured on first show

func _ready() -> void:
	# Bind the toggle action to backtick if the consumer hasn't defined it.
	_ensure_action(toggle_action, KEY_QUOTELEFT)
	# Clicks outside an actual control fall through to gameplay.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()

## Register a knob. Safe to call before or after _ready — the row is built
## immediately if the UI exists, otherwise queued and built in _build_ui.
func add_knob(label: String, target: Object, property: StringName,
		minimum: float, maximum: float, step: float) -> void:
	var knob := Knob.new(label, target, property, minimum, maximum, step)
	_knobs.append(knob)
	if _vbox != null:
		_build_row(knob)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	# custom_minimum_size enforces the 300px width; setting size directly would
	# fight the LEFT_WIDE preset's top/bottom anchors (anchor-override warning).
	panel.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.82)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 8)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_vbox)

	var title := Label.new()
	title.text = "TUNING (` toggles)"
	title.add_theme_font_size_override("font_size", 18)
	_vbox.add_child(title)

	# Build rows for any knobs registered before the UI existed.
	for knob in _knobs:
		_build_row(knob)

	var reset := Button.new()
	reset.text = "Reset"
	reset.pressed.connect(_reset)
	_vbox.add_child(reset)
	# Keep Reset pinned at the bottom as new knobs are added.
	_vbox.move_child(reset, -1)

func _build_row(knob: Knob) -> void:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 13)
	_vbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = knob.minimum
	slider.max_value = knob.maximum
	slider.step = knob.step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = clampf(knob.read(), knob.minimum, knob.maximum)
	_vbox.add_child(slider)

	var row := {"knob": knob, "label": label, "slider": slider}
	_rows.append(row)

	slider.value_changed.connect(func(v: float) -> void: _on_slider(row, v))
	_refresh_label(row)

func _on_slider(row: Dictionary, value: float) -> void:
	(row["knob"] as Knob).write(value)
	_refresh_label(row)

func _refresh_label(row: Dictionary) -> void:
	var knob: Knob = row["knob"]
	row["label"].text = "%s: %.2f" % [knob.label, (row["slider"] as HSlider).value]

## Restore every knob to the value captured the first time the panel was shown.
func _reset() -> void:
	for i in _rows.size():
		if i < _defaults.size():
			# Setting the slider fires value_changed → _on_slider, which writes live.
			(_rows[i]["slider"] as HSlider).value = _defaults[i]

## Capture current values as the Reset baseline (once, on first show).
func _capture_defaults() -> void:
	if _captured:
		return
	_captured = true
	_defaults.clear()
	for row in _rows:
		_defaults.append((row["knob"] as Knob).read())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		visible = not visible
		if visible:
			_capture_defaults()
		else:
			# Sliders grab keyboard focus on click; release it on close so the
			# keyboard keeps driving gameplay.
			var focused := get_viewport().gui_get_focus_owner()
			if focused != null:
				focused.release_focus()
		get_viewport().set_input_as_handled()

func _ensure_action(action: StringName, keycode: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
