extends RefCounted
## Builds a fish mesh from a species spec. The head points to -Z, as Godot's look_at expects.
## Surfaces: 0 = body, 1 = fins (COLOR.r = flex weight), 2 = eyes (COLOR = albedo, alpha 0 = sparkle).

const RINGS := 22
const SIDES := 16


## Returns (half_width, half_height, y_center) of the body cross-section at t (0 = nose, 1 = tail stem).
static func profile(spec: Dictionary, t: float) -> Vector3:
	var L: float = spec.length
	var H: float = L * float(spec.height_ratio)
	var tp: float = spec.get("peak", 0.38)
	var stem: float = spec.get("stem", 0.25)
	var h := 0.0
	var u := 0.0
	if t < tp:
		var q := (tp - t) / tp
		var round_h := sqrt(maxf(0.0, 1.0 - q * q))
		var blunt_h := pow(maxf(0.0, 1.0 - q * q), 0.3)
		h = H * lerpf(round_h, blunt_h, float(spec.get("blunt", 0.3)))
	else:
		u = (t - tp) / (1.0 - tp)
		h = H * (stem + (1.0 - stem) * (cos(u * PI) * 0.5 + 0.5))
	var w := h * float(spec.width_ratio) * lerpf(1.0, 0.55, u)
	var yc := -float(spec.get("belly_drop", 0.0)) * H * sin(PI * t) * 0.22
	return Vector3(w * 0.5, h * 0.5, yc)


static func build(spec: Dictionary) -> Dictionary:
	var L: float = spec.length
	var head_z := -L * 0.5
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _body(spec, head_z))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _fins(spec, head_z))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _eyes(spec, head_z))
	var H: float = L * float(spec.height_ratio)
	return {"mesh": mesh, "head_z": head_z, "length": L, "height": H}


