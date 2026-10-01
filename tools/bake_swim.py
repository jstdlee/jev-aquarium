# Blender (headless): bake a real swim cycle into a fish model.
#   blender -b -P tools/bake_swim.py -- <in.glb> <out.glb> <tail_amp> <beats> [<proof_dir>]
#
# The body follows a Lighthill travelling wave, the standard model of carangiform swimming:
#   h(s, t) = A(s) * sin(k*s - w*t),  A(s) = tail_amp * L * (0.1*s + 0.9*s^2),  wavelength = 1 body length
# where s is the position along the body (0 = snout, 1 = tail tip). Every centreline bone behind the
# head (the spine and the tail-fin chains) turns so its slope follows the wave; each joint gets the
# change of slope from its parent. Side bones (pectoral and pelvic fins) keep the artist's keys.
# The cycle holds `beats` tail beats over the original clip length, so it loops seamlessly and plays
# at beats/length Hz natively. Output action is named "Swim".
#
# The model is imported with its straight bind pose (rigs differ: some rest upright, some bent), and
# the wave is keyed relative to that straight pose. Some rigs then come out of the export turned
# compared with the original file; scripts/species.gd corrects that with a per-model "fix" rotation.
import bpy, math, sys, os, mathutils

args = sys.argv[sys.argv.index("--") + 1:]
src, dst, tail_amp, beats = args[0], args[1], float(args[2]), int(args[3])
proof = args[4] if len(args) > 4 else None


def load(bind: bool):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src, guess_original_bind_pose=bind)
    for o in list(bpy.data.objects):
        if o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o)
    scn = bpy.context.scene
    arm = next(o for o in scn.objects if o.type == "ARMATURE")
    meshes = [o for o in scn.objects if o.type == "MESH"]
    return scn, arm, meshes


