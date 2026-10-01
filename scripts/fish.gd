extends Node3D
## One fish: steering behaviour, swim animation uniforms, hunger visuals and a gentle death.

const FishMesh = preload("res://scripts/fish_mesh.gd")
const SpeciesDB = preload("res://scripts/species.gd")
const BODY_SHADER := preload("res://shaders/fish_body.gdshader")
const FIN_SHADER := preload("res://shaders/fish_fin.gdshader")
const EYE_SHADER := preload("res://shaders/fish_eye.gdshader")

var rec: Dictionary
var spec: Dictionary
var world: Node  # main.gd

var vel := Vector3.ZERO
var phase := 0.0
var target := Vector3.ZERO
var wander_t := 0.0
var startle_t := 0.0
var startle_dir := Vector3.ZERO
var curious_t := 0.0
var interested := false
var _last_visit := -100.0
var wiggle := 0.0
var play_t := 0.0
var turn_bend := 0.0
var prev_fwd := Vector3.FORWARD
var personality := 1.0
var dead := false
var dead_t := 0.0
var fade := 1.0
var mats: Array = []
var label: Label3D
var length := 1.0


func setup(record: Dictionary, main: Node, start: Vector3) -> void:
	rec = record
	world = main
	spec = SpeciesDB.get_spec(rec.species)
	length = spec.length
	personality = randf_range(0.85, 1.15)
	phase = randf() * TAU
	var info := FishMesh.build(spec)
	var mi := MeshInstance3D.new()
	mi.mesh = info.mesh
	add_child(mi)
	var body := ShaderMaterial.new()
	body.shader = BODY_SHADER
	body.set_shader_parameter("col_a", spec.col_a)
	body.set_shader_parameter("col_b", spec.col_b)
	body.set_shader_parameter("col_belly", spec.col_belly)
	body.set_shader_parameter("pattern", int(spec.pattern))
	body.set_shader_parameter("pattern_scale", float(spec.pattern_scale))
	body.set_shader_parameter("specks", float(spec.specks))
	body.set_shader_parameter("seed", float(rec.id) * 3.17)
	body.set_shader_parameter("body_h", float(info.height))
	var fin := ShaderMaterial.new()
	fin.shader = FIN_SHADER
	fin.set_shader_parameter("fin_a", spec.fin_a)
	fin.set_shader_parameter("fin_b", spec.fin_b)
	fin.set_shader_parameter("fin_alpha", float(spec.fin_alpha))
	var eye := ShaderMaterial.new()
	eye.shader = EYE_SHADER
	mats = [body, fin, eye]
	for i in 3:
		mi.set_surface_override_material(i, mats[i])
	for m in mats:
		m.set_shader_parameter("body_len", float(info.length))
		m.set_shader_parameter("head_z", float(info.head_z))
		m.set_shader_parameter("wave_k", float(spec.wave_k))
	position = start
	vel = Vector3(randf_range(-1, 1), 0, randf_range(-0.2, 0.2)).normalized() * float(spec.speed)
	_pick_target()
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.pixel_size = 0.004
	label.no_depth_test = true
	label.visible = false
	add_child(label)


func _pick_target() -> void:
	var d: Vector2 = spec.depth
	var x := randf_range(-5.0, 5.0)
	var z := randf_range(-1.6, 1.3)
	if float(spec.school) > 0.5:
		target = world.school_target(rec.species) + Vector3(randf_range(-0.8, 0.8), randf_range(-0.4, 0.4), randf_range(-0.5, 0.5))
	else:
		target = Vector3(x, randf_range(d.x, d.y), z)
	if Game.stage(rec.satiety) == "starving":
		target.y = world.tank.floor_height(target.x, target.z) + 0.5
	target.y = maxf(target.y, world.tank.floor_height(target.x, target.z) + 0.5)
	wander_t = randf_range(3.0, 8.0)


func startle(from: Vector3, power: float) -> void:
	if dead:
		return
	var d := global_position.distance_to(from)
	if d > 4.5:
		return
	startle_dir = (global_position - from).normalized()
	startle_dir.z *= 0.5
	startle_t = 0.7 * power * float(spec.startle) * (1.0 - d / 4.5) + 0.2
	# Curious fish come back to look after the fright.
	curious_t = 6.0 * float(spec.curiosity)


