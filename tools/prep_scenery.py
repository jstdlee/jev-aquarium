# Blender: turn the downloaded scenery sources into clean, game-ready GLBs in assets/scenery/.
# Each output is one mesh: transforms baked, polygon count reduced to a budget, base centred on the
# origin, largest dimension 1.0. Sizes in the tank are set in scripts/scenery.gd.
# Writes assets/scenery/index.json with each piece's proportions (glTF axes, Y up).
# blender -b -P tools/prep_scenery.py
import bpy, bmesh, json, os, mathutils

RAW = "assets/raw"
PH = "assets/polyhaven"
OUT = "assets/scenery"
PACK = f"{RAW}/aquariumplants_java_fern_vallisneria_etc.glb"

# (output name, source file, mesh-name prefixes to keep (None = all), triangle budget)
ITEMS = [
    ("vallisneria", PACK, ["Vallisneria"], 9000),
    ("java_fern", PACK, ["Java Vern Narrow"], 9000),
    ("red_tiger_lotus", PACK, ["Red Tiger Lotus"], 7000),
    ("staurogyne", PACK, ["Staurogyne Repens_"], 2500),
    ("staurogyne_b", PACK, ["Staurogyne Repens2"], 2500),
    ("pack_universal", PACK, ["Universal"], 9000),
    ("anubias", f"{RAW}/aquariumplants_like_anubia_barteri.glb", None, 40000),
    ("driftwood", f"{RAW}/real_aquarium_wood_3d_scan.glb", None, 40000),
    ("temple", f"{RAW}/temple_ruin_aquarium_decoration_-_photoscan.glb", None, 30000),
    ("shell", f"{RAW}/sea_shell_photogrammetry.glb", None, 5000),
    ("boulder", f"{PH}/boulder_01/boulder_01.gltf", None, 25000),
    ("dragon_stones", f"{PH}/namaqualand_boulder_02/namaqualand_boulder_02.gltf", None, 30000),
    ("trunk", f"{PH}/dead_tree_trunk_02/dead_tree_trunk_02.gltf", None, 25000),
    ("quiver_branch", f"{PH}/dead_quiver_branch_01/dead_quiver_branch_01.gltf", None, 15000),
    ("branch_a", f"{PH}/dry_branches_medium_01/dry_branches_medium_01.gltf", ["dry_branches_medium_01_a"], 6000),
    ("branch_b", f"{PH}/dry_branches_medium_01/dry_branches_medium_01.gltf", ["dry_branches_medium_01_b"], 6000),
    ("branch_c", f"{PH}/dry_branches_medium_01/dry_branches_medium_01.gltf", ["dry_branches_medium_01_c"], 6000),
    ("fern_big", f"{PH}/fern_02/fern_02.gltf", ["fern_02_b"], 3000),
    ("fern_wide", f"{PH}/fern_02/fern_02.gltf", ["fern_02_c"], 3000),
]
for i in range(1, 7):
    ITEMS.append((f"moss_rock_{i}", f"{PH}/rock_moss_set_01/rock_moss_set_01.gltf", [f"rock_moss_set_01_rock0{i}"], 8000))
for i in range(7, 14):
    ITEMS.append((f"moss_stone_{i}", f"{PH}/rock_moss_set_02/rock_moss_set_02.gltf", [f"rock_moss_set_02_rock{i:02d}"], 6000))


def load(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


index = {}
os.makedirs(OUT, exist_ok=True)
for name, src, keep, budget in ITEMS:
    load(src)
    objs = [o for o in bpy.context.scene.objects
            if o.type == "MESH" and o.name != "Icosphere"
            and (keep is None or any(o.name.startswith(k) for k in keep))]
    if not objs:
        print(f"SKIP {name}: no mesh matched {keep}")
        continue
    # Bake world transforms into the mesh data (removes the near-zero node scales).
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        o.data = o.data.copy()
        o.data.transform(o.matrix_world)
        o.parent = None
        o.matrix_world = mathutils.Matrix.Identity(4)
        for m in list(o.modifiers):
            o.modifiers.remove(m)
    for o in list(bpy.context.scene.objects):
        if o not in objs:
            bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    tris = tri_count(obj)
    if tris > budget:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.ratio = budget / tris
        bpy.ops.object.modifier_apply(modifier=mod.name)
    # Base centre at the origin, largest dimension 1.
    vs = [v.co for v in obj.data.vertices]
    lo = mathutils.Vector([min(v[i] for v in vs) for i in range(3)])
    hi = mathutils.Vector([max(v[i] for v in vs) for i in range(3)])
    size = hi - lo
    s = 1.0 / max(size)
    obj.data.transform(mathutils.Matrix.Scale(s, 4) @ mathutils.Matrix.Translation(-mathutils.Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))))
    obj.data.update()
    obj.name = name
    out = f"{OUT}/{name}.glb"
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=True)
    # Blender (x, y, z-up) -> glTF (x, z, -y)
    index[name] = {"width": round(size.x * s, 4), "height": round(size.z * s, 4), "depth": round(size.y * s, 4),
                   "tris": tri_count(obj), "source": src}
    print(f"OK {name}: tris {tris} -> {tri_count(obj)}, w/h/d {index[name]['width']}/{index[name]['height']}/{index[name]['depth']}")

with open(f"{OUT}/index.json", "w") as f:
    json.dump(index, f, indent=1)
