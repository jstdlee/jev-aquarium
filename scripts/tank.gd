extends Node3D
## The aquarium scene: camera, light, sand, glass, water surface, plants, wood, rocks and ambience.
## Everything is generated in code so the look can be tuned without art files.

const X_HALF := 6.0
const Z_HALF := 2.5
const WATER_Y := 6.6
const TOP_Y := 7.0

const SAND := preload("res://shaders/sand_real.gdshader")
const Scenery = preload("res://scripts/scenery.gd")
const SAND_TEX := "res://assets/textures/coast_sand_01/coast_sand_01_"
const BACKDROP := preload("res://shaders/backdrop.gdshader")
const GLASS := preload("res://shaders/glass.gdshader")
const SURFACE := preload("res://shaders/surface.gdshader")
const RAYS := preload("res://shaders/rays.gdshader")
const PLANT := preload("res://shaders/plant.gdshader")
const WOOD := preload("res://shaders/wood.gdshader")
const ROCK := preload("res://shaders/rock.gdshader")
const LEAF := preload("res://shaders/leaf.gdshader")
const PARTICLE := preload("res://shaders/particle.gdshader")

var camera: Camera3D
var scenery: Node3D
var reflect_vp: SubViewport
var reflect_cam: Camera3D
var env: Environment
var sand_mat: ShaderMaterial
var back_mat: ShaderMaterial
var surface_mat: ShaderMaterial
var plant_mats: Array = []
var ripples: Array = []  # Vector4(x, z, start, strength)
var leaves: Array = []  # {pos, vel, rot, spin}
var leaf_mm: MultiMesh
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 7
	_build_camera_and_light()
	_build_floor()
	_build_walls()
	_build_surface()
	scenery = Scenery.new()
	add_child(scenery)
	scenery.setup(self)
	_build_rays()
	_build_particles()
	_build_leaves()
	for i in 8:
		ripples.append(Vector4(0, 0, -100, 0))


## Sand height at (x, z): rises toward the back with a mound under the driftwood.
func floor_height(x: float, z: float) -> float:
	var h := 0.3 + 0.95 * clampf((1.6 - z) / 4.0, 0.0, 1.0)
	h += 0.1 * sin(x * 0.9 + 1.3) * cos(z * 1.3)
	h += 0.45 * exp(-(pow(x + 2.6, 2.0) + pow(z + 0.9, 2.0)) / 2.2)
	h += 0.35 * exp(-(pow(x - 3.8, 2.0) + pow(z + 0.6, 2.0)) / 1.6)
	return h


func _build_camera_and_light() -> void:
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 49.0
	camera.position = Vector3(0, 3.6, 15.0)
	camera.look_at_from_position(camera.position, Vector3(0, 3.45, 0), Vector3.UP)
	camera.current = true
	add_child(camera)

	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.11, 0.075)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.46, 0.36)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.22, 0.3, 0.18)
	env.fog_density = 0.35
	env.fog_depth_begin = 14.0
	env.fog_depth_end = 30.0
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	env.adjustment_contrast = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.88, 0.7)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.65
	sun.directional_shadow_max_distance = 40.0
	sun.rotation_degrees = Vector3(-62, -28, 0)
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 4.0, 6.0)
	fill.light_color = Color(0.7, 0.85, 0.75)
	fill.light_energy = 0.6
	fill.omni_range = 14.0
	add_child(fill)


func _build_floor() -> void:
	var nx := 72
	var nz := 30
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for j in nz + 1:
		for i in nx + 1:
			var x := -X_HALF + 2.0 * X_HALF * i / nx
			var z := -Z_HALF + 2.0 * Z_HALF * j / nz
			verts.append(Vector3(x, floor_height(x, z), z))
			var e := 0.05
			var dx := floor_height(x + e, z) - floor_height(x - e, z)
			var dz := floor_height(x, z + e) - floor_height(x, z - e)
			norms.append(Vector3(-dx, 2.0 * e, -dz).normalized())
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + nx + 1
			idx.append_array([a, a + 1, b + 1, a, b + 1, b])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var uvs := PackedVector2Array()
	for v in verts:
		uvs.append(Vector2(v.x, v.z) * 0.28)
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_tangents()
	var mesh := st.commit()
	sand_mat = ShaderMaterial.new()
	sand_mat.shader = SAND
	sand_mat.set_shader_parameter("albedo_tex", load(SAND_TEX + "Diffuse.jpg"))
	sand_mat.set_shader_parameter("normal_tex", load(SAND_TEX + "nor_gl.jpg"))
	sand_mat.set_shader_parameter("rough_tex", load(SAND_TEX + "Rough.jpg"))
	sand_mat.set_shader_parameter("ao_tex", load(SAND_TEX + "AO.jpg"))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = sand_mat
	add_child(mi)
	# Front face of the sand bed, seen through the glass.
	var front := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0 * X_HALF, 0.6)
	front.mesh = q
	front.position = Vector3(0, 0.0, Z_HALF - 0.01)
	front.material_override = sand_mat
	add_child(front)


