extends Node3D
## Real scenery: scanned driftwood and rocks (Poly Haven, CC0) and artist-made aquarium plants
## (Sketchfab, CC-BY), prepared by tools/prep_scenery.py into assets/scenery/ (base at origin,
## largest dimension 1). This script lays them out in the Lantern Garden composition.
## Repeated plants are drawn with MultiMesh and sway; solid pieces register obstacles for the fish.

const DIR := "res://assets/scenery/"
# Pieces whose source uses the spec-gloss material that Blender drops: take the material from the
# original file instead (UVs survive the polygon reduction).
const MATERIAL_FROM := {"driftwood": "res://assets/raw/real_aquarium_wood_3d_scan.glb"}
const CAUSTICS := preload("res://shaders/caustics_overlay.gdshader")

var tank: Node3D
var obstacles: Array = []  # {pos: Vector3, radius: float}
var _sway: Array = []  # {mm, base: Array[Transform3D], phase: Array[float], amount}
var _caustic_mat: ShaderMaterial
var rng := RandomNumberGenerator.new()

# Hardscape: [piece, x, z, yaw°, size, sink (fraction of height), tilt° about x, tilt° about z, obstacle radius (0 = none)]
const HARDSCAPE := [
	["driftwood", -1.4, -0.7, 170.0, 7.2, 0.1, -12.0, -28.0, 0.0],
	["quiver_branch", -3.4, -1.3, 30.0, 3.4, 0.05, 0.0, -10.0, 0.0],
	["trunk", 1.4, -1.5, -12.0, 4.6, 0.15, 0.0, 24.0, 0.0],
	["branch_a", 0.4, 0.2, 60.0, 2.2, 0.2, 0.0, 0.0, 0.0],
	["branch_b", -4.2, 0.4, -40.0, 1.6, 0.25, 0.0, 0.0, 0.0],
	["dragon_stones", 3.7, -0.6, -18.0, 3.6, 0.1, 0.0, 0.0, 1.1],
	["boulder", 4.8, -1.6, 40.0, 2.0, 0.15, 0.0, 0.0, 0.9],
	["moss_rock_4", -4.6, -1.6, 10.0, 1.6, 0.12, 0.0, 0.0, 0.7],
	["moss_rock_1", 2.5, 0.8, 75.0, 1.1, 0.2, 0.0, 0.0, 0.5],
	["moss_rock_3", -4.4, 0.9, -30.0, 1.0, 0.2, 0.0, 0.0, 0.45],
	["moss_stone_9", -2.9, 1.4, 15.0, 0.7, 0.2, 0.0, 0.0, 0.0],
	["moss_stone_12", 5.0, 0.7, -60.0, 0.9, 0.2, 0.0, 0.0, 0.4],
	["moss_stone_8", 1.6, 1.6, 30.0, 0.45, 0.25, 0.0, 0.0, 0.0],
	["moss_stone_10", -0.9, 1.8, 100.0, 0.4, 0.25, 0.0, 0.0, 0.0],
	["shell", 0.9, 1.75, 35.0, 0.35, 0.15, 0.0, 0.0, 0.0],
	["anubias", -1.9, -0.2, 20.0, 1.3, 0.05, 0.0, 0.0, 0.0],
	["anubias", 3.0, -0.2, -50.0, 1.1, 0.05, 0.0, 0.0, 0.0],
]

# Planted groups: [piece, count, [[x, z, radius], ...], size range, sway, sink, avoid sand path]
const PLANTS := [
	["vallisneria", 12, [[-4.8, -2.0, 1.0], [-0.8, -2.1, 0.9], [3.6, -2.0, 0.8]], Vector2(1.6, 3.6), 0.05, 0.05, false],
	["fern_big", 7, [[-5.2, -1.0, 0.8], [5.2, -0.6, 0.6], [0.2, -1.8, 1.4]], Vector2(1.4, 2.0), 0.03, 0.05, false],
	["pack_universal", 10, [[-5.3, 0.0, 0.8], [5.4, 0.1, 0.6], [2.2, -1.9, 0.8]], Vector2(1.5, 2.2), 0.04, 0.05, false],
	["java_fern", 12, [[-2.6, -0.8, 1.2], [-0.2, -0.9, 1.0], [4.3, 0.3, 0.8], [-5.0, 1.0, 0.5]], Vector2(0.9, 1.5), 0.05, 0.05, false],
	["red_tiger_lotus", 3, [[-3.2, -0.2, 0.6], [4.4, -1.0, 0.5]], Vector2(1.2, 1.6), 0.03, 0.18, false],
	["fern_wide", 6, [[-3.8, 1.3, 0.8], [3.6, 1.3, 0.9]], Vector2(0.9, 1.3), 0.03, 0.05, true],
	["staurogyne", 120, [[-3.6, 1.2, 2.4], [3.6, 1.2, 2.4], [0.0, -0.2, 1.6]], Vector2(0.5, 0.95), 0.05, 0.1, true],
	["staurogyne_b", 100, [[-3.6, 1.2, 2.4], [3.6, 1.2, 2.4], [0.0, -0.2, 1.6]], Vector2(0.5, 0.95), 0.05, 0.1, true],
]


