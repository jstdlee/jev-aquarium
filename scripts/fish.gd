extends Node3D
## One fish: steering behaviour, swim animation uniforms, hunger visuals and a gentle death.

const FishMesh = preload("res://scripts/fish_mesh.gd")
const SpeciesDB = preload("res://scripts/species.gd")
const BODY_SHADER := preload("res://shaders/fish_body.gdshader")
const FIN_SHADER := preload("res://shaders/fish_fin.gdshader")
const EYE_SHADER := preload("res://shaders/fish_eye.gdshader")
const SwimSpine = preload("res://scripts/swim_spine.gd")

var rec: Dictionary
var spec: Dictionary
var world: Node  # main.gd

var vel := Vector3.ZERO
var phase := 0.0
# Locomotion: the fish always moves along its body. Heading turns with a limited rate (smooth arcs);
# speed comes in kicks followed by glides, like real fish.
var yaw := 0.0
var pitch := 0.0
var yaw_rate := 0.0
var roll := 0.0
var speed := 0.0
var kick := -1.0  # 0..1 progress through the current tail kick, < 0 when coasting
var kick_len := 0.5
var kick_power := 0.0
var effort := 0.0  # 0 = gliding or hovering, 1 = hard swimming; drives the tail animation
var hover_t := 0.0
var hover_cool := 4.0
var holder: Node3D
var spine: SkeletonModifier3D  # beat strength and turn curvature (artist models)
var beat_amp := 0.6  # strength of the swim beat, smoothed (read by swim_spine.gd)
var beat_hz := 1.2  # current tail-beat frequency, smoothed
var holder_basis := Basis()
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
# Artist model (when the species has one): its animation and materials for hunger tint and fade.
var anim: AnimationPlayer
var anim_base := 1.0
var model_mats: Array = []  # [material, original albedo colour]
var _shown_vitality := 1.0
var _shown_fade := 1.0


func setup(record: Dictionary, main: Node, start: Vector3) -> void:
	rec = record
	world = main
	spec = SpeciesDB.get_spec(rec.species)
	length = spec.length
	personality = randf_range(0.85, 1.15)
	phase = randf() * TAU
	if spec.has("model"):
		_setup_model(spec.model)
	else:
		_setup_procedural()
	position = start
	if spine and spine.bend_enabled:
		spine.find_bones()
	yaw = randf_range(0.0, TAU)
	speed = float(spec.speed) * 0.5
	hover_cool = randf_range(3.0, 10.0)
	_pick_target()
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.pixel_size = 0.004
	label.no_depth_test = true
	label.visible = false
	add_child(label)


func _setup_model(m: Dictionary) -> void:
	var scene: PackedScene = load(m.path)
	var model: Node3D = scene.instantiate()
	# Turn the head to -Z, centre the rest pose on this node and scale to the tank length.
	holder = Node3D.new()
	var s: float = length / float(m.size)
	# "fix" turns a re-exported model back to the original file's orientation (tools/bake_swim.py
	# exports some rigs from their upright bind pose); "center" is measured on the original file.
	var fix := Basis.from_euler(Vector3(m.get("fix", Vector3.ZERO)) * (PI / 180.0))
	holder_basis = (Basis(Vector3.UP, deg_to_rad(float(m.yaw))) * fix).scaled(Vector3.ONE * s)
	holder.transform = Transform3D(holder_basis, Vector3.ZERO)
	model.position = -(fix.inverse() * Vector3(m.center))
	holder.add_child(model)
	add_child(holder)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and not anim.get_animation_list().is_empty():
		# Prefer the baked "Swim" cycle (tools/bake_swim.py) over the artist's original clip.
		var anim_name: StringName = anim.get_animation_list()[0]
		for nm in anim.get_animation_list():
			if String(nm).to_lower().contains("swim"):
				anim_name = nm
		anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		anim.play(anim_name)
		anim.seek(randf() * anim.current_animation_length, true)
		anim_base = float(m.get("anim_speed", 1.0))
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty() and anim:
		# The clip keeps playing; the modifier scales its strength and bends the body into turns.
		spine = SwimSpine.new()
		skels[0].add_child(spine)
		spine.setup(self, float(spec.get("spine", 0.45)))
		spine.bend_enabled = bool(spec.get("procedural", true))
		spine.wave_tail = float(spec.get("wave", 0.0))
		var t0 := anim.current_animation_position
		spine.capture_neutral(anim)
		anim.seek(t0, true)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var gi := mi as MeshInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in gi.mesh.get_surface_count():
			var mat := gi.get_active_material(i)
			if mat is BaseMaterial3D:
				var dup: BaseMaterial3D = mat.duplicate()
				var mname := String(mat.resource_name).to_lower()
				if mname.contains("lens") or mname.contains("iris") or mname.contains("eye") or mname.contains("pupil"):
					# Wet, glossy eyes catch a highlight and look alive instead of flat and staring.
					dup.roughness = 0.04
					dup.metallic_specular = 1.0
					dup.clearcoat_enabled = true
					dup.clearcoat = 1.0
					dup.clearcoat_roughness = 0.02
				gi.set_surface_override_material(i, dup)
				model_mats.append([dup, dup.albedo_color, dup.transparency])


