extends SkeletonModifier3D
## Live swimming for artist fish models. The artist's swim clip keeps playing (it carries the fin,
## gill and tail-fin life), and this modifier, which runs after it each frame:
##  - scales the clip's strength: every bone is blended between its average "neutral" pose
##    (measured from the clip) and the animated pose, so a gliding fish beats gently and a kicking
##    fish beats fully, smoothly in between;
##  - curves the spine into turns, like a real fish bending its body around a corner.
## The spine is found from bone names or the longest head-to-tail centreline path.

var fish: Node3D  # fish.gd: provides phase, effort, turn_bend, hover_t, length
var tail_angle := 0.45  # radians of total bend at the tail at full effort
var chain: Array[int] = []  # spine bones, head to tail
var chain_s: Array[float] = []  # 0 at the head end of the chain, 1 at the tail end
var fins: Array[int] = []  # pectoral fins
var fin_side: Array[float] = []
var neutral: Array[Quaternion] = []  # per bone: average pose over one cycle of the clip
var bend_enabled := true
# Body wave for fish whose clip doesn't really swim: tail swing in body lengths (0 = use the clip).
var wave_tail := 0.0


func setup(f: Node3D, amount: float) -> void:
	fish = f
	tail_angle = amount


## Fish-local rest position of a bone (head at -Z, tail at +Z).
func _local(skel: Skeleton3D, bone: int) -> Vector3:
	var g := skel.global_transform * skel.get_bone_global_rest(bone)
	return fish.global_transform.affine_inverse() * g.origin


func find_bones() -> void:
	var skel := get_skeleton()
	chain.clear()
	fins.clear()
	var n := skel.get_bone_count()
	var L: float = fish.length
	var pos := []
	for i in n:
		pos.append(_local(skel, i))
	var named := []
	for i in n:
		if skel.get_bone_name(i).to_lower().contains("spine"):
			named.append(i)
	if named.size() >= 3:
		# Rigs with named spine bones: use them, head to tail.
		named.sort_custom(func(a, b): return _depth(skel, a) < _depth(skel, b))
		chain.assign(named)
	else:
		# Otherwise: the longest run of centreline bones that keeps heading toward the tail.
		var best_len := {}  # bone -> [tail z reached, path]
		var order := range(n)
		order.sort_custom(func(a, b): return _depth(skel, a) > _depth(skel, b))
		for i in order:
			var path := [i]
			var reach_z: float = pos[i].z
			if absf(pos[i].x) > L * 0.15:
				best_len[i] = [-INF, []]
				continue
			for c in skel.get_bone_children(i):
				var bc: Array = best_len.get(c, [-INF, []])
				if bc[0] > reach_z and pos[c].z > pos[i].z - L * 0.03:
					reach_z = bc[0]
					path = [i] + bc[1]
			best_len[i] = [reach_z, path]
		var best_span := -INF
		for i in n:
			var bl: Array = best_len[i]
			if bl[1].is_empty():
				continue
			var span: float = bl[0] - pos[i].z
			if span > best_span + L * 0.02 or (absf(span - best_span) <= L * 0.02 and bl[1].size() > chain.size()):
				best_span = span
				chain.assign(bl[1])
	# Keep the bones that actually run along the body.
	chain = chain.filter(func(i): return pos[i].z > pos[chain[0]].z - L * 0.05)
	var z0: float = pos[chain[0]].z if chain.size() > 0 else 0.0
	var z1: float = pos[chain[-1]].z if chain.size() > 0 else 1.0
	chain_s.clear()
	for i in chain:
		chain_s.append(clampf((pos[i].z - z0) / maxf(z1 - z0, 0.001), 0.0, 1.0))
	# Pectoral fins: bones named so, or side bones near the front third of the body.
	for i in n:
		var nm := skel.get_bone_name(i).to_lower()
		if nm.contains("pectoral") and skel.get_bone_parent(i) >= 0 and not skel.get_bone_name(skel.get_bone_parent(i)).to_lower().contains("pectoral"):
			fins.append(i)
			fin_side.append(signf(pos[i].x))


func _depth(skel: Skeleton3D, i: int) -> int:
	var d := 0
	while skel.get_bone_parent(i) >= 0:
		i = skel.get_bone_parent(i)
		d += 1
	return d