static func _body(spec: Dictionary, head_z: float) -> Array:
	var L: float = spec.length
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var p0 := profile(spec, 0.0)
	v.append(Vector3(0, p0.z, head_z))
	n.append(Vector3(0, 0, -1))
	uv.append(Vector2(0, 0.5))
	var e := 0.5 / RINGS
	for r in range(1, RINGS + 1):
		var t := float(r) / RINGS
		var pr := profile(spec, t)
		var pa := profile(spec, maxf(t - e, 0.0))
		var pb := profile(spec, minf(t + e, 1.0))
		var slope := ((pb.x + pb.y) - (pa.x + pa.y)) * 0.5 / (2.0 * e * L)
		var z := head_z + t * L
		for s in SIDES:
			var a := TAU * s / SIDES
			v.append(Vector3(sin(a) * pr.x, pr.z + cos(a) * pr.y, z))
			var en := Vector3(sin(a) / maxf(pr.x, 0.001), cos(a) / maxf(pr.y, 0.001), 0.0).normalized()
			n.append((en + Vector3(0, 0, -slope)).normalized())
			uv.append(Vector2(t, float(s) / SIDES))
	var pl := profile(spec, 1.0)
	v.append(Vector3(0, pl.z, head_z + L))
	n.append(Vector3(0, 0, 1))
	uv.append(Vector2(1, 0.5))
	var cap := v.size() - 1
	for s in SIDES:
		var s2 := (s + 1) % SIDES
		idx.append_array([0, 1 + s, 1 + s2])
		for r in range(RINGS - 1):
			var a0 := 1 + r * SIDES
			var a1 := a0 + SIDES
			idx.append_array([a0 + s, a1 + s, a1 + s2, a0 + s, a1 + s2, a0 + s2])
		var last := 1 + (RINGS - 1) * SIDES
		idx.append_array([last + s, cap, last + s2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	return arr


## Appends a fin grid between a base polyline and a tip polyline.
static func _fin_grid(f: Dictionary, base: Array, tip: Array, rows: int, flex0: float, flex1: float, normal: Vector3) -> void:
	var start: int = f.v.size()
	var k := base.size()
	for r in rows + 1:
		var t := float(r) / rows
		for i in k:
			var b: Vector3 = base[i]
			var p: Vector3 = tip[i]
			f.v.append(b.lerp(p, t))
			f.n.append(normal)
			f.c.append(Color(lerpf(flex0, flex1, t), 0, 0))
			f.uv.append(Vector2(float(i) / (k - 1), t))
	for r in rows:
		for i in k - 1:
			var a := start + r * k + i
			var b2 := a + k
			f.idx.append_array([a, b2, b2 + 1, a, b2 + 1, a + 1])


static func _fins(spec: Dictionary, head_z: float) -> Array:
	var L: float = spec.length
	var H: float = L * float(spec.height_ratio)
	var f := {"v": [], "n": [], "c": [], "uv": [], "idx": []}

	# Tail fin: a fan anchored on the tail stem.
	var tail: Dictionary = spec.tail
	var pl := profile(spec, 1.0)
	var tz := head_z + L * 0.96
	var TL: float = float(tail.len) * L
	var spread: float = tail.spread
	var kind: String = tail.type
	var sides := [0.0]
	if kind == "twin":
		sides = [-1.0, 1.0]
	for side in sides:
		var base := []
		var tip := []
		for i in 13:
			var vn := float(i) / 12.0 * 2.0 - 1.0
			var th := vn * spread
			var r := TL
			match kind:
				"fork":
					r *= 0.45 + 0.55 * pow(absf(vn), 0.8)
				"twin":
					r *= 0.72 + 0.28 * pow(absf(vn), 0.6)
				"round":
					r *= 1.0 - 0.35 * vn * vn
				"veil":
					r *= 0.9 + 0.1 * cos(vn * PI)
			var b := Vector3(side * pl.x * 0.3, pl.z + pl.y * vn * 0.85, tz)
			base.append(b)
			tip.append(b + Vector3(side * r * 0.32, sin(th) * r, cos(th) * r))
		_fin_grid(f, base, tip, 5, 0.12, 1.0, Vector3(1, 0, 0))

	# Dorsal and anal fins along the top and bottom lines.
	for fin_key in ["dorsal", "anal"]:
		var d: Dictionary = spec.get(fin_key, {})
		if d.is_empty():
			continue
		var sgn := 1.0 if fin_key == "dorsal" else -1.0
		var base := []
		var tip := []
		for i in 9:
			var u := float(i) / 8.0
			var t: float = lerpf(float(d.t0), float(d.t1), u)
			var pr := profile(spec, t)
			var b := Vector3(0, pr.z + sgn * pr.y * 0.9, head_z + t * L)
			var fh: float = float(d.h) * H * pow(sin(PI * clampf(u * 1.05, 0.0, 1.0)), 0.6) * (1.15 - 0.4 * u)
			base.append(b)
			tip.append(b + Vector3(0, sgn * fh, fh * 0.55))
		_fin_grid(f, base, tip, 3, 0.05, 0.55, Vector3(1, 0, 0))

	# Pectoral fins: small paddles behind the gills.
	var P: float = float(spec.pect) * L
	var pp := profile(spec, 0.3)
	for side in [-1.0, 1.0]:
		var base := []
		var tip := []
		for i in 5:
			var u := float(i) / 4.0
			var b := Vector3(side * pp.x * 0.85, pp.z - pp.y * 0.35, head_z + L * (0.28 + 0.06 * u))
			base.append(b)
			var r := P * (0.75 + 0.25 * sin(PI * u))
			tip.append(b + Vector3(side * r * 0.45, -r * 0.45 + u * r * 0.2, r * 0.75))
		_fin_grid(f, base, tip, 3, 0.3, 1.0, Vector3(0, 1, 0))

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(f.v)
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(f.n)
	arr[Mesh.ARRAY_COLOR] = PackedColorArray(f.c)
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(f.uv)
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array(f.idx)
	return arr


static func _sphere(e: Dictionary, center: Vector3, radius: float, col: Color) -> void:
	var start: int = e.v.size()
	var lat := 8
	var lon := 10
	for i in lat + 1:
		var th := PI * i / lat
		for j in lon + 1:
			var ph := TAU * j / lon
			var dir := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			e.v.append(center + dir * radius)
			e.n.append(dir)
			e.c.append(col)
	for i in lat:
		for j in lon:
			var a := start + i * (lon + 1) + j
			var b := a + lon + 1
			e.idx.append_array([a, b, b + 1, a, b + 1, a + 1])


static func _eyes(spec: Dictionary, head_z: float) -> Array:
	var L: float = spec.length
	var te: float = spec.get("eye_t", 0.14)
	var pr := profile(spec, te)
	var er: float = float(spec.eye) * L
	var e := {"v": [], "n": [], "c": [], "idx": []}
	for side in [-1.0, 1.0]:
		var c := Vector3(side * pr.x * 0.78, pr.z + pr.y * 0.22, head_z + te * L)
		_sphere(e, c, er, Color(0.97, 0.95, 0.9, 1))
		_sphere(e, c + Vector3(side * er * 0.5, -er * 0.05, -er * 0.12), er * 0.68, Color(0.03, 0.03, 0.06, 1))
		_sphere(e, c + Vector3(side * er * 1.02, er * 0.3, -er * 0.28), er * 0.2, Color(1, 1, 1, 0))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(e.v)
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(e.n)
	arr[Mesh.ARRAY_COLOR] = PackedColorArray(e.c)
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array(e.idx)
	return arr
