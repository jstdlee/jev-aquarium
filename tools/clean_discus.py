# Blender: remove stray vertices (a long thin strand far behind the tail) from the discus model,
# then export the cleaned model with its animation to assets/fish/discus.glb.
# blender -b -P tools/clean_discus.py
import bpy, bmesh
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="assets/raw/discus_3.glb")
for o in list(bpy.context.scene.objects):
    if o.name == "Icosphere":  # bone display shape added by the importer
        bpy.data.objects.remove(o)
mesh = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
# Decide by the posed (armature-evaluated) positions, which is how the model is seen.
dg = bpy.context.evaluated_depsgraph_get()
ev = mesh.evaluated_get(dg)
em = ev.to_mesh()
posed_x = [(ev.matrix_world @ v.co).x for v in em.vertices]
ev.to_mesh_clear()
bm = bmesh.new()
bm.from_mesh(mesh.data)
bm.verts.ensure_lookup_table()
assert len(bm.verts) == len(posed_x)
stray = [v for v in bm.verts if posed_x[v.index] > 70.0]
print("removing", len(stray), "stray vertices")
bmesh.ops.delete(bm, geom=stray, context="VERTS")
bm.to_mesh(mesh.data)
bm.free()
bpy.ops.export_scene.gltf(filepath="assets/fish/discus.glb", export_format="GLB", export_animations=True)