func _quad(size: Vector2, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _build_walls() -> void:
	back_mat = ShaderMaterial.new()
	back_mat.shader = BACKDROP
	_quad(Vector2(2.0 * X_HALF, TOP_Y + 0.4), Vector3(0, TOP_Y * 0.5 - 0.2, -Z_HALF), Vector3.ZERO, back_mat)
	var glass := ShaderMaterial.new()
	glass.shader = GLASS
	for side in [-1.0, 1.0]:
		_quad(Vector2(2.0 * Z_HALF, TOP_Y + 0.4), Vector3(side * X_HALF, TOP_Y * 0.5 - 0.2, 0), Vector3(0, 90, 0), glass)
	# Bright glass edges at the corners, like the concept art.
	var edge_mat := ShaderMaterial.new()
	edge_mat.shader = GLASS
	edge_mat.set_shader_parameter("edge", 0.35)
	for side in [-1.0, 1.0]:
		for zz in [Z_HALF, -Z_HALF]:
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.05, TOP_Y + 0.4, 0.05)
			box.mesh = bm
			box.position = Vector3(side * X_HALF, TOP_Y * 0.5 - 0.2, zz)
			box.material_override = edge_mat
			box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(box)


func _build_surface() -> void:
	# Mirror camera for the underside of the water (total internal reflection). It renders
	# everything except the surface itself (layer 2) into a half-resolution texture.
	reflect_vp = SubViewport.new()
	reflect_vp.size = Vector2i(800, 450)
	reflect_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(reflect_vp)
	reflect_cam = Camera3D.new()
	reflect_cam.cull_mask = 1
	reflect_cam.keep_aspect = Camera3D.KEEP_WIDTH
	reflect_vp.add_child(reflect_cam)
	surface_mat = ShaderMaterial.new()
	surface_mat.shader = SURFACE
	surface_mat.set_shader_parameter("reflect_tex", reflect_vp.get_texture())
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.0 * X_HALF, 2.0 * Z_HALF)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3(0, WATER_Y, 0)
	mi.layers = 2
	mi.material_override = surface_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _update_reflection() -> void:
	# Mirror the main camera about the water plane.
	var p := camera.global_position
	var target := p - camera.global_transform.basis.z
	var mp := Vector3(p.x, 2.0 * WATER_Y - p.y, p.z)
	var mt := Vector3(target.x, 2.0 * WATER_Y - target.y, target.z)
	reflect_cam.fov = camera.fov
	reflect_cam.global_transform = Transform3D(Basis(), mp).looking_at(mt, Vector3.UP)
	var vsize := get_viewport().get_visible_rect().size
	reflect_vp.size = Vector2i(maxi(64, int(vsize.x / 2)), maxi(36, int(vsize.y / 2)))
	var vp: Projection = reflect_cam.get_camera_projection() * Projection(reflect_cam.global_transform.affine_inverse())
	surface_mat.set_shader_parameter("reflect_vp", vp)


func add_ripple(x: float, z: float, strength: float = 1.0) -> void:
	ripples.pop_front()
	ripples.append(Vector4(x, z, Game.sim_time, strength))


# --- Scenery -----------------------------------------------------------------------