func _setup_procedural() -> void:
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


func _pick_target() -> void:
	var d: Vector2 = spec.depth
	var x := randf_range(-5.0, 5.0)
	var z := randf_range(-1.9, 1.6)
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
	var prev := position
	_locomote(desired, delta)
	_resolve_contacts(prev)
	_keep_inside()
	_update_visuals(delta)


func _locomote(desired: Vector3, delta: float) -> void:
	var max_speed: float = spec.max_speed
	var glide: float = spec.get("glide", 0.5)  # 0 = steady swimmer, 1 = strong kick-and-glide
	var turn: float = spec.get("turn", 2.2)  # max turn rate, rad/s
	var want := minf(desired.length(), max_speed)
	var dir := desired / desired.length() if desired.length() > 0.001 else -transform.basis.z
	var scared := startle_t > 0.0

	# Now and then a calm fish pauses to hover, sculling with its fins.
	hover_cool -= delta
	if hover_t > 0.0:
		hover_t -= delta
		if not scared and want < max_speed * 0.7:
			want *= 0.12
	elif hover_cool <= 0.0:
		hover_cool = randf_range(6.0, 16.0)
		if randf() < float(spec.get("hover", 0.2)) and not scared:
			hover_t = randf_range(2.0, 6.0)

	# Turning: rate-limited and smoothed, so paths are arcs. A frightened fish snaps around.
	var flat := Vector2(dir.x, dir.z)
	if flat.length() > 0.05:
		var err := wrapf(atan2(dir.x, dir.z) - yaw, -PI, PI)
		var limit := turn * (3.0 if scared else 1.0)
		var want_rate := clampf(err * 1.6, -limit, limit)
		yaw_rate = lerpf(yaw_rate, want_rate, 1.0 - exp(-delta * (8.0 if scared else 2.2)))
	else:
		yaw_rate = lerpf(yaw_rate, 0.0, 1.0 - exp(-delta * 3.0))
	yaw += yaw_rate * delta
	var want_pitch := clampf(asin(clampf(dir.y, -1.0, 1.0)), -0.45, 0.45)
	if hover_t > 0.0:
		want_pitch *= 0.3
	pitch = lerpf(pitch, want_pitch, 1.0 - exp(-delta * 1.6))
	var heading := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))

	# Speed: smooth thrust pulses from the tail against water drag. Each kick rises and falls
	# (sin^2 envelope), so speed and acceleration change continuously - no lurches.
	var target_speed := want * (1.0 - clampf(absf(yaw_rate) / 5.0, 0.0, 0.45))
	var drag := 0.7 + 0.7 * glide
	if kick < 0.0 and (scared or speed < target_speed * (1.0 - 0.4 * glide) or glide < 0.25):
		kick = 0.0
		kick_len = (0.25 if scared else randf_range(0.45, 0.8) * (0.7 + glide))
		# Enough push that the kick averages out at the wanted speed (plus a little for the glide).
		kick_power = maxf(target_speed - speed * exp(-drag * kick_len * 0.5), 0.0) * drag * (2.2 + glide) + (max_speed * 3.0 if scared else 0.0)
	var env := 0.0
	if kick >= 0.0:
		kick += delta / kick_len
		env = pow(sin(PI * clampf(kick, 0.0, 1.0)), 2.0)
		if kick >= 1.0:
			kick = -1.0
	speed += (env * kick_power - drag * speed) * delta
	speed = clampf(speed, 0.0, max_speed * (1.3 if scared else 1.0))
	# Tail effort follows the kick; while coasting the fins keep a slow idle beat.
	var want_effort := env * clampf(0.5 + kick_power / (max_speed * drag * 2.0), 0.4, 1.4) + (0.12 if hover_t <= 0.0 else 0.22)
	effort = lerpf(effort, want_effort, 1.0 - exp(-delta * 4.0))
	# Each tail stroke pushes: real fish surge forward twice per beat instead of sliding evenly.
	var surge := 1.0 + 0.22 * beat_amp * sin(2.0 * phase) * clampf(effort + 0.3, 0.0, 1.0)
	vel = heading * speed
	position += vel * surge * delta

	# Orientation: face the heading, bank gently into turns.
	var want_roll := clampf(-yaw_rate * 0.18 * clampf(speed / max_speed + 0.3, 0.0, 1.0), -0.35, 0.35)
	roll = lerpf(roll, want_roll, 1.0 - exp(-delta * 3.0))
	var b := Basis.looking_at(heading, Vector3.UP)
	transform.basis = b * Basis(Vector3.FORWARD, roll)
	turn_bend = lerpf(turn_bend, clampf(-yaw_rate * 0.15, -0.7, 0.7), 1.0 - exp(-delta * 4.0))


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
	# A slow meander so straight runs become lazy curves.
	desired = desired.rotated(Vector3.UP, sin(Game.sim_time * 0.35 + float(rec.id) * 1.7) * 0.5)

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

	# Feel ahead with three whisker rays and turn away from wood, rocks and decorations.
	desired += _whiskers(p)

	# Look ahead along the heading so turns start before the glass, not at it.
	var ahead := p + vel * 1.2
	var fy: float = world.tank.floor_height(ahead.x, ahead.z) + 0.5
	if absf(ahead.x) > 5.0: desired.x -= signf(ahead.x) * float(spec.max_speed) * 0.8
	if ahead.z > 1.5 or ahead.z < -1.8: desired.z -= signf(ahead.z) * float(spec.max_speed) * 0.6
	if ahead.y < fy: desired.y += float(spec.max_speed) * 0.5
	if ahead.y > 6.0: desired.y -= float(spec.max_speed) * 0.5

	# Soft walls and floor.
	var floor_y: float = world.tank.floor_height(p.x, p.z) + 0.25 + length * 0.2
	if p.x > 5.4 - length * 0.3: desired.x -= (p.x - 5.4 + length * 0.3) * 3.0 + 1.0
	if p.x < -5.4 + length * 0.3: desired.x += (-5.4 + length * 0.3 - p.x) * 3.0 + 1.0
	if p.z > 1.6: desired.z -= (p.z - 1.6) * 4.0
	if p.z < -1.9: desired.z += (-1.9 - p.z) * 4.0
	if p.y > 6.1: desired.y -= (p.y - 6.1) * 4.0
	if p.y < floor_y + 0.3: desired.y += (floor_y + 0.3 - p.y) * 4.0

	desired += Game.current_at(p) * 0.9
	# Mild preference for showing a side, but fish still swim toward and away from the glass.
	desired.z *= 0.85
	return desired


