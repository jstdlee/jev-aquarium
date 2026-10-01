extends Node3D
## Root of the game: builds the tank, spawns fish, and turns mouse input into hand interactions.
##   move          fish notice the "finger on the glass"
##   click         tap the glass: ring + gentle startle (applied only if no second click follows)
##   double click  sprinkle food
##   triple click  bubble burst, and drop the toy ball if there is none
##   drag          stir the water

const Tank = preload("res://scripts/tank.gd")
const Fish = preload("res://scripts/fish.gd")
const SpeciesDB = preload("res://scripts/species.gd")
const Food = preload("res://scripts/food.gd")
const Toy = preload("res://scripts/toy.gd")
const Ring = preload("res://scripts/ring.gd")
const Menu = preload("res://scripts/settings_menu.gd")
const TankPanel = preload("res://scripts/tank_panel.gd")
const RING_SHADER := preload("res://shaders/ring.gdshader")

const MULTI_CLICK := 0.33
const CURSOR_Z := 1.7

var tank: Node3D
var fishes: Array = []
var foods: Array = []
var toy: Node3D = null
var menu: CanvasLayer
var toast: Label

var _school_targets := {}
var _school_timer := 0.0
var _click_count := 0
var _last_click := -10.0
var _pending_tap := {}
var _pressing := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _finger: MeshInstance3D
var _finger_mat: ShaderMaterial
var _toast_t := 0.0


func _ready() -> void:
	tank = Tank.new()
	add_child(tank)
	_build_finger()
	_build_ui()
	Game.population_reset.connect(_respawn_all)
	Game.fish_added.connect(_spawn)
	Game.fish_removed.connect(_on_fish_removed)
	Game.extras_changed.connect(_apply_toy)
	Game.fish_died.connect(_on_fish_died)
	_respawn_all()
	_apply_toy()
	if not Game.offline_deaths.is_empty():
		var names := ", ".join(PackedStringArray(Game.offline_deaths.map(func(r): return r.name)))
		_show_toast("While you were away, %s passed away. They are remembered in the settings menu." % names)


func _build_finger() -> void:
	_finger = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	_finger.mesh = q
	_finger_mat = ShaderMaterial.new()
	_finger_mat.shader = RING_SHADER
	_finger_mat.set_shader_parameter("mode", 1)
	_finger_mat.set_shader_parameter("strength", 0.0)
	_finger.material_override = _finger_mat
	_finger.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_finger)


