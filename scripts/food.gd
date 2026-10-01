extends MeshInstance3D
## A food pellet: floats a moment, sinks with a wobble, rests on the sand, then dissolves into cloudiness.

var world: Node
var vel := Vector3.ZERO
var wobble := 0.0
var settled := false
var rest_t := 0.0


func setup(main: Node, pos: Vector3) -> void:
	world = main
	position = pos
	wobble = randf() * TAU
	var sm := SphereMesh.new()
	sm.radius = 0.055
	sm.height = 0.07
	sm.radial_segments = 8
	sm.rings = 4
	mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.42, 0.14).lerp(Color(0.6, 0.3, 0.1), randf())
	mat.roughness = 0.7
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.15, 0.03)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	if settled:
		rest_t += delta
		if rest_t > 90.0:
			Game.cloudiness = minf(1.0, Game.cloudiness + 0.02)
			world.remove_food(self)
		return
	var cur := Game.current_at(position)
	vel.y = lerpf(vel.y, -0.36, 1.0 - exp(-delta * 1.2))
	vel.x = lerpf(vel.x, cur.x * 0.8, 1.0 - exp(-delta * 2.0))
	vel.z = lerpf(vel.z, cur.z * 0.8, 1.0 - exp(-delta * 2.0))
	wobble += delta * 2.5
	var step := (vel + Vector3(sin(wobble) * 0.08, 0, cos(wobble * 0.7) * 0.05)) * delta
	# Land on wood and rocks, not through them.
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position, position + step + Vector3(0, -0.03, 0)))
	if hit:
		position = hit.position + Vector3(0, 0.03, 0)
		settled = true
		return
	position += step
	position.x = clampf(position.x, -5.8, 5.8)
	position.z = clampf(position.z, -2.3, 2.3)
	rotate_y(delta * 1.5)
	var fh: float = world.tank.floor_height(position.x, position.z) + 0.04
	if position.y <= fh:
		position.y = fh
		settled = true
