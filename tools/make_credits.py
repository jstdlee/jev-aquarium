#!/usr/bin/env python3
"""Write CREDITS.md from the author/license/source metadata Sketchfab embeds in each GLB."""
import glob, json, os, struct

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = []
for f in sorted(glob.glob(os.path.join(root, "assets", "raw", "*.glb"))):
    b = open(f, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    ex = json.loads(b[20:20 + n]).get("asset", {}).get("extras", {})
    rows.append((ex.get("title", os.path.basename(f)), ex.get("author", "?"), ex.get("license", "?"), ex.get("source", "")))

with open(os.path.join(root, "CREDITS.md"), "w") as out:
    out.write("# Credits\n\nThird-party 3D models used in this game. CC-BY 4.0 works are used with credit as the license requires; ")
    out.write("some were modified (re-oriented, scaled, cleaned of stray geometry).\n\n")
    out.write("| Model | Author | License | Source |\n|---|---|---|---|\n")
    for t, a, l, s in rows:
        out.write(f"| {t} | {a} | {l} | {s} |\n")
    ph = sorted(os.listdir(os.path.join(root, "assets", "polyhaven"))) + sorted(os.listdir(os.path.join(root, "assets", "textures")))
    out.write("\nScanned rocks, wood, plants and ground textures from [Poly Haven](https://polyhaven.com), CC0 (no attribution required, credited with thanks): ")
    out.write(", ".join(ph) + ".\n")
print(f"{len(rows)} models credited")