func _branch(from: Vector3, to: Vector3, r0: float, r1: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var length := from.distance_to(to)
	cm.height = length
	cm.bottom_radius = r0
	cm.top_radius = r1
	cm.radial_segments = 10
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = mat
	var dir := (to - from).normalized()
	var bas := Basis()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.001:
		bas = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	mi.transform = Transform3D(bas, (from + to) * 0.5)
	add_child(mi)


func _build_wood() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = WOOD
	var base := Vector3(-2.6, floor_height(-2.6, -0.9) - 0.2, -0.9)
	var trunk_top := Vector3(-1.4, 3.6, -1.1)
	_branch(base, trunk_top, 0.42, 0.26, mat)
	_branch(trunk_top, Vector3(1.6, 6.0, -1.4), 0.26, 0.1, mat)
	_branch(trunk_top, Vector3(-3.4, 5.9, -1.3), 0.2, 0.08, mat)
	_branch(Vector3(-0.2, 4.4, -1.2), Vector3(0.9, 3.3, -0.5), 0.14, 0.06, mat)
	_branch(base + Vector3(0.2, 0.3, 0.1), Vector3(1.8, 1.2, 0.2), 0.22, 0.09, mat)
	_branch(Vector3(0.6, 0.9, 0.0), Vector3(2.2, 2.0, -0.6), 0.12, 0.05, mat)
	_branch(base + Vector3(0.1, 0.4, 0), Vector3(-4.6, 1.6, -0.2), 0.2, 0.08, mat)
	_branch(Vector3(-1.9, 2.4, -1.0), Vector3(-3.3, 3.9, -0.6), 0.13, 0.05, mat)


func _build_rocks() -> void:
	var spots := [
		[Vector3(3.6, 0, -0.6), Vector3(1.4, 1.5, 1.1)],
		[Vector3(4.7, 0, -1.3), Vector3(1.0, 1.9, 0.9)],
		[Vector3(2.7, 0, 0.6), Vector3(0.8, 0.7, 0.7)],
		[Vector3(-4.2, 0, 0.7), Vector3(0.8, 0.6, 0.7)],
		[Vector3(-3.0, 0, 1.1), Vector3(0.5, 0.4, 0.5)],
		[Vector3(1.4, 0, 1.6), Vector3(0.35, 0.25, 0.3)],
	]
	var i := 0
	for s in spots:
		var p: Vector3 = s[0]
		var sc: Vector3 = s[1]
		var mat := ShaderMaterial.new()
		mat.shader = ROCK
		mat.set_shader_parameter("seed", float(i) * 13.7)
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 24
		sm.rings = 12
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = mat
		mi.scale = sc
		mi.rotation.y = i * 1.3
		mi.position = Vector3(p.x, floor_height(p.x, p.z) + sc.y * 0.25, p.z)
		add_child(mi)
		i += 1


## A single plant blade: a tapered strip of `seg` segments, 1 unit tall, curving forward.
func _blade_mesh(kind: String) -> ArrayMesh:
	var seg := 6
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in seg + 1:
		var t := float(i) / seg
		var w := 0.5 * pow(1.0 - t, 0.8)
		if kind == "leaf":
			w = 0.5 * sin(PI * (t * 0.85 + 0.12))
		var z := 0.18 * t * t
		v.append(Vector3(-w, t, z))
		v.append(Vector3(w, t, z))
		n.append(Vector3(0, 0.2, 1).normalized())
		n.append(Vector3(0, 0.2, 1).normalized())
		uv.append(Vector2(0, t))
		uv.append(Vector2(1, t))
	for i in seg:
		var a := i * 2
		idx.append_array([a, a + 1, a + 3, a, a + 3, a + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## A stem plant (like rotala or ludwigia): thin stem with crossed pairs of oval leaves, 1 unit tall.
func _stem_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var nodes := 9
	for k in nodes:
		var t := (float(k) + 0.6) / nodes
		var ang := k * PI * 0.5
		var leaf_len := 0.16 * (1.0 - 0.45 * t)
		for side in [-1.0, 1.0]:
			var dir := Vector3(cos(ang) * side, 0.0, sin(ang) * side)
			var up := Vector3(0, 1, 0)
			var tip := dir * leaf_len + up * leaf_len * 0.45
			var mid := (tip) * 0.5
			var wdir := dir.cross(up).normalized() * leaf_len * 0.28
			var base := Vector3(0, t, 0)
			var i0 := v.size()
			for p in [Vector3.ZERO, mid + wdir, tip, mid - wdir]:
				v.append(base + p)
				n.append((up + dir * 0.3).normalized())
				uv.append(Vector2(0.5, t))
			idx.append_array([i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3])
	# The stem itself: a thin ribbon.
	var i1 := v.size()
	for p in [Vector3(-0.012, 0, 0), Vector3(0.012, 0, 0), Vector3(0.012, 1.0, 0), Vector3(-0.012, 1.0, 0)]:
		v.append(p)
		n.append(Vector3(0, 0, 1))
		uv.append(Vector2(0.5, p.y))
	idx.append_array([i1, i1 + 1, i1 + 2, i1, i1 + 2, i1 + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Scatters `count` blades around cluster centres. Each entry of `clusters` is [x, z, radius].
func _plant_patch(kind: String, count: int, clusters: Array, height: Vector2, width: Vector2,
		col_a: Color, col_b: Color, sway: float, avoid_path := false) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _stem_mesh() if kind == "stem" else _blade_mesh(kind)
	var placed := []
	var tries := 0
	while placed.size() < count and tries < count * 20:
		tries += 1
		var c: Array = clusters[rng.randi() % clusters.size()]
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * float(c[2])
		var x: float = clampf(float(c[0]) + cos(ang) * r, -X_HALF + 0.15, X_HALF - 0.15)
		var z: float = clampf(float(c[1]) + sin(ang) * r, -Z_HALF + 0.15, Z_HALF - 0.15)
		# Keep a sandy path open in the middle-front, as in the concept.
		if avoid_path and absf(x - 0.3) < 1.4 + (z - 0.5) * 0.3 and z > -0.2:
			continue
		placed.append(Vector3(x, floor_height(x, z) - 0.05, z))
	mm.instance_count = placed.size()
	for i in placed.size():
		var h := rng.randf_range(height.x, height.y)
		var w := rng.randf_range(width.x, width.y)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, h, w))
		b = Basis(Vector3(1, 0, 0), rng.randf_range(-0.15, 0.15)) * b
		mm.set_instance_transform(i, Transform3D(b, placed[i]))
		mm.set_instance_color(i, col_a.lerp(col_b, rng.randf()))
	var mat := ShaderMaterial.new()
	mat.shader = PLANT
	mat.set_shader_parameter("sway", sway)
	plant_mats.append(mat)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)


func _build_plants() -> void:
	# Tall grass along the back.
	_plant_patch("grass", 90, [[-4.8, -1.9, 1.2], [-1.0, -2.0, 1.4], [2.4, -2.0, 1.2], [5.0, -1.8, 0.8]],
		Vector2(2.5, 5.4), Vector2(0.07, 0.11), Color(0.14, 0.42, 0.08), Color(0.36, 0.62, 0.14), 0.1)
	# Red stem plants, right-back and left-mid.
	_plant_patch("stem", 150, [[4.6, -1.0, 1.1], [3.2, -1.9, 0.9], [-5.0, 0.0, 0.9], [-3.4, -1.6, 0.8]],
		Vector2(1.4, 3.6), Vector2(1.6, 2.4), Color(0.5, 0.06, 0.05), Color(0.85, 0.24, 0.12), 0.08)
	# Bright green stem plants on the sides.
	_plant_patch("stem", 150, [[-5.3, 1.0, 0.9], [5.3, 0.6, 0.9], [-0.2, -1.6, 1.0], [1.8, -1.2, 0.8]],
		Vector2(0.9, 2.6), Vector2(1.4, 2.0), Color(0.22, 0.52, 0.08), Color(0.5, 0.78, 0.16), 0.09)
	# Dense carpet across the front, leaving a sand path in the middle.
	_plant_patch("leaf", 1600, [[-3.5, 0.9, 2.6], [3.5, 0.9, 2.6], [0.0, -0.6, 2.0]],
		Vector2(0.12, 0.32), Vector2(0.07, 0.11), Color(0.2, 0.5, 0.06), Color(0.45, 0.78, 0.15), 0.04, true)


func _build_rays() -> void:
	var spots := [[-3.6, 2.2, -0.5], [-1.6, 1.4, -1.2], [0.4, 2.6, 0.2], [2.6, 1.6, -0.8], [4.2, 1.2, 0.4]]
	var i := 0
	for s in spots:
		var mat := ShaderMaterial.new()
		mat.shader = RAYS
		mat.set_shader_parameter("seed", float(i) * 2.3)
		mat.set_shader_parameter("strength", 0.13 + 0.05 * (i % 2))
		var mi := _quad(Vector2(float(s[1]), 8.0), Vector3(float(s[0]), WATER_Y - 4.0, float(s[2])), Vector3(0, 0, -14), mat)
		mi.name = "Ray%d" % i
		i += 1


func _particle_material(kind: int, color: Color, strength: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PARTICLE
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("strength", strength)
	return mat


func make_bubbles(amount: int, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 5.0
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.12, 0.12)
	p.mesh = qm
	p.material_override = _particle_material(1, Color(0.85, 0.95, 1.0), 0.9)
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.35, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0.7))
	p.color_ramp = g
	return p


func _build_particles() -> void:
	var motes := CPUParticles3D.new()
	motes.amount = 260
	motes.lifetime = 14.0
	motes.preprocess = 14.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.05, 0.05)
	motes.mesh = qm
	motes.material_override = _particle_material(0, Color(1.0, 0.88, 0.55), 1.4)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(X_HALF - 0.2, 3.0, Z_HALF - 0.3)
	motes.position = Vector3(0, 3.5, 0)
	motes.direction = Vector3(1, 0.2, 0)
	motes.spread = 180.0
	motes.initial_velocity_min = 0.02
	motes.initial_velocity_max = 0.12
	motes.gravity = Vector3(0, -0.01, 0)
	motes.scale_amount_min = 0.4
	motes.scale_amount_max = 1.3
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.2, Color(1, 1, 1, 1))
	g.add_point(0.8, Color(1, 1, 1, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	motes.color_ramp = g
	add_child(motes)

	# Air stone in the back right corner.
	var air := make_bubbles(36, false)
	air.position = Vector3(5.2, floor_height(5.2, -1.9) + 0.1, -1.9)
	add_child(air)


func _build_leaves() -> void:
	leaf_mm = MultiMesh.new()
	leaf_mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.4, 0.4)
	leaf_mm.mesh = pm
	leaf_mm.instance_count = 16
	for i in 16:
		leaves.append({
			"pos": Vector3(rng.randf_range(-5.5, 5.5), WATER_Y - 0.06, rng.randf_range(-2.2, 2.2)),
			"vel": Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.03, 0.03)),
			"rot": rng.randf() * TAU,
			"spin": rng.randf_range(-0.1, 0.1),
			"size": rng.randf_range(0.6, 1.3),
		})
	var mat := ShaderMaterial.new()
	mat.shader = LEAF
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = leaf_mm
	mmi.material_override = mat
	add_child(mmi)


