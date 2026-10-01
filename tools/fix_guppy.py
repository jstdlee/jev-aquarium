# Blender: the guppy's eye mesh (Circle.001) sits in front of its nose in the source model.
# Move it back into the head, shrink it a little, and export with the animation.
# blender -b -P tools/fix_guppy.py
import bpy, mathutils
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="assets/raw/guppy_fish.glb")
for o in list(bpy.context.scene.objects):
    if o.name == "Icosphere":
        bpy.data.objects.remove(o)
eyes = bpy.data.objects["Circle.001_0"]
me = eyes.data
c = sum((v.co for v in me.vertices), mathutils.Vector()) / len(me.vertices)
# Mesh-local coords; the object matrix maps local -> world. Shift by 0.95 world units toward the tail (-Y).
inv = eyes.matrix_world.inverted().to_3x3()
shift = inv @ mathutils.Vector((0.0, -0.95, -0.12))
for v in me.vertices:
    v.co = c + (v.co - c) * 0.8 + shift
me.update()
bpy.ops.export_scene.gltf(filepath="assets/fish/guppy.glb", export_format="GLB", export_animations=True)
print("guppy eyes moved")
