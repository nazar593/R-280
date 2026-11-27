"""Convert the authored Blockbench Hornet to the project's Unity mesh format."""
import base64
import itertools
import json
import math
from pathlib import Path

assets = Path(__file__).resolve().parents[1] / "Assets"
source = json.loads((assets / "Art/Hornet.bbmodel").read_text())
texture = source["textures"][0]
width, height = source["resolution"]["width"], source["resolution"]["height"]
texture_path = assets / "Resources/Textures/Hornet.png"
texture_path.write_bytes(base64.b64decode(texture["source"].split(",", 1)[1]))

directions = {
    "north": (0, 1, 3, 2), "south": (5, 4, 6, 7),
    "west": (4, 0, 2, 6), "east": (1, 5, 7, 3),
    "up": (2, 3, 7, 6), "down": (4, 5, 1, 0),
}

def cube_vertices(element):
    start, end = element["from"], element["to"]
    ox, oy, oz = element["origin"]
    rx, ry, rz = element["rotation"]
    assert rx == ry == 0, "Handle a new cube rotation before reimporting."
    a = math.radians(rz)
    for iz, iy, ix in itertools.product((0,1), repeat=3):
        x = (end if ix else start)[0] - ox
        y = (end if iy else start)[1] - oy
        z = (end if iz else start)[2] - oz
        yield (ox + x*math.cos(a) - y*math.sin(a), oy + x*math.sin(a) + y*math.cos(a), oz + z)

parts = {}
for element in source["elements"]:
    # Leave the propeller's moving geometry in its own mesh, aligned with the fuselage.
    name = "propeller" if element["name"].startswith("Blade") else "airframe"
    part = parts.setdefault(name, dict(name=name, color=[1,1,1], vertices=[], uv=[], triangles=[], texture="Textures/Hornet"))
    is_cube = element["type"] == "cube"
    vertices = list(cube_vertices(element)) if is_cube else element["vertices"]
    for side, face in element["faces"].items():
        if face["texture"] is None:
            continue
        sequence = directions[side] if is_cube else face["vertices"]
        if is_cube:
            u1,v1,u2,v2 = face["uv"]
            uvs = [(u1,v2),(u2,v2),(u2,v1),(u1,v1)]
            quarter = face.get("rotation", 0) // 90
            uvs = uvs[quarter:] + uvs[:quarter]
        else:
            uvs = [face["uv"][key] for key in sequence]
        first = len(part["vertices"]) // 3
        for key, (u,v) in zip(sequence, uvs):
            x,y,z = vertices[key]
            part["vertices"] += [round(x/27,6), round((y-8.78)/27,6), round(-z/27,6)]
            part["uv"] += [round(u/width,6), round(1-v/height,6)]
        # Reflect Z to place the nose forward. Mesh faces and the cube lookup
        # start with opposite winding, so reverse only the authored mesh faces.
        for j in range(1,len(sequence)-1):
            a,b = (j,j+1) if is_cube else (j+1,j)
            part["triangles"] += [first,first+a,first+b]

(assets / "Resources/Meshes/hornet.json").write_text(json.dumps({"parts":list(parts.values())}, separators=(",",":")))
