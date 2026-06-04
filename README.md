# Gamekit

A small library of reusable, drop-in **Godot 4.6** components (GDScript only),
extracted from the [carball](../carball) project. Each component is a plain
`class_name` script — no editor plugin, no `plugin.cfg`. This is a
**copy-don't-depend** library: grab a component by copying its folder out of
`addons/gamekit/<component>/` into your own project.

Everything is procedural — no asset files (audio is synthesized at runtime,
particle materials and meshes are built in `_ready`).

## Run the demo

```sh
godot --path .
```

The demo (`demo/demo.tscn`) is the main scene. Shove the orange sphere with the
**arrow keys** into the glowing pickup pads; each pickup fires an impact burst,
shakes the camera, and plays a sound. Press **`** (backtick) to open the tuning
panel and **M** to mute.

Headless validation:

```sh
godot --path . --headless --import
godot --path . --headless --quit-after 120
```

---

## GKTuningPanel — `addons/gamekit/tuning_panel/`

Left-docked, semi-transparent debug overlay for live property tweaking from the
UI — no editor round-trip. Consumers register knobs at runtime; each knob is a
slider + live value driving a property on any `Object`. A **Reset** button
restores the values captured the first time the panel is shown. The panel does
not pause the game and its `mouse_filter` lets clicks fall through to gameplay.

Drop in: copy `tuning_panel/`. Add a `Control` node with the script (or
`GKTuningPanel.new()`), then register knobs.

```gdscript
var panel := GKTuningPanel.new()
add_child(panel)
panel.add_knob("Shove force", player, "shove_force", 5.0, 60.0, 1.0)
# press ` to toggle
```

| Export | Default | Purpose |
| --- | --- | --- |
| `toggle_action` | `gk_tuning_toggle` | Action to show/hide; auto-bound to backtick if not registered. |

Method: `add_knob(label, target, property, min, max, step)`.

---

## GKCameraShake — `addons/gamekit/camera_shake/`

Trauma-based screen shake for a `Camera3D`. Push impact with `add_shake(0..1)`;
trauma decays per frame and drives a random `offset²` jolt (small hits barely
register, big ones kick). The camera joins a group so you can shake all cameras
with one broadcast.

Two usages:

- **Attach directly** to a `Camera3D` — it shakes around its rest local position.
- **Extend it** for a follow/chase camera: override `_process`, do your own
  follow positioning, then add `_shake_offset(delta)` to the final position.

Broadcast pattern (no hardcoded caller):

```gdscript
get_tree().call_group("gk_camera", "add_shake", 0.6)
```

| Export | Default | Purpose |
| --- | --- | --- |
| `shake_decay` | `5.0` | Trauma lost per second. |
| `shake_strength` | `0.6` | Metres of jolt at full trauma. |
| `shake_max` | `0.8` | Trauma cap so a pile-up can't blow it out. |
| `group_name` | `gk_camera` | Group joined for broadcasts. |

---

## GKSynthSfx — `addons/gamekit/sfx/`

Procedural synth SFX bus. Builds short `AudioStreamWAV` cues in code at startup
and plays them through a round-robin pool of `AudioStreamPlayer`s so overlapping
cues don't cut each other off. **Designed as an autoload** — register it so
`play()` works from any scene:

```gdscript
# project.godot
[autoload]
Sfx="*res://addons/gamekit/sfx/synth_sfx.gd"
```

```gdscript
Sfx.play("pickup")
# synth and register your own:
Sfx.register_clip("zap", Sfx.sweep(900.0, 120.0, 0.18, "square", 0.4, 9.0))
Sfx.play("zap")
```

Default clips: `blip`, `hit`, `pickup`, `explode`, `win`. Builders are public:
`tone`, `sweep`, `arpeggio`, `noise`. A mute toggle is auto-bound to **M**.

| Export | Default | Purpose |
| --- | --- | --- |
| `mute_action` | `gk_mute` | Action toggling mute. |
| `mute_key` | `KEY_M` | Key bound to `mute_action` if not already registered. |

Methods: `play(name)`, `register_clip(name, stream)`, and the builders above.

---

## GKMotionTrail — `addons/gamekit/motion_trail/`

Speed-reactive trail. Attach to a `GPUParticles3D` that is a child of a
`RigidBody3D`; it modulates `amount_ratio` so the trail is off when slow and a
visible streak at speed. Cheap — fixed particle pool, no per-frame allocation.

**Contract:** the parent must be a `RigidBody3D` (read for `linear_velocity`).
Set the particles' own process material / draw pass as usual; this script only
drives `amount_ratio` + `emitting`.

| Export | Default | Purpose |
| --- | --- | --- |
| `min_speed` | `6.0` | Speed (m/s) below which the trail is off. |
| `max_speed` | `30.0` | Speed (m/s) at full intensity. |
| `response` | `8.0` | How snappily the ratio follows speed changes. |

---

## GKImpactBurst — `addons/gamekit/impact_burst/`

One-shot `GPUParticles3D` burst — celebrations, impacts, pickups. Sits idle
until `burst()` fires a single pop. If no process material is assigned, `_ready`
builds a fully procedural `ParticleProcessMaterial` + `QuadMesh`, so **no scene
or asset is required** — `add_child(GKImpactBurst.new())` then `burst()` works.

```gdscript
var fx := GKImpactBurst.new()
add_child(fx)
fx.global_position = hit_point
fx.burst()
```

| Export | Default | Purpose |
| --- | --- | --- |
| `color` | `(1, 0.85, 0.35)` | Particle tint (procedural material only). |
| `amount_per_burst` | `48` | Particles per burst. |
| `burst_speed` | `6.0` | Outward initial speed (m/s). |
| `burst_lifetime` | `0.6` | Particle lifetime (s). |

---

## GKPickupPad — `addons/gamekit/pickup_pad/`

An `Area3D` that hands an amount to a qualifying body on contact, then
deactivates and respawns on a timer. When a body in `collector_group` enters
while active, the pad emits `collected(body, amount)` **and** calls
`body.collect(amount)` (or whatever `collector_method` names) if the body has
that method. Pads join `pad_group` so you can broadcast `reset()` to all of them.

Drop in: copy `pickup_pad/` and instance `pickup_pad.tscn` (or attach the script
to your own `Area3D` with a `Mesh` child).

```gdscript
pad.collected.connect(func(body, amount): print("got ", amount))
# or give the collector a collect() method:
func collect(amount: float) -> void: _energy += amount
```

| Export | Default | Purpose |
| --- | --- | --- |
| `amount` | `12.0` | Value handed to the collector. |
| `respawn_s` | `4.0` | Seconds before re-activating after pickup. |
| `collector_group` | `gk_collector` | Only bodies in this group can collect. |
| `collector_method` | `collect` | Method called on the body with `amount`. |
| `pad_group` | `gk_pickup_pad` | Group joined for `reset()` broadcasts. |
| `big` | `false` | Larger visual scale. |

Methods: `reset()`, `is_active()`.

---

## Credit

Extracted from the **carball** project. MIT licensed — see `LICENSE`.
