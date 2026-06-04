extends Node
class_name GKSynthSfx

## Procedural synth SFX bus. Builds all sound effects in code at startup as short
## AudioStreamWAV buffers — no asset files. Exposes a tiny play("blip") API backed
## by a small round-robin pool of AudioStreamPlayer nodes so overlapping cues
## don't cut each other off.
##
## Designed as an autoload: register it in project.godot under [autoload] (e.g.
## Sfx="*res://addons/gamekit/sfx/synth_sfx.gd") so play() works from any scene.
##
## A mute toggle is bound at startup (default key M via the "gk_mute" action).
## Consumers can add their own clips with register_clip(name, stream) and play
## them by name. The default set: blip, hit, pickup, explode, win.
##
## Tone/sweep/arpeggio/noise builders are public so consumers can synth more clips:
##   Sfx.register_clip("zap", Sfx.sweep(900.0, 120.0, 0.18, "square", 0.4, 9.0))

const SAMPLE_RATE := 22050
const POOL_SIZE := 6

## Action name toggled to mute/unmute. Auto-bound to mute_key if not present.
@export var mute_action: StringName = "gk_mute"
## Physical key bound to mute_action when it isn't already registered.
@export var mute_key: int = KEY_M

var muted := false              # sound toggle; persists across scenes for the session

var _clips := {}                # name -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build_clips()
	_ensure_action(mute_action, mute_key)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(mute_action):
		muted = not muted
		if not muted:
			play("blip")  # audible confirmation that sound is back on

func _build_clips() -> void:
	# A small generic demo set — consumers extend via register_clip().
	# Short mid blip (UI / confirmation).
	_clips["blip"] = tone(660.0, 0.12, "sine", 0.4, 5.0)
	# Low square thud (impact).
	_clips["hit"] = tone(160.0, 0.10, "square", 0.45, 6.0)
	# Upward blip (pickup).
	_clips["pickup"] = sweep(380.0, 720.0, 0.12, "square", 0.35, 7.0)
	# Noise burst with a fast decay (explosion-ish).
	_clips["explode"] = noise(0.35, 0.5, 8.0)
	# Three-note rising arpeggio (win fanfare).
	_clips["win"] = arpeggio([523.0, 659.0, 784.0], 0.11, "square", 0.4)

## Register or replace a clip by name so consumers can add their own cues.
func register_clip(name: StringName, stream: AudioStreamWAV) -> void:
	_clips[name] = stream

## Play a named cue. Unknown names are ignored so callers can't crash.
func play(name: StringName) -> void:
	if muted:
		return
	var clip: AudioStreamWAV = _clips.get(name)
	if clip == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = clip
	p.play()

## Single tone with an exponential decay envelope. `decay` is the falloff rate.
func tone(freq: float, dur: float, wave: String, amp: float, decay: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var data := PackedFloat32Array()
	data.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-decay * t)
		data[i] = _wave(wave, freq, t) * amp * env
	return _to_wav(data)

## Linear frequency sweep from `f0` to `f1` over the duration.
func sweep(f0: float, f1: float, dur: float, wave: String, amp: float, decay: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var data := PackedFloat32Array()
	data.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var freq := lerpf(f0, f1, t / dur)
		phase += TAU * freq / SAMPLE_RATE
		var env := exp(-decay * t)
		data[i] = _wave_phase(wave, phase) * amp * env
	return _to_wav(data)

## Sequence of notes back-to-back, each with its own quick decay.
func arpeggio(freqs: Array, note_dur: float, wave: String, amp: float) -> AudioStreamWAV:
	var per := int(SAMPLE_RATE * note_dur)
	var data := PackedFloat32Array()
	data.resize(per * freqs.size())
	var idx := 0
	for f in freqs:
		for i in per:
			var t := float(i) / SAMPLE_RATE
			var env := exp(-5.0 * t)
			data[idx] = _wave(wave, f, t) * amp * env
			idx += 1
	return _to_wav(data)

## White-noise burst with an exponential decay envelope (impacts / explosions).
func noise(dur: float, amp: float, decay: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur)
	var data := PackedFloat32Array()
	data.resize(n)
	for i in n:
		var t := float(i) / SAMPLE_RATE
		var env := exp(-decay * t)
		data[i] = randf_range(-1.0, 1.0) * amp * env
	return _to_wav(data)

func _wave(wave: String, freq: float, t: float) -> float:
	return _wave_phase(wave, TAU * freq * t)

func _wave_phase(wave: String, phase: float) -> float:
	if wave == "square":
		return 1.0 if sin(phase) >= 0.0 else -1.0
	return sin(phase)

## Pack a float buffer into a 16-bit mono AudioStreamWAV.
func _to_wav(data: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		var s := int(clampf(data[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = SAMPLE_RATE
	wav.data = bytes
	return wav

func _ensure_action(action: StringName, keycode: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
