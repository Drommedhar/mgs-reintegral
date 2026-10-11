"""glTF 2.0 mesh/rig conversion; no engine or proprietary asset dependencies."""

import base64
import json
import math
import struct
from collections import defaultdict

from godot_assets.formats import Part


def point(vector):
    return vector[0] / 1000, -vector[1] / 1000, -vector[2] / 1000


def resolve_vertex(parts: list[Part], owner: int, index: int):
    for _ in parts:
        part = parts[owner]
        if index >= len(part.vertices):
            raise ValueError("KMD vertex index out of range")
        vertex = part.vertices[index]
        if vertex[3] == -1:
            return owner, vertex[:3]
        if part.parent < 0:
            raise ValueError("Linked KMD vertex has no parent")
        owner, index = part.parent, vertex[3]
    raise ValueError("Cyclic KMD vertex ownership")


class Gltf:
    def __init__(self, identity: str):
        self.blob = bytearray()
        self.document = {
            "asset": {"version": "2.0", "generator": "mgs-integral-native"},
            "extensionsUsed": ["KHR_materials_unlit"],
            "extras": {"mgsAssetId": identity, "coordinateScale": 0.001},
            "bufferViews": [],
            "accessors": [],
            "meshes": [],
            "nodes": [],
            "materials": [],
            "textures": [],
            "images": [],
            "samplers": [
                {"magFilter": 9728, "minFilter": 9728, "wrapS": 33071, "wrapT": 33071}
            ],
        }

    def accessor(self, rows, scalar: str, kind: str, component: int, bounds=False):
        while len(self.blob) % 4:
            self.blob.append(0)
        data = b"".join(struct.pack("<" + scalar * len(row), *row) for row in rows)
        views = self.document["bufferViews"]
        accessors = self.document["accessors"]
        item = {
            "bufferView": len(views),
            "componentType": component,
            "count": len(rows),
            "type": kind,
        }
        view = {"buffer": 0, "byteOffset": len(self.blob), "byteLength": len(data)}
        if kind != "MAT4":
            view["target"] = 34962
        views.append(view)
        self.blob.extend(data)
        if bounds:
            item["min"] = list(map(min, zip(*rows)))
            item["max"] = list(map(max, zip(*rows)))
        accessors.append(item)
        return len(accessors) - 1

    def material(self, texture: int, textures: dict, flags: int):
        identity = f"{texture:04x}"
        material = {
            "name": identity,
            "doubleSided": bool(flags & 0x400),
            "alphaMode": "MASK",
            "alphaCutoff": 0.5,
            "extensions": {"KHR_materials_unlit": {}},
            "pbrMetallicRoughness": {"metallicFactor": 0, "roughnessFactor": 1},
            "extras": {"mgsTextureId": identity, "mgsModelFlags": flags},
        }
        if identity in textures:
            index = len(self.document["images"])
            self.document["images"].append({"uri": textures[identity]["uri"]})
            self.document["textures"].append({"source": index, "sampler": 0})
            material["pbrMetallicRoughness"]["baseColorTexture"] = {"index": index}
        else:
            material["extras"]["unresolvedTexture"] = True
            material["pbrMetallicRoughness"]["baseColorFactor"] = [1, 0, 1, 1]
        self.document["materials"].append(material)
        return len(self.document["materials"]) - 1

    def write(self, path):
        uri = "data:application/octet-stream;base64," + base64.b64encode(
            self.blob
        ).decode("ascii")
        self.document["buffers"] = [{"byteLength": len(self.blob), "uri": uri}]
        for key in ("meshes", "materials", "textures", "images"):
            if not self.document[key]:
                del self.document[key]
        if "textures" not in self.document:
            del self.document["samplers"]
        path.write_text(
            json.dumps(self.document, separators=(",", ":")), encoding="utf-8"
        )


def build_rig(gltf: Gltf, parts: list[Part]):
    nodes = gltf.document["nodes"]
    origins = []
    inverses = []
    for index, part in enumerate(parts):
        offset = point(part.translation)
        parent_origin = origins[part.parent] if part.parent >= 0 else (0, 0, 0)
        origin = tuple(a + b for a, b in zip(offset, parent_origin))
        origins.append(origin)
        nodes.append(
            {
                "name": f"part_{index:03d}",
                "translation": offset,
                "extras": {"mgsPart": index, "mgsParent": part.parent},
            }
        )
        if part.parent >= 0:
            nodes[part.parent].setdefault("children", []).append(index)
        inverses.append(
            (1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -origin[0], -origin[1], -origin[2], 1)
        )
    gltf.document["skins"] = [
        {
            "name": "original_rig",
            "joints": list(range(len(parts))),
            "inverseBindMatrices": gltf.accessor(inverses, "f", "MAT4", 5126),
        }
    ]
    return origins