def frame_axes(arm, meshes):
    """Body, left/right and up axes of the rest frame, plus body extent."""
    pts = []
    for m in meshes:
        pts += [m.matrix_world @ v.co for v in m.data.vertices]
    lo = mathutils.Vector([min(p[i] for p in pts) for i in range(3)])
    hi = mathutils.Vector([max(p[i] for p in pts) for i in range(3)])
    size = hi - lo
    mw = arm.matrix_world
    body = max(range(3), key=lambda i: size[i])
    heads = [mw @ b.head_local for b in arm.data.bones]
    others = [i for i in range(3) if i != body]

    def mad(i):
        vals = sorted(h[i] for h in heads)
        med = vals[len(vals) // 2]
        devs = sorted(abs(v - med) for v in vals)
        return devs[len(devs) // 2]

    lat = min(others, key=mad)
    up = next(i for i in others if i != lat)
    return lo, hi, size, body, lat, up, heads


# ---- Pass 1: straight bind pose -> wave bones and their positions along the body.
scn, arm, meshes = load(True)
lo, hi, size, body, lat, up, heads = frame_axes(arm, meshes)
mw = arm.matrix_world
L = size[body]
roots = [b for b in arm.data.bones if b.parent is None]
root_c = mw @ roots[0].head_local
head_is_max = abs(root_c[body] - hi[body]) < abs(root_c[body] - lo[body])
mid_lat = sorted(h[lat] for h in heads)[len(heads) // 2]


def s_of(p):
    return (hi[body] - p[body]) / L if head_is_max else (p[body] - lo[body]) / L


wave_s = {}
for b in arm.data.bones:
    nm = b.name.lower()
    if b.parent is None or "root" in nm or "mch" in nm:
        continue  # root and control bones place the whole fish; never touch them
    p = mw @ ((b.head_local + b.tail_local) * 0.5)
    if abs(p[lat] - mid_lat) < L * 0.06 and s_of(p) > 0.15:
        wave_s[b.name] = s_of(p)
print("pass 1: body length %.2f (axis %s), wave bones: %d" % (L, "XYZ"[body], len(wave_s)))

# ---- Key the wave (same straight bind pose).
lo2, hi2, size2, body2, lat2, up2 = lo, hi, size, body, lat, up
mw = arm.matrix_world
up_vec = mathutils.Vector([1.0 if i == up2 else 0.0 for i in range(3)])
orig = arm.animation_data.action
frames = int(round(orig.frame_range[1] - orig.frame_range[0]))
f0 = int(orig.frame_range[0])
fps = scn.render.fps
print("pass 2: body axis %s, up %s" % ("XYZ"[body2], "XYZ"[up2]))


def avg_rotation(bone_name):
    """Average of the original clip's rotation for this bone (identity if it has no keys)."""
    curves = [orig.fcurves.find('pose.bones["%s"].rotation_quaternion' % bone_name, index=i) for i in range(4)]
    if any(c is None for c in curves):
        return mathutils.Quaternion()
    acc = mathutils.Vector((0.0, 0.0, 0.0, 0.0))
    ref = None
    for f in range(f0, f0 + frames, max(1, frames // 48)):
        q = mathutils.Quaternion([c.evaluate(f) for c in curves])
        if ref is None:
            ref = q
        if q.dot(ref) < 0.0:
            q = -q
        acc += mathutils.Vector(q)
    return mathutils.Quaternion(acc.normalized())


def theta(s, phase):
    # Slope angle of the midline for the travelling wave; growth stops past the tail tip.
    s = max(0.0, min(s, 1.15))
    k = 2 * math.pi
    a = tail_amp * (0.1 * s + 0.9 * s * s)
    da = tail_amp * (0.1 + 1.8 * s)
    return math.atan(da * math.sin(k * s - phase) + a * k * math.cos(k * s - phase))


wave = [b for b in arm.data.bones if b.name in wave_s]
names = set(wave_s)
neutral = {b.name: mathutils.Quaternion() for b in wave}  # wave relative to the straight bind pose
local_up = {}
for b in wave:
    m = (mw.to_3x3() @ b.matrix_local.to_3x3()).inverted()
    local_up[b.name] = (m @ up_vec).normalized()

act = orig.copy()
act.name = "Swim"
for fc in list(act.fcurves):
    if fc.data_path.startswith('pose.bones["'):
        if fc.data_path.split('"')[1] in names and "rotation" in fc.data_path:
            act.fcurves.remove(fc)
arm.animation_data.action = act
for pb in arm.pose.bones:
    pb.rotation_mode = "QUATERNION"

for f in range(frames + 1):
    phase = 2 * math.pi * beats * f / frames
    for b in wave:
        s = wave_s[b.name]
        if b.parent and b.parent.name in names:
            d = theta(s, phase) - theta(wave_s[b.parent.name], phase)
        else:
            d = theta(s, phase)  # first wave bone: slope relative to the stiff head
        pb = arm.pose.bones[b.name]
        pb.rotation_quaternion = mathutils.Quaternion(local_up[b.name], d) @ neutral[b.name]
        pb.keyframe_insert("rotation_quaternion", frame=f0 + f)
for fc in act.fcurves:
    if fc.data_path.split('"')[1] in names:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
bpy.data.actions.remove(orig)
act.use_fake_user = True

if proof:
    # Top view of the posed fish (look down its "up" axis), 8 frames across one tail beat.
    os.makedirs(proof, exist_ok=True)
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"
    scn.display.shading.color_type = "TEXTURE"
    scn.render.resolution_x, scn.render.resolution_y = 360, 360
    scn.frame_set(f0)
    dg = bpy.context.evaluated_depsgraph_get()
    pp = []
    for m in meshes:
        ev = m.evaluated_get(dg)
        me = ev.to_mesh()
        pp += [ev.matrix_world @ v.co for v in me.vertices]
        ev.to_mesh_clear()
    plo = mathutils.Vector([min(p[i] for p in pp) for i in range(3)])
    phi = mathutils.Vector([max(p[i] for p in pp) for i in range(3)])
    c = (plo + phi) / 2
    cd = bpy.data.cameras.new("cam")
    cd.type = "ORTHO"
    cd.ortho_scale = max(phi - plo) * 1.3
    cd.clip_end = 1e5
    cam = bpy.data.objects.new("cam", cd)
    scn.collection.objects.link(cam)
    scn.camera = cam
    cam.location = c + up_vec * L * 10
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    per_beat = frames / beats
    for i in range(8):
        scn.frame_set(f0 + int(round(i * per_beat / 8)))
        scn.render.filepath = os.path.join(proof, "top_%02d.png" % i)
        bpy.ops.render.render(write_still=True)

bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_animations=True,
                          export_animation_mode="ACTIONS", export_force_sampling=True)
print("baked %s: %d frames, %d beats -> %.2f Hz native" % (os.path.basename(dst), frames, beats, beats / (frames / fps)))
