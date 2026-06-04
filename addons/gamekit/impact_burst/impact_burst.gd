extends GPUParticles3D
class_name GKImpactBurst

## One-shot particle burst.
##
## A GPUParticles3D that sits idle (emitting = false, one_shot) until burst()
## restarts emission for a single pop — celebrations, impacts, pickups. If no
## process material is assigned, _ready builds a fully procedural
## ParticleProcessMaterial + QuadMesh draw pass so no .tscn / asset is required:
## you can just `add_child(GKImpactBurst.new())` and call burst().
##
## Cheap: a fixed small pool that only spends draws during the ~lifetime window.

## Particle tint (procedural material only — ignored if you assign your own).
@export var color := Color(1.0, 0.85, 0.35, 1.0)
## Number of particles per burst.
@export var amount_per_burst := 48
## Outward initial speed (m/s).
@export var burst_speed := 6.0
## Particle lifetime (s).
@export var burst_lifetime := 0.6

func _ready() -> void:
	one_shot = true
	emitting = false
	amount = max(amount_per_burst, 1)
	lifetime = burst_lifetime
	explosiveness = 1.0  # all particles spawn at once for a clean pop
	if process_material == null:
		process_material = _build_process_material()
	if draw_pass_1 == null:
		draw_pass_1 = _build_mesh()

## Fire a single burst.
func burst() -> void:
	restart()
	emitting = true

func _build_process_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = burst_speed * 0.4
	mat.initial_velocity_max = burst_speed
	mat.gravity = Vector3(0, -4.0, 0)
	mat.damping_min = 1.0
	mat.damping_max = 2.0
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	mat.color = color
	# Fade alpha out over life.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r, color.g, color.b, 1.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	mat.color_ramp = tex
	return mat

func _build_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.25, 0.25)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.vertex_color_use_as_albedo = true
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.emission_enabled = true
	smat.emission = color
	smat.emission_energy_multiplier = 2.0
	mesh.material = smat
	return mesh
