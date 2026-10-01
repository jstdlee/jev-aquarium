extends Node3D
## Dev tool: render GLB files side-on with their first animation playing, auto-framed.
## godot --path . tools/render_glb.tscn -- --out=/tmp/x.png --files=res://a.glb,res://b.glb --time=1.0
func _ready() -> void:
	var out := "/tmp/r.png"
	var files: PackedStringArray = []
	var t := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		elif a.begins_with("--files="): files = a.substr(8).split(",")
		elif a.begins_with("--time="): t = float(a.substr(7))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.8, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); add_child(sun)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; add_child(cam); cam.current = true
	var x := 0.0
	var boxes := []
	for f in files:
		var inst: Node3D = (load(f) as PackedScene).instantiate()
		add_child(inst)
		var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			ap.play(ap.get_animation_list()[0]); ap.seek(t, true)
		await get_tree().process_frame
		var bb := AABB(); var first := true
		# Skinned AABBs are unreliable; frame by the skeleton's bone positions instead.
		var skel := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for b in skel.get_bone_count():
			var p := skel.global_transform * skel.get_bone_global_pose(b).origin
			bb = AABB(p, Vector3.ZERO) if first else bb.expand(p)
			first = false
		inst.position.x = x - bb.position.x
		x += bb.size.x + bb.size.length() * 0.3
		boxes.append(bb)
	await get_tree().process_frame
	var span := x
	cam.size = span * 0.62
	cam.look_at_from_position(Vector3(span * 0.5, 0, 100), Vector3(span * 0.5, 0, 0), Vector3.UP)
	for i in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