func setup(t: Node3D) -> void:
	tank = t
	rng.seed = 11
	_caustic_mat = ShaderMaterial.new()
	_caustic_mat.shader = CAUSTICS
	for h in HARDSCAPE:
		_place(h)
	for p in PLANTS:
		_plant_group(p)


func _piece(name: String) -> Array:
	## Returns [mesh, materials] from a prepared GLB (one mesh each).
	var scene: PackedScene = load(DIR + name + ".glb")
	var inst := scene.instantiate()
	var mi := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh: Mesh = mi.mesh
	var src_mi := mi
	var src_inst: Node = null
	if MATERIAL_FROM.has(name):
		src_inst = (load(MATERIAL_FROM[name]) as PackedScene).instantiate()
		src_mi = src_inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mats := []
	for i in mesh.get_surface_count():
		var m := src_mi.get_active_material(mini(i, src_mi.mesh.get_surface_count() - 1))
		if m:
			m = m.duplicate()
			m.next_pass = _caustic_mat  # sunlight caustics on every piece
		mats.append(m)
	inst.free()
	if src_inst:
		src_inst.free()
	return [mesh, mats]


func _place(h: Array) -> void:
	var p := _piece(h[0])
	var mi := MeshInstance3D.new()
	mi.mesh = p[0]
	for i in p[1].size():
		mi.set_surface_override_material(i, p[1][i])
	var size: float = h[4]
	var x: float = h[1]
	var z: float = h[2]
	var aabb: AABB = mi.mesh.get_aabb()
	var b := Basis(Vector3.UP, deg_to_rad(h[3]))
	b = Basis(Vector3.RIGHT, deg_to_rad(h[6])) * Basis(Vector3.BACK, deg_to_rad(h[7])) * b
	b = b.scaled(Vector3.ONE * size)
	var y: float = tank.floor_height(x, z) - aabb.size.y * size * float(h[5])
	mi.transform = Transform3D(b, Vector3(x, y, z))
	add_child(mi)
	var r: float = h[8]
	if r > 0.0:
		obstacles.append({"pos": Vector3(x, y + aabb.size.y * size * 0.45, z), "radius": r})


func _plant_group(g: Array) -> void:
	var p := _piece(g[0])
	var count: int = g[1]
	var clusters: Array = g[2]
	var size_r: Vector2 = g[3]
	var avoid_path: bool = g[6]
	# Put the (caustics-enabled) materials on a copy of the mesh so every surface keeps its own.
	var mesh: Mesh = (p[0] as Mesh).duplicate()
	for i in p[1].size():
		if p[1][i]:
			mesh.surface_set_material(i, p[1][i])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var aabb: AABB = mesh.get_aabb()
	var placed: Array = []
	var tries := 0
	while placed.size() < count and tries < count * 30:
		tries += 1
		var c: Array = clusters[rng.randi() % clusters.size()]
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * float(c[2])
		var x := clampf(float(c[0]) + cos(ang) * r, -5.7, 5.7)
		var z := clampf(float(c[1]) + sin(ang) * r, -2.2, 2.2)
		if avoid_path and absf(x - 0.3) < 1.3 + (z - 0.4) * 0.35 and z > -0.3:
			continue
		var s := rng.randf_range(size_r.x, size_r.y)
		var y: float = tank.floor_height(x, z) - aabb.size.y * s * float(g[5])
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		placed.append(Transform3D(b, Vector3(x, y, z)))
	mm.instance_count = placed.size()
	var phases := []
	for i in placed.size():
		mm.set_instance_transform(i, placed[i])
		phases.append(rng.randf() * TAU)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	_sway.append({"mm": mm, "base": placed, "phase": phases, "amount": float(g[4])})


func _process(_delta: float) -> void:
	# Gentle sway, plus a lean when the hand stirs the water nearby.
	var t := Game.sim_time
	var cur := Game.strongest_current()
	for s in _sway:
		var mm: MultiMesh = s.mm
		var amount: float = s.amount
		for i in mm.instance_count:
			var base: Transform3D = s.base[i]
			var ph: float = s.phase[i]
			var lean := Vector2(sin(t * 0.7 + ph), cos(t * 0.5 + ph * 1.3) * 0.6) * amount
			if not cur.is_empty():
				var d2: float = base.origin.distance_squared_to(cur.pos)
				var push: Vector3 = cur.vel * exp(-d2 / 3.0) * clampf(cur.life / 1.6, 0.0, 1.0) * 0.12
				lean += Vector2(push.x, push.z)
			var rot := Basis(Vector3.BACK, -lean.x) * Basis(Vector3.RIGHT, lean.y)
			mm.set_instance_transform(i, Transform3D(rot * base.basis, base.origin))