## Sample the clip over one loop and average each bone's rotation: the pose the beat swings around.
func capture_neutral(anim: AnimationPlayer) -> void:
	var skel := get_skeleton()
	var n := skel.get_bone_count()
	var sums: Array[Vector4] = []
	sums.resize(n)
	var first: Array[Quaternion] = []
	first.resize(n)
	var length := anim.current_animation_length
	var samples := 24
	for k in samples:
		anim.seek(length * k / samples, true)
		for b in n:
			var q := skel.get_bone_pose_rotation(b)
			if k == 0:
				first[b] = q
				sums[b] = Vector4.ZERO
			if q.dot(first[b]) < 0.0:
				q = -q  # keep all samples on the same hemisphere before averaging
			sums[b] += Vector4(q.x, q.y, q.z, q.w)
	neutral.resize(n)
	for b in n:
		var v := sums[b].normalized()
		neutral[b] = Quaternion(v.x, v.y, v.z, v.w)


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or fish == null:
		return
	# 1) Strength of the swim beat: 0 = neutral pose, 1 = the artist's full clip.
	#    Fish with a procedural body wave keep their clip at full strength for the fins.
	var amp: float = 1.0 if wave_tail > 0.0 else clampf(fish.beat_amp, 0.0, 1.0)
	if neutral.size() == skel.get_bone_count() and amp < 0.999:
		for b in neutral.size():
			skel.set_bone_pose_rotation(b, neutral[b].slerp(skel.get_bone_pose_rotation(b), amp))
	# 2) Curve the body into turns.
	if not bend_enabled or chain.is_empty():
		return
	var up_skel := (skel.global_basis.inverse() * fish.global_basis.y).normalized()
	var bend: float = clampf(fish.turn_bend, -0.8, 0.8)
	var wave_a: float = wave_tail * clampf(fish.beat_amp, 0.0, 1.2)
	var prev_theta := 0.0
	for k in chain.size():
		# Turn: more curvature toward the tail, a C-shape around the corner.
		var a := bend * (0.35 + 0.65 * chain_s[k]) / chain.size() * 1.6
		if wave_tail > 0.0:
			# Lighthill travelling wave h(s,t) = A(s) sin(k s - w t), A(s) = A_tail (0.1 s + 0.9 s^2),
			# wavelength ~ one body length. Each joint turns by the change of the body's slope there.
			var sb := 0.15 + 0.85 * chain_s[k]  # position along the body, 0 = snout, 1 = tail tip
			var theta := _slope(sb, wave_a, fish.phase)
			a += theta - prev_theta
			prev_theta = theta
		_rotate_bone(skel, chain[k], up_skel, a)


## Angle of the body midline at body position s (0 snout .. 1 tail) for a Lighthill wave.
func _slope(s: float, a_tail: float, phase: float) -> float:
	var kw := TAU / 1.0  # wavelength = one body length
	var amp := a_tail * (0.1 * s + 0.9 * s * s)
	var damp := a_tail * (0.1 + 1.8 * s)
	var dh := damp * sin(kw * s - phase) + amp * kw * cos(kw * s - phase)
	return atan(dh)


func _old_procedural_wave() -> void:
	var skel := get_skeleton()
	if skel == null or fish == null or chain.is_empty():
		return
	# The fish's up axis in skeleton space: the spine bends around it (side to side).
	var up_skel := (skel.global_basis.inverse() * fish.global_basis.y).normalized()
	var e: float = clampf(fish.effort, 0.0, 1.4)
	var amp := tail_angle * (0.18 + 0.82 * clampf(e, 0.0, 1.0))
	var phase: float = fish.phase
	var bend: float = clampf(fish.turn_bend, -0.7, 0.7)
	var per := 1.0 / chain.size()
	for k in chain.size():
		var i := chain[k]
		var s := chain_s[k]
		# Wave grows toward the tail; the head counter-sways a little. Turning curves the body.
		var wave := sin(phase - s * 4.2) * amp * (0.25 + 1.6 * s * s) * per * 2.2
		var a := wave + bend * 0.55 * per
		_rotate_bone(skel, i, up_skel, a)
	# Pectoral fins scull: gently while cruising, more while hovering.
	var hovering: bool = fish.hover_t > 0.0
	var fin_amp := 0.35 if hovering else 0.15
	for k in fins.size():
		_rotate_bone(skel, fins[k], up_skel, sin(phase * 0.7 + fin_side[k] * 1.3) * fin_amp * fin_side[k])


func _rotate_bone(skel: Skeleton3D, bone: int, axis_skel: Vector3, angle: float) -> void:
	var g := skel.get_bone_global_pose(bone)
	var axis_local := (g.basis.inverse() * axis_skel).normalized()
	skel.set_bone_pose_rotation(bone, skel.get_bone_pose_rotation(bone) * Quaternion(axis_local, angle))


func describe() -> String:
	var skel := get_skeleton()
	var names := chain.map(func(i): return skel.get_bone_name(i))
	return "chain %d %s | fins %d" % [chain.size(), names, fins.size()]


## Dev helper: how many side-to-side tail beats one loop of the clip contains, and its length.
func measure_beats(anim: AnimationPlayer) -> String:
	var skel := get_skeleton()
	if chain.is_empty():
		return "no chain"
	var tail := chain[-1]
	var length := anim.current_animation_length
	var xs: Array[float] = []
	for k in 96:
		anim.seek(length * k / 96.0, true)
		var g := skel.global_transform * skel.get_bone_global_pose(tail)
		xs.append((fish.global_transform.affine_inverse() * g.origin).x)
	var mean := 0.0
	for x in xs:
		mean += x / xs.size()
	var crossings := 0
	for k in xs.size():
		if signf(xs[k] - mean) != signf(xs[(k + 1) % xs.size()] - mean):
			crossings += 1
	var amp: float = (xs.max() - xs.min()) / 2.0 / fish.length
	return "clip %.2fs, %d beats, tail swing %.2f body lengths, %.2f Hz" % [length, crossings / 2, amp, crossings / 2.0 / length]