func _process(delta: float) -> void:
	if dead:
		_process_dead(delta)
		_update_visuals(delta)
		return
	if rec.satiety <= 0.0:
		_die()
		return
	var desired := _steer(delta)
	var max_speed: float = spec.max_speed
	var accel := max_speed * (4.0 if startle_t > 0.0 else 1.6)
	vel += (desired - vel).limit_length(accel * delta)
	vel = vel.limit_length(max_speed)
	position += vel * delta
	_keep_inside()
	_orient(delta)
	_update_visuals(delta)


func _steer(delta: float) -> Vector3:
	var p := position
	var st := Game.stage(rec.satiety)
	var mood := 1.0
	match st:
		"full":
			mood = 0.75
		"hungry":
			mood = 1.15
		"starving":
			mood = 0.4
	var cruise: float = float(spec.speed) * mood * personality
	startle_t -= delta
	curious_t -= delta
	wiggle = maxf(0.0, wiggle - delta)
	play_t -= delta

	if startle_t > 0.0:
		return startle_dir * float(spec.max_speed)

	wander_t -= delta
	if wander_t <= 0.0 or p.distance_to(target) < 0.6:
		_pick_target()
	var desired := (target - p).normalized() * cruise

	# Food: hungrier fish care more and swim faster for it.
	var appetite := clampf((95.0 - rec.satiety) / 45.0, 0.0, 1.0) * float(spec.greed)
	if appetite > 0.05:
		var food: Node3D = world.nearest_food(p, 7.0)
		if food:
			var to := food.position - p
			if to.length() < length * 0.4 + 0.12:
				_eat(food)
			else:
				var urgency := clampf(appetite * 1.3, 0.0, 1.0)
				desired = desired.lerp(to.normalized() * float(spec.max_speed) * (0.55 + 0.35 * appetite), urgency)

	# The hand at the glass: curious fish come close, shy fish keep away.
	var since_seen := Game.sim_time - Game.cursor_seen_at
	if since_seen > 4.0:
		_last_visit = -100.0
	elif _last_visit < 0.0:
		# A new visit of the hand: each fish decides whether it cares this time.
		_last_visit = Game.sim_time
		interested = randf() < float(spec.curiosity) * (1.3 if st == "hungry" else 0.75)
	if since_seen < 4.0 and (interested or curious_t > 0.0 or float(spec.shy) > 0.0):
		var to_c := Game.cursor_pos - p
		var d := to_c.length()
		var curiosity: float = float(spec.curiosity) * (1.6 if curious_t > 0.0 else 1.0)
		if st == "hungry":
			curiosity *= 1.4  # begging at the glass
		if (interested or curious_t > 0.0) and curiosity > 0.3 and d < 7.0:
			var w := curiosity * clampf(d / 3.0, 0.0, 1.0) * (1.0 - since_seen / 4.0)
			var stop := 0.8 + length * 0.7 + float(rec.id % 5) * 0.25
			if d > stop:
				desired = desired.lerp(to_c.normalized() * cruise * 1.3, clampf(w, 0.0, 0.85))
			else:
				desired *= 0.25
		if float(spec.shy) > 0.0 and d < 2.6:
			desired += -to_c.normalized() * float(spec.shy) * 2.0 * (1.0 - d / 2.6)

	# Toy: playful fish give the ball a nudge now and then.
	var toy: Node3D = world.toy
	if toy and st in ["full", "content"] and float(spec.curiosity) > 0.5:
		if play_t <= 0.0 and randf() < delta * 0.08:
			play_t = 6.0
		if play_t > 0.0:
			var to_t := toy.position + Vector3(0, -0.35, 0) - p
			desired = desired.lerp(to_t.normalized() * float(spec.max_speed) * 0.6, 0.7)
			if to_t.length() < 0.5:
				toy.push(vel * 0.6 + Vector3(0, 0.1, 0))
				play_t = 0.0
				startle_t = 0.25
				startle_dir = -to_t.normalized()

	# Schooling and personal space.
	var sep := Vector3.ZERO
	var align := Vector3.ZERO
	var coh := Vector3.ZERO
	var n := 0
	var school: float = spec.school
	for other in world.fishes:
		if other == self or other.dead:
			continue
		var off: Vector3 = other.position - p
		var d2 := off.length_squared()
		var space := (length + float(other.length)) * 0.45
		if d2 < space * space and d2 > 0.0001:
			sep -= off / d2 * space
		if school > 0.0 and other.rec.species == rec.species and d2 < 3.2:
			align += other.vel
			coh += off
			n += 1
	if n > 0:
		desired += (align / n - vel) * 0.5 * school
		desired += (coh / n) * 0.6 * school
	desired += sep * 1.4

	# Soft walls and floor.
	var floor_y: float = world.tank.floor_height(p.x, p.z) + 0.25 + length * 0.2
	if p.x > 5.4 - length * 0.3: desired.x -= (p.x - 5.4 + length * 0.3) * 3.0 + 1.0
	if p.x < -5.4 + length * 0.3: desired.x += (-5.4 + length * 0.3 - p.x) * 3.0 + 1.0
	if p.z > 1.6: desired.z -= (p.z - 1.6) * 4.0
	if p.z < -1.9: desired.z += (-1.9 - p.z) * 4.0
	if p.y > 6.1: desired.y -= (p.y - 6.1) * 4.0
	if p.y < floor_y + 0.3: desired.y += (floor_y + 0.3 - p.y) * 4.0

	desired += Game.current_at(p) * 0.9
	# Prefer swimming across the glass so fish show their side.
	desired.z *= 0.6
	return desired


