# Blender: import each raw fish GLB, report exact evaluated bounds, eye positions, and
# render three orthographic views (side from +X, top from +Y, front from +Z) with Workbench.
# blender -b -P tools/blender_inspect.py -- <raw_dir> <out_dir>
import bpy, sys, os, mathutils

raw, out = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(out, exist_ok=True)

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def world_verts(obj, depsgraph):
    ev = obj.evaluated_get(depsgraph)
    me = ev.to_mesh()
    pts = [ev.matrix_world @ v.co for v in me.vertices]
    ev.to_mesh_clear()
    return pts

for f in sorted(os.listdir(raw)):
    if not f.endswith(".glb") or "lionfish" in f:
        continue
    clear()
    bpy.ops.import_scene.gltf(filepath=os.path.join(raw, f))
    dg = bpy.context.evaluated_depsgraph_get()
    allp = []
    eyes = []
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        pts = world_verts(o, dg)
        allp += pts
        mats = " ".join(m.name.lower() for m in o.data.materials if m)
        if any(k in (o.name.lower() + " " + mats) for k in ("eye", "iris", "sclara", "pupil", "lens")):
            eyes += pts
    lo = mathutils.Vector([min(p[i] for p in allp) for i in range(3)])
    hi = mathutils.Vector([max(p[i] for p in allp) for i in range(3)])
    size = hi - lo
    c = (lo + hi) / 2
    eye_c = sum(eyes, mathutils.Vector()) / len(eyes) if eyes else None
    print(f"BOUNDS {f} lo={tuple(round(x,3) for x in lo)} hi={tuple(round(x,3) for x in hi)} size={tuple(round(x,3) for x in size)} eyes={tuple(round(x,3) for x in eye_c) if eye_c else None}")
    # Render three views.
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"
    scn.display.shading.color_type = "TEXTURE"
    scn.render.resolution_x, scn.render.resolution_y = 480, 320
    span = max(size) * 1.15
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = span
    cam = bpy.data.objects.new("cam", cam_data)
    scn.collection.objects.link(cam)
    scn.camera = cam
    # Blender is Z-up; glTF +Y up maps to Blender +Z, glTF +Z maps to Blender -Y.
    views = {"side_from_gltf+X": (mathutils.Vector((1, 0, 0)), "Z"),
             "top_from_gltf+Y": (mathutils.Vector((0, 0, 1)), "Y"),
             "front_from_gltf+Z": (mathutils.Vector((0, -1, 0)), "Z")}
    for name, (d, up) in views.items():
        cam.location = c + d * span * 4
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", up).to_euler()
        scn.render.filepath = os.path.join(out, f"{f[:-4]}__{name}.png")
        bpy.ops.render.render(write_still=True)
