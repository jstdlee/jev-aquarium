extends Node3D
## Dev tool: close-up side and 3/4 portraits of every species under tank-like light,
## to judge eyes, materials and animation poses. Saves <out>/<species>.png
## godot --path . tools/fish_gallery.tscn -- --out=/tmp/dir

const SpeciesDB = preload("res://scripts/species.gd")
var out := "/tmp"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.8, 0.88)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.88, 0.9)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.7
	sun.rotation_degrees = Vector3(-62, -28, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30
	add_child(cam)
	cam.current = true
	for id in SpeciesDB.ORDER:
		var spec: Dictionary = SpeciesDB.get_spec(id)
		if not spec.has("model"):
			continue
		var m: Dictionary = spec.model
		var model: Node3D = (load(m.path) as PackedScene).instantiate()
		var holder := Node3D.new()
		var s: float = float(spec.length) / float(m.size)
		holder.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(m.yaw))).scaled(Vector3.ONE * s), Vector3.ZERO)
		model.position = -m.center
		holder.add_child(model)
		add_child(holder)
		var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and not ap.get_animation_list().is_empty():
			ap.play(ap.get_animation_list()[0])
			ap.seek(0.3, true)
		var L: float = spec.length
		# Head faces -Z: side view from +X, then a 3/4 front view.
		cam.look_at_from_position(Vector3(L * 2.6, 0.0, 0.0), Vector3.ZERO, Vector3.UP)
		await _shot("%s/%s_side.png" % [out, id])
		cam.look_at_from_position(Vector3(L * 1.4, L * 0.2, -L * 1.6), Vector3(0, 0, -L * 0.25), Vector3.UP)
		await _shot("%s/%s_face.png" % [out, id])
		holder.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _shot(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