func _process(delta: float) -> void:
	# Leaves drift and get pushed by the hand.
	for i in leaves.size():
		var l: Dictionary = leaves[i]
		var cur := Game.current_at(l.pos)
		l.vel = l.vel.lerp(Vector3(cur.x, 0, cur.z) * 0.6, 1.0 - exp(-delta * 1.5))
		l.vel += Vector3(sin(Game.sim_time * 0.1 + i), 0, cos(Game.sim_time * 0.13 + i * 2.0)) * 0.004 * delta
		l.pos += l.vel * delta + Vector3(0.03, 0, 0.0) * delta * sin(i)
		if absf(l.pos.x) > X_HALF - 0.3:
			l.pos.x = clampf(l.pos.x, -X_HALF + 0.3, X_HALF - 0.3)
			l.vel.x *= -0.5
		if absf(l.pos.z) > Z_HALF - 0.3:
			l.pos.z = clampf(l.pos.z, -Z_HALF + 0.3, Z_HALF - 0.3)
			l.vel.z *= -0.5
		l.rot += l.spin * delta
		var b := Basis(Vector3.UP, l.rot).scaled(Vector3.ONE * float(l.size))
		leaf_mm.set_instance_transform(i, Transform3D(b, l.pos + Vector3(0, sin(Game.sim_time + i) * 0.01, 0)))

	# Plants bend with the strongest hand current.
	var c := Game.strongest_current()
	for m in plant_mats:
		if c.is_empty():
			m.set_shader_parameter("stir_vel", Vector3.ZERO)
		else:
			m.set_shader_parameter("stir_pos", c.pos)
			m.set_shader_parameter("stir_vel", c.vel * clampf(c.life / 1.6, 0.0, 1.0))

	_update_reflection()
	surface_mat.set_shader_parameter("ripples", ripples)
	surface_mat.set_shader_parameter("now", Game.sim_time)
	var cl := Game.cloudiness
	sand_mat.set_shader_parameter("cloudiness", cl)
	back_mat.set_shader_parameter("cloudiness", cl)
	surface_mat.set_shader_parameter("cloudiness", cl)
	env.fog_density = 0.35 + cl * 1.2
	env.fog_depth_begin = lerpf(14.0, 8.0, cl)
