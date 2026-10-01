extends SkeletonModifier3D
## Procedural swimming for artist fish models. Instead of looping the canned clip, the real spine
## bones are bent every frame: a travelling wave from head to tail whose strength follows the fish's
## kick envelope, a curve into turns, and pectoral fins that scull. Spine and fins are found
## automatically from the rest pose, so it works on any fish skeleton without per-model setup.

var fish: Node3D  # fish.gd: provides phase, effort, turn_bend, hover_t, length
var tail_angle := 0.45  # radians of total bend at the tail at full effort
var chain: Array[int] = []  # spine bones, head to tail
var chain_s: Array[float] = []  # 0 at the head end of the chain, 1 at the tail end
var fins: Array[int] = []  # pectoral fins
var fin_side: Array[float] = []


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


func _process_modification() -> void:
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
