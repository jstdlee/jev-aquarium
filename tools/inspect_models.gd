extends Node3D
## Dev tool: renders each fish model from the side and from above with axis markers,
## and prints its bounds and animations, to work out orientation and scale.
## godot --path . tools/inspect_models.tscn -- --out=/tmp/dir

var out := "/tmp"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.38, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(cam)
	cam.current = true
	var files := DirAccess.get_files_at("res://assets/raw")
	for f in files:
		if not f.ends_with(".glb"):
			continue
		var scene: PackedScene = load("res://assets/raw/" + f)
		var inst: Node3D = scene.instantiate()
		add_child(inst)
		await get_tree().process_frame
		var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var anims := []
		if ap:
			anims = ap.get_animation_list()
		var box := AABB()
		var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			box = bb if first else box.merge(bb)
			first = false
		print("MODEL ", f, " aabb_pos=", box.position, " size=", box.size, " anims=", anims)
		var axes := _axes(box)
		add_child(axes)
		var c := box.get_center()
		var span := maxf(box.size.x, maxf(box.size.y, box.size.z)) * 1.3
		cam.size = span
		# Side view: looking down -Z (from +Z). Then top view: looking down from +Y.
		cam.look_at_from_position(c + Vector3(0, 0, span * 3.0), c, Vector3.UP)
		await _shot(out + "/" + f.get_basename() + "_front.png")
		cam.look_at_from_position(c + Vector3(0, span * 3.0, 0.001), c, Vector3.FORWARD)
		await _shot(out + "/" + f.get_basename() + "_top.png")
		inst.queue_free()
		axes.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _shot(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


## Red = +X, green = +Y, blue = +Z, drawn from the model's centre.
func _axes(box: AABB) -> Node3D:
	var n := Node3D.new()
	var c := box.get_center()
	var len := maxf(box.size.x, maxf(box.size.y, box.size.z)) * 0.6
	for d in [[Vector3.RIGHT, Color.RED], [Vector3.UP, Color.GREEN], [Vector3.BACK, Color.BLUE]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var dir: Vector3 = d[0]
		bm.size = Vector3.ONE * len * 0.03 + dir.abs() * len
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = d[1]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mi.material_override = mat
		mi.position = c + dir * len * 0.5
		n.add_child(mi)
	return n