func _whiskers(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var heading := -transform.basis.z
	var reach := length * 0.8 + speed * 1.1 + 0.3
	var push := Vector3.ZERO
	for a in [0.0, 0.5, -0.5]:
		var dir := heading.rotated(Vector3.UP, a)
		var q := PhysicsRayQueryParameters3D.create(p, p + dir * reach * (1.0 if a == 0.0 else 0.7))
		var hit := space.intersect_ray(q)
		if hit:
			var closeness := 1.0 - p.distance_to(hit.position) / reach
			var n: Vector3 = hit.normal
			# Away from the surface, and sideways toward the freer side.
			push += (n + heading.cross(Vector3.UP) * signf(a if a != 0.0 else 0.3)) * closeness * float(spec.max_speed) * 2.2
	return push


## If the fish ended up touching a solid piece, slide it back out along the surface.
func _resolve_contacts(prev: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = length * 0.22
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis(), position)
	var info := space.get_rest_info(q)
	if info.is_empty():
		return
	var n: Vector3 = info.normal
	var move := position - prev
	if move.dot(n) < 0.0:
		move -= n * move.dot(n)  # keep only the sliding part
	position = prev + move + n * 0.01
	speed *= 0.85


func _keep_inside() -> void:
	var floor_y: float = world.tank.floor_height(position.x, position.z) + 0.2
	position.x = clampf(position.x, -5.7, 5.7)
	position.z = clampf(position.z, -2.1, 2.1)
	position.y = clampf(position.y, floor_y, 6.35)


func _eat(food: Node3D) -> void:
	world.remove_food(food)
	Game.feed(rec, float(spec.food_value))
	wiggle = 1.0


func _update_visuals(delta: float) -> void:
	var e := clampf(effort, 0.0, 1.4)
	# Tail-beat frequency rises with speed (Bainbridge: f grows linearly with body lengths per second)
	# and with effort; a kick beats faster than a glide.
	var want_hz := float(spec.get("beat_hz", 1.5)) * (1.0 + 0.8 * speed / length) * (0.8 + 0.35 * e) * (1.0 + wiggle * 0.5)
	beat_hz = lerpf(beat_hz, 0.0 if dead else want_hz, 1.0 - exp(-delta * 2.5))
	var clip_hz := float(spec.get("clip_hz", 0.0))
	var wave_fish := float(spec.get("wave", 0.0)) > 0.0
	if anim and clip_hz > 0.0 and not wave_fish and anim.current_animation_length > 0.0:
		# One rhythm for everything: the phase follows the artist clip's own tail beat.
		phase = TAU * anim.current_animation_position * clip_hz
	else:
		phase += TAU * beat_hz * delta
	var amp: float = float(spec.amp) * (0.35 + 0.9 * e) * (1.0 + wiggle * 0.6)
	if dead:
		amp = 0.0
	var vitality := 1.0
	if rec.satiety < Game.STAGE_HUNGRY:
		vitality = lerpf(0.25, 1.0, rec.satiety / Game.STAGE_HUNGRY)
	if dead:
		vitality = 0.15
	if anim:
		# Real fish never stop beating: the rhythm rises smoothly with effort (about 1.3 Hz idling
		# to 3 Hz cruising) and the beat grows from a gentle sway to a full sweep.
		var want_anim := 0.0
		if not dead:
			if clip_hz > 0.0 and not wave_fish:
				want_anim = beat_hz / clip_hz  # play the clip at the real tail frequency
			else:
				want_anim = float(spec.get("clip_speed", 1.0))  # clip only carries fin motion
		anim.speed_scale = lerpf(anim.speed_scale, want_anim, 1.0 - exp(-delta * 2.5))
		var want_amp := 0.0 if dead else clampf(0.4 + 0.6 * e + wiggle * 0.2, 0.0, 1.0)
		beat_amp = lerpf(beat_amp, want_amp, 1.0 - exp(-delta * 3.0))
	if holder and not dead:
		# The head sways a little with every tail beat.
		var sway := sin(phase) * 0.05 * (0.3 + e)
		holder.transform = Transform3D(Basis(Vector3.UP, sway) * holder_basis, Vector3.ZERO)
	if model_mats.size() > 0 and (absf(vitality - _shown_vitality) > 0.02 or absf(fade - _shown_fade) > 0.01):
		_shown_vitality = vitality
		_shown_fade = fade
		for entry in model_mats:
			var mat: BaseMaterial3D = entry[0]
			var orig: Color = entry[1]
			# Hungry fish grow pale; dead fish fade out.
			var c := orig.lerp(Color(0.62, 0.66, 0.7, orig.a), 1.0 - vitality)
			c.a = orig.a * fade
			mat.albedo_color = c
			if fade < 1.0:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
