# Blender: list mesh parts (size, triangles, location) of scenery assets and render a preview of each file.
# blender -b -P tools/blender_scenery.py -- <out_dir> <file> [<file> ...]
import bpy, sys, os, mathutils
args = sys.argv[sys.argv.index("--") + 1:]
out, files = args[0], args[1:]
os.makedirs(out, exist_ok=True)
for f in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if f.endswith(".gltf") or f.endswith(".glb"):
        bpy.ops.import_scene.gltf(filepath=f)
    dg = bpy.context.evaluated_depsgraph_get()
    allp = []
    print(f"FILE {os.path.basename(f)}")
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or o.name == "Icosphere":
            continue
        ev = o.evaluated_get(dg); me = ev.to_mesh()
        pts = [ev.matrix_world @ v.co for v in me.vertices]
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        ev.to_mesh_clear()
        if not pts:
            continue
        lo = mathutils.Vector([min(p[i] for p in pts) for i in range(3)]); hi = mathutils.Vector([max(p[i] for p in pts) for i in range(3)])
        allp += [lo, hi]
        print(f"  PART {o.name[:40]:40} tris={tris:7d} size(x,y,z)={tuple(round(v,2) for v in hi-lo)} center={tuple(round(v,2) for v in (lo+hi)/2)}")
    lo = mathutils.Vector([min(p[i] for p in allp) for i in range(3)]); hi = mathutils.Vector([max(p[i] for p in allp) for i in range(3)])
    c = (lo + hi) / 2; size = hi - lo
    print(f"  TOTAL size(x,y,z)={tuple(round(v,2) for v in size)} (Blender Z is up)")
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"
    scn.display.shading.color_type = "TEXTURE"
    scn.render.resolution_x, scn.render.resolution_y = 480, 320
    cd = bpy.data.cameras.new("cam"); cd.type = "ORTHO"; cd.ortho_scale = max(size.x, size.z * 1.5) * 1.1; cd.clip_end = 1e6
    cam = bpy.data.objects.new("cam", cd); scn.collection.objects.link(cam); scn.camera = cam
    cam.location = c + mathutils.Vector((0, -1, 0)) * max(size) * 3
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = os.path.join(out, os.path.basename(f).rsplit(".", 1)[0] + ".png")
    bpy.ops.render.render(write_still=True)