func _keep_inside() -> void:
	var floor_y: float = world.tank.floor_height(position.x, position.z) + 0.2
	position.x = clampf(position.x, -5.7, 5.7)
	position.z = clampf(position.z, -2.1, 2.1)
	position.y = clampf(position.y, floor_y, 6.35)


func _orient(delta: float) -> void:
	var spd := vel.length()
	if spd < 0.03:
		return
	var fwd := vel / spd
	fwd.y = clampf(fwd.y, -0.5, 0.5)
	fwd = fwd.normalized()
	var target_basis := Basis.looking_at(fwd, Vector3.UP)
	var q := Quaternion(transform.basis.orthonormalized())
	var k := 1.0 - exp(-delta * (6.0 if startle_t > 0.0 else 3.0))
	transform.basis = Basis(q.slerp(Quaternion(target_basis), k))
	var yaw_rate := prev_fwd.signed_angle_to(fwd, Vector3.UP) / maxf(delta, 0.001)
	prev_fwd = fwd
	turn_bend = lerpf(turn_bend, clampf(-yaw_rate * 0.12, -0.7, 0.7), 1.0 - exp(-delta * 4.0))


func _eat(food: Node3D) -> void:
	world.remove_food(food)
	Game.feed(rec, float(spec.food_value))
	wiggle = 1.0


func _update_visuals(delta: float) -> void:
	var spd := vel.length()
	var max_speed: float = spec.max_speed
	var effort := clampf(spd / max_speed, 0.0, 1.0)
	var freq: float = float(spec.freq) * (0.55 + 1.3 * effort) * (1.0 + wiggle * 0.8)
	if dead:
		freq = 0.0
	phase += TAU * freq * delta
	var amp: float = float(spec.amp) * (0.55 + 0.8 * effort) * (1.0 + wiggle * 0.6)
	if dead:
		amp = 0.0
	var vitality := 1.0
	if rec.satiety < Game.STAGE_HUNGRY:
		vitality = lerpf(0.25, 1.0, rec.satiety / Game.STAGE_HUNGRY)
	if dead:
		vitality = 0.15
	for m in mats:
		m.set_shader_parameter("swim_phase", phase)
		m.set_shader_parameter("swim_amp", amp)
		m.set_shader_parameter("turn_bend", turn_bend)
		m.set_shader_parameter("vitality", vitality)
		m.set_shader_parameter("fade", fade)
	label.visible = Game.show_debug
	if label.visible:
		label.position = Vector3(0, length * 0.6, 0)
		label.text = "%s · %s\n%d%% %s" % [rec.name, spec.name, int(rec.satiety), Game.stage(rec.satiety)]


func _die() -> void:
	dead = true
	Game.mark_dead(rec, false)


func _process_dead(delta: float) -> void:
	# Drift up belly-up, rest at the surface, then fade softly away.
	dead_t += delta
	vel = vel.lerp(Vector3(0, 0.12, 0), 1.0 - exp(-delta * 1.2))
	position += vel * delta + Game.current_at(position) * 0.3 * delta
	position.y = minf(position.y, 6.25)
	var fwd := -transform.basis.z
	fwd.y = 0
	if fwd.length() < 0.01:
		fwd = Vector3.RIGHT
	var belly_up := Basis.looking_at(fwd.normalized(), Vector3.DOWN)
	var q := Quaternion(transform.basis.orthonormalized())
	transform.basis = Basis(q.slerp(Quaternion(belly_up), 1.0 - exp(-delta * 0.8)))
	if dead_t > 10.0:
		fade = clampf(1.0 - (dead_t - 10.0) / 5.0, 0.0, 1.0)
		if fade <= 0.0:
			world.remove_fish(self)
