extends Node
## Scripted input for automated tests, so tests never touch the real desktop.
## Usage: godot ... -- --steps="wait:30;move:800,400;dclick:800,400;shot:/tmp/a.png;quit"
## Steps: wait:N (frames)  sleep:S (seconds)  move:x,y  click:x,y  dclick:x,y  tclick:x,y
##        drag:x1,y1,x2,y2,frames  key:esc|f1  speed:N  shot:path  quit
##        stock:goldfish=1,neon=8  (fixed population)   cam:x,y,z,fov  (move the camera, for close-ups)
##        log:path  (write every fish's motion each frame as CSV, until quit)
## With --fixed-fps / --write-movie, use wait:N (frames); sleep uses wall-clock time.

var steps: Array = []
var wait_frames := 0
var wait_until := -1.0
var drag := {}
var busy := false
var log_file: FileAccess
var follow_species := ""
var frame := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--steps="):
			steps = Array(a.substr(8).split(";", false))


func _process(_delta: float) -> void:
	frame += 1
	if log_file:
		_log_frame()
	if follow_species != "":
		_follow()
	if busy or (steps.is_empty() and drag.is_empty()):
		return
	if not drag.is_empty():
		_drag_step()
		return
	if wait_frames > 0:
		wait_frames -= 1
		return
	if wait_until > 0.0:
		if Time.get_ticks_msec() / 1000.0 < wait_until:
			return
		wait_until = -1.0
	var step: String = steps.pop_front()
	var parts := step.split(":", true, 1)
	var cmd := parts[0]
	var arg := parts[1] if parts.size() > 1 else ""
	var nums: Array = Array(arg.split(",", false)).map(func(s): return float(s))
	match cmd:
		"wait":
			wait_frames = int(arg)
		"sleep":
			wait_until = Time.get_ticks_msec() / 1000.0 + float(arg)
		"move":
			_motion(Vector2(nums[0], nums[1]), Vector2.ZERO)
		"click":
			_click(Vector2(nums[0], nums[1]), 1)
		"dclick":
			_click(Vector2(nums[0], nums[1]), 2)
		"tclick":
			_click(Vector2(nums[0], nums[1]), 3)
		"drag":
			drag = {"a": Vector2(nums[0], nums[1]), "b": Vector2(nums[2], nums[3]), "n": int(nums[4]), "i": 0}
			_button(drag.a, true)
		"key":
			var ev := InputEventKey.new()
			ev.keycode = {"esc": KEY_ESCAPE, "f1": KEY_F1}[arg]
			ev.pressed = true
			Input.parse_input_event(ev)
		"speed":
			Game.settings.time_scale = float(arg)
		"stock":
			Game.settings.population_mode = "fixed"
			for id in Game.settings.fixed_counts:
				Game.settings.fixed_counts[id] = 0
			for kv in arg.split(","):
				var p := kv.split("=")
				Game.settings.fixed_counts[p[0]] = int(p[1])
			Game.generate_population()
		"cam":
			var cam := get_viewport().get_camera_3d()
			cam.position = Vector3(nums[0], nums[1], nums[2])
			cam.fov = nums[3]
		"shot":
			busy = true
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png(arg)
			print("screenshot: ", arg)
			busy = false
		"follow":
			follow_species = arg
		"beats":
			for f in get_tree().current_scene.fishes:
				if f.spine and f.anim:
					print("BEATS ", f.rec.species, " ", f.spine.measure_beats(f.anim))
		"spines":
			for f in get_tree().current_scene.fishes:
				if f.spine:
					print("SPINE ", f.rec.species, " ", f.spine.describe())
		"log":
			log_file = FileAccess.open(arg, FileAccess.WRITE)
			log_file.store_line("frame,t,id,species,x,y,z,speed,yaw,pitch,yaw_rate,roll,effort,anim_speed,hover,inside")
		"quit":
			if log_file:
				log_file.close()
			Game.save_game()
			get_tree().quit()


func _log_frame() -> void:
	var main := get_tree().current_scene
	var space: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	var probe := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	probe.shape = sphere
	for f in main.fishes:
		if f.dead:
			continue
		var p: Vector3 = f.position
		var a: float = f.anim.speed_scale if f.anim else 0.0
		# Is the fish's core inside wood, rock or a decoration?
		sphere.radius = f.length * 0.12
		probe.transform = Transform3D(Basis(), p)
		var inside := 0 if space.intersect_shape(probe, 1).is_empty() else 1
		log_file.store_line("%d,%.4f,%d,%s,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%d" % [
			frame, Game.sim_time, f.rec.id, f.rec.species, p.x, p.y, p.z, f.speed, f.yaw, f.pitch,
			f.yaw_rate, f.roll, f.effort, a, 1 if f.hover_t > 0.0 else 0, inside])


## Close-up camera that tracks the first fish of a species from a little in front of the glass.
func _follow() -> void:
	var main := get_tree().current_scene
	for f in main.fishes:
		if f.rec.species == follow_species and not f.dead:
			var cam := get_viewport().get_camera_3d()
			var L: float = f.length
			cam.fov = 40.0
			var target: Vector3 = f.global_position
			cam.global_position = cam.global_position.lerp(target + Vector3(0, L * 0.6, L * 3.4), 0.2)
			cam.look_at(target, Vector3.UP)
			return


func _motion(pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = rel
	Input.parse_input_event(ev)


func _button(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos
	ev.global_position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _click(pos: Vector2, count: int) -> void:
	_motion(pos, Vector2.ZERO)
	for i in count:
		_button(pos, true)
		_button(pos, false)


func _drag_step() -> void:
	var i: int = drag.i
	var n: int = drag.n
	var prev: Vector2 = drag.a.lerp(drag.b, float(i) / n)
	var cur: Vector2 = drag.a.lerp(drag.b, float(i + 1) / n)
	_motion(cur, cur - prev)
	drag.i = i + 1
	if drag.i >= n:
		_button(drag.b, false)
		drag = {}
