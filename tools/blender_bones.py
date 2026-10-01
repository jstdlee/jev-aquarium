# Blender: print each fish's bone hierarchy with rest positions (glTF axes) so the spine chain
# (head -> tail) and the side-to-side bend axis can be identified for procedural swimming.
# blender -b -P tools/blender_bones.py -- <glb> [<glb> ...]
import bpy, sys, mathutils
for f in sys.argv[sys.argv.index("--") + 1:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f)
    arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    print("FILE", f.split("/")[-1], "armatures", len(arm))
    if not arm:
        continue
    a = arm[0]
    def g(v):  # Blender world -> glTF axes
        w = a.matrix_world @ v
        return (round(w.x, 2), round(w.z, 2), round(-w.y, 2))
    def walk(b, depth):
        print("  " * depth + f"- {b.name[:28]:28} head={g(b.head_local)} tail={g(b.tail_local)} len={b.length*a.matrix_world.to_scale().x:.2f}")
        for c in b.children:
            walk(c, depth + 1)
    for b in a.data.bones:
        if b.parent is None:
            walk(b, 1)
