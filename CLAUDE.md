# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

Gamekit — a small library of reusable, drop-in Godot 4.6 components (GDScript
only) extracted from the carball project. Each component is a plain
`class_name` script (gamekit-prefixed: `GK…`) with no cross-component coupling.
This is a **copy-don't-depend** library: there is no `plugin.cfg` and no editor
plugin. To use a component, copy its folder out of `addons/gamekit/<component>/`
into your project.

Components: `GKTuningPanel`, `GKCameraShake`, `GKSynthSfx`, `GKMotionTrail`,
`GKImpactBurst`, `GKPickupPad`. The `demo/` scene exercises all six.

## Conventions (inherited from carball)

- **Composition via typed `@export`** for any cross-scene dependency; the parent
  `.tscn` wires it (`node_paths` header + value line). `$Path` / `@onready` is
  only for self-owned children inside the same packed scene.
- **Groups, not node paths, for broadcasts.** Components join configurable groups
  (e.g. `gk_camera`, `gk_pickup_pad`) so consumers can `call_group(...)` without
  reaching in by node path.
- **Forces apply per unit mass** (`force * mass`) so tuning stays stable if mass
  changes.
- **Tunables are `@export`** on the node (editable in the inspector), not hidden
  in `const` unless truly invariant.
- **No asset files** — everything procedural (synthesized audio buffers,
  ParticleProcessMaterial, meshes built in `_ready`).
- **No `.uid` orphans** — when you delete a `.gd`/`.tscn`, delete its sibling
  `.gd.uid` / `.tscn`'s uid. All generated `.uid` files are committed.
- `.gitattributes` normalizes line endings; repo is text-only and portable.

## Validate headless

```sh
godot --path . --headless --import        # import resources, generate .uid
godot --path . --headless --quit-after 120 # run demo.tscn ~120 frames, expect 0 errors
```

macOS without `godot` on PATH:
`/Applications/Godot.app/Contents/MacOS/Godot --path . …`