def face_vertices(parts, part_index, face, origins, texture_size, color_layout):
    part = parts[part_index]
    vertices = []
    width, height = texture_size
    color_base, color_height = color_layout
    # DG_TransChanl accepts positive screen-space NCLIP (clockwise faces).
    for corner in (0, 3, 1, 1, 3, 2):
        entry = face * 4 + corner
        owner, local = resolve_vertex(parts, part_index, part.indices[entry])
        position = tuple(a + b for a, b in zip(point(local), origins[owner]))
        uv = (
            (part.uv[entry * 2] * width // 256 + 0.5) / width,
            (part.uv[entry * 2 + 1] * height // 256 + 0.5) / height,
        )
        color_index = color_base + face * 4 + corner
        shade_uv = (
            (color_index % 256 + 0.5) / 256,
            (color_index // 256 + 0.5) / color_height,
        )
        normal_index = part.normal_indices[entry]
        if part.flags & 0x10000:
            normal_index &= 0x7F
        if normal_index >= len(part.normals):
            raise ValueError("KMD normal index out of range")
        normal = point(part.normals[normal_index])
        length = math.sqrt(sum(value * value for value in normal))
        # DG lighting uses vertex-minus-light vectors; KMD normals point inward.
        normal = tuple(-value / length for value in normal) if length else None
        vertices.append(
            (position, uv, (owner, 0, 0, 0), (1, 0, 0, 0), shade_uv, normal)
        )
    return vertices


def convert_model(identity, count, parts, textures, path):
    gltf = Gltf(identity)
    origins = build_rig(gltf, parts)
    rig_root = len(gltf.document["nodes"])
    gltf.document["nodes"].append(
        {
            "name": "original_rig_root",
            "children": [i for i, part in enumerate(parts) if part.parent < 0],
        }
    )
    gltf.document["skins"][0]["skeleton"] = rig_root
    roots = [rig_root]
    color_count = sum(len(part.textures) * 4 for part in parts)
    color_height = max(1, (color_count + 255) // 256)
    color_base = 0
    for part_index, part in enumerate(parts):
        grouped = defaultdict(list)
        for face, texture in enumerate(part.textures):
            texture_data = textures.get(f"{texture:04x}")
            size = texture_data["size"] if texture_data is not None else [256, 256]
            grouped[texture].extend(
                face_vertices(
                    parts, part_index, face, origins, size, (color_base, color_height)
                )
            )
        primitives = []
        for texture, vertices in sorted(grouped.items()):
            position, uv, bones, weights, shade_uv, normals = map(list, zip(*vertices))
            attributes = {
                "POSITION": gltf.accessor(position, "f", "VEC3", 5126, True),
                "TEXCOORD_0": gltf.accessor(uv, "f", "VEC2", 5126),
                "TEXCOORD_1": gltf.accessor(shade_uv, "f", "VEC2", 5126),
                "JOINTS_0": gltf.accessor(bones, "H", "VEC4", 5123),
                "WEIGHTS_0": gltf.accessor(weights, "f", "VEC4", 5126),
            }
            if all(normal is not None for normal in normals):
                attributes["NORMAL"] = gltf.accessor(normals, "f", "VEC3", 5126)
            primitives.append(
                {
                    "attributes": attributes,
                    "material": gltf.material(texture, textures, part.flags),
                }
            )
        color_base += len(part.textures) * 4
        if primitives:
            mesh = len(gltf.document["meshes"])
            gltf.document["meshes"].append(
                {"name": f"mesh_{part_index:03d}", "primitives": primitives}
            )
            roots.append(len(gltf.document["nodes"]))
            gltf.document["nodes"].append(
                {
                    "name": f"mesh_{part_index:03d}",
                    "mesh": mesh,
                    "skin": 0,
                    "extras": {
                        "mgsPart": part_index,
                        "mgsExtension": part_index >= count,
                    },
                }
            )
    gltf.document["scenes"] = [{"nodes": roots}]
    gltf.document["scene"] = 0
    gltf.document["extras"]["rig"] = [
        {"name": f"part_{i:03d}", "parent": p.parent} for i, p in enumerate(parts)
    ]
    gltf.write(path)
    return {
        "parts": count,
        "extendedParts": len(parts),
        "colorCount": color_count,
        "surfaces": sum(len(m["primitives"]) for m in gltf.document["meshes"]),
        "unresolvedTextures": sorted(
            {
                m["name"]
                for m in gltf.document["materials"]
                if m["extras"].get("unresolvedTexture")
            }
        ),
    }