func _build_ui() -> void:
	menu = Menu.new()
	add_child(menu)
	add_child(TankPanel.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.anchor_left = 0.2
	toast.anchor_right = 0.8
	toast.anchor_top = 0.88
	toast.anchor_bottom = 0.96
	toast.add_theme_font_size_override("font_size", 20)
	toast.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
	toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	toast.add_theme_constant_override("shadow_offset_x", 1)
	toast.add_theme_constant_override("shadow_offset_y", 2)
	toast.modulate.a = 0.0
	layer.add_child(toast)


func _show_toast(text: String) -> void:
	toast.text = text
	_toast_t = 7.0


# --- Population ------------------------------------------------------------------------

func _respawn_all() -> void:
	for f in fishes:
		f.queue_free()
	fishes.clear()
	for rec in Game.alive_records():
		_spawn(rec)


func _spawn(rec: Dictionary) -> void:
	var sp: Dictionary = SpeciesDB.get_spec(rec.species)
	var d: Vector2 = sp.depth
	# Pick a start point in open water, not inside wood or rock.
	var start := Vector3.ZERO
	var space := get_world_3d().direct_space_state
	var probe := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = float(sp.length) * 0.6
	probe.shape = sphere
	for attempt in 20:
		start = Vector3(randf_range(-4.8, 4.8), randf_range(d.x, d.y), randf_range(-1.4, 1.4))
		start.y = maxf(start.y, tank.floor_height(start.x, start.z) + 0.6)
		probe.transform = Transform3D(Basis(), start)
		if space.intersect_shape(probe, 1).is_empty():
			break
	var f := Fish.new()
	add_child(f)
	f.setup(rec, self, start)
	fishes.append(f)


func _on_fish_removed(rec: Dictionary) -> void:
	for f in fishes:
		if f.rec == rec:
			remove_fish(f)
			return


func _apply_toy() -> void:
	var want: bool = Game.settings.extras.get("toy", false)
	if want and toy == null:
		_drop_toy(Vector3(randf_range(-3.0, 3.0), 4.0, 0.6))
	elif not want and toy != null:
		toy.queue_free()
		toy = null


func _on_fish_died(rec: Dictionary, offline: bool) -> void:
	if not offline:
		_show_toast("%s the %s has passed away." % [rec.name, SpeciesDB.get_spec(rec.species).name])


func remove_fish(f: Node) -> void:
	fishes.erase(f)
	f.queue_free()


func school_target(species: String) -> Vector3:
	if not _school_targets.has(species):
		_school_targets[species] = _random_school_point(species)
	return _school_targets[species]


func _random_school_point(species: String) -> Vector3:
	var d: Vector2 = SpeciesDB.get_spec(species).depth
	return Vector3(randf_range(-4.5, 4.5), randf_range(d.x, d.y), randf_range(-1.2, 1.4))


# --- Food and toy ------------------------------------------------------------------------

func nearest_food(p: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius * radius
	for f in foods:
		var d2: float = p.distance_squared_to(f.position)
		if d2 < best_d:
			best_d = d2
			best = f
	return best


func remove_food(f: Node) -> void:
	foods.erase(f)
	f.queue_free()


func drop_food(at: Vector3) -> void:
	var n := 7
	for i in n:
		var food := Food.new()
		add_child(food)
		var x := clampf(at.x + randf_range(-0.45, 0.45), -5.6, 5.6)
		var z := clampf(at.z + randf_range(-0.6, 0.3), -2.0, 2.0)
		food.setup(self, Vector3(x, Tank.WATER_Y - 0.05 - randf() * 0.05, z))
		food.vel = Vector3(0, -randf() * 0.1, 0)
		foods.append(food)
	tank.add_ripple(at.x, at.z, 1.0)
	while foods.size() > 80:
		remove_food(foods[0])


func _bubble_burst(at: Vector3) -> void:
	var b: CPUParticles3D = tank.make_bubbles(28, true)
	b.position = at
	b.emitting = true
	add_child(b)
	get_tree().create_timer(6.0).timeout.connect(b.queue_free)
	for f in fishes:
		f.startle(at, 0.5)


func _drop_toy(at: Vector3) -> void:
	toy = Toy.new()
	add_child(toy)
	toy.setup(self, Vector3(clampf(at.x, -5.0, 5.0), Tank.WATER_Y + 0.4, 0.6))
	tank.add_ripple(toy.position.x, toy.position.z, 1.5)


# --- Input ---------------------------------------------------------------------------------

func _cursor_world(screen: Vector2, plane_z: float) -> Vector3:
	var cam: Camera3D = tank.camera
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.z) < 0.0001:
		return Vector3(0, 3.5, plane_z)
	var t := (plane_z - o.z) / d.z
	var p := o + d * t
	return Vector3(clampf(p.x, -5.8, 5.8), clampf(p.y, 0.4, 6.4), plane_z)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		Game.cursor_pos = _cursor_world(mm.position, CURSOR_Z)
		Game.cursor_seen_at = Game.sim_time
		if _pressing and not _dragging and mm.position.distance_to(_press_pos) > 10.0:
			_dragging = true
			_pending_tap = {}
		if _dragging:
			_stir(mm.position, mm.relative)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_dragging = false
				_press_pos = mb.position
			else:
				_pressing = false
				if not _dragging:
					_on_click(mb.position)
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			menu.toggle()
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE:
				menu.toggle()
			KEY_F1:
				Game.show_debug = not Game.show_debug
			KEY_F11:
				var w := get_window()
				w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _on_click(screen: Vector2) -> void:
	var now := Game.sim_time
	_click_count = _click_count + 1 if now - _last_click < MULTI_CLICK else 1
	_last_click = now
	var glass := _cursor_world(screen, Tank.Z_HALF - 0.02)
	var inside := _cursor_world(screen, CURSOR_Z)
	Game.cursor_pos = inside
	Game.cursor_seen_at = now
	match _click_count:
		1:
			var ring := Ring.new()
			add_child(ring)
			ring.setup(glass, 1.4, 1.2)
			# The startle waits to see whether this click becomes a double click.
			_pending_tap = {"at": inside, "time": now}
		2:
			_pending_tap = {}
			drop_food(inside)
		_:
			_pending_tap = {}
			_bubble_burst(inside)
			if toy == null:
				_drop_toy(inside)
				Game.settings.extras["toy"] = true


func _stir(screen: Vector2, rel: Vector2) -> void:
	var p1 := _cursor_world(screen, 0.6)
	var p0 := _cursor_world(screen - rel, 0.6)
	var dt := maxf(get_process_delta_time(), 1.0 / 240.0)
	var v := ((p1 - p0) / dt).limit_length(6.0) * 0.35
	Game.add_current(p1, v)
	# Sweeping low over the sand clears the cloudiness from uneaten food.
	if p1.y < 1.8:
		Game.cloudiness = maxf(0.0, Game.cloudiness - (p1 - p0).length() * 0.04)


func _process(delta: float) -> void:
	if not _pending_tap.is_empty() and Game.sim_time - float(_pending_tap.time) > MULTI_CLICK:
		for f in fishes:
			f.startle(_pending_tap.at, 0.6)
		_pending_tap = {}

	_school_timer -= delta
	if _school_timer <= 0.0:
		_school_timer = randf_range(5.0, 9.0)
		for sp in _school_targets.keys():
			_school_targets[sp] = _random_school_point(sp)

	# Fingertip glow on the glass while the hand is near.
	var since := Game.sim_time - Game.cursor_seen_at
	_finger.position = Vector3(Game.cursor_pos.x, Game.cursor_pos.y, Tank.Z_HALF - 0.03)
	_finger_mat.set_shader_parameter("strength", clampf(1.0 - since / 2.5, 0.0, 1.0) * 0.35)

	if _toast_t > 0.0:
		_toast_t -= delta
		toast.modulate.a = clampf(minf(_toast_t, 7.0 - _toast_t) * 1.5, 0.0, 1.0)
