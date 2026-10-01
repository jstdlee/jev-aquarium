extends Node
## Scripted input for automated tests, so tests never touch the real desktop.
## Usage: godot ... -- --steps="wait:30;move:800,400;dclick:800,400;shot:/tmp/a.png;quit"
## Steps: wait:N (frames)  sleep:S (seconds)  move:x,y  click:x,y  dclick:x,y  tclick:x,y
##        drag:x1,y1,x2,y2,frames  key:esc|f1  speed:N  shot:path  quit
##        stock:goldfish=1,neon=8  (fixed population)   cam:x,y,z,fov  (move the camera, for close-ups)

var steps: Array = []
var wait_frames := 0
var wait_until := -1.0
var drag := {}
var busy := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--steps="):
			steps = Array(a.substr(8).split(";", false))


func _process(_delta: float) -> void:
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
		"quit":
			Game.save_game()
			get_tree().quit()


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
