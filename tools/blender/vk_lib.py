"""Shared helpers for the Vân Khê Blender generators.

Every generator runs in its own background Blender process:
    blender --background --factory-startup --python tools/blender/<script>.py
Geometry is built with bmesh into a single object per asset so materials, UVs,
smoothing and skin weights stay explicit. Units are metres, Z-up in Blender,
characters face -Y (glTF export turns this into +Z forward, Y-up).
"""
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "art"
MODELS = ROOT / "assets" / "models"
DATA = ROOT / "data"
PREVIEW = ROOT / ".cache" / "blender_previews"

# sRGB hex palette shared by every asset; Godot converts these to toon materials.
PALETTE = {
    "jade": "2f9e94", "jade_dark": "1d6b67", "jade_light": "86d4c6",
    "bamboo": "6fae4f", "bamboo_dark": "3f7d3a", "bamboo_light": "b4d878",
    "cream": "f3e6c8", "cream_dark": "d6c196", "white": "fbf7ee",
    "vermilion": "c8402e", "vermilion_dark": "8a2a22", "gold": "e9b24a",
    "lantern": "ffc35a", "wood": "8a5a3b", "wood_dark": "573827", "wood_light": "b98b5e",
    "roof": "3b5a60", "roof_dark": "2a4045", "stone": "a9a38e", "stone_dark": "7a7666",
    "stone_light": "cfc8b0", "moss": "7b9a55", "skin": "f7d7c0", "skin_shadow": "e7b9a0",
    "hair": "262b38", "hair_white": "e9e6df", "hair_brown": "5a3b2c", "cloth_dark": "2c3a3f",
    "cloth_blue": "3c5d86", "cloth_brown": "7a5537", "leather": "5b3a26", "metal": "b9c3c4",
    "metal_dark": "5d666a", "bronze": "9c7a3c", "paper": "efe3c2", "ink": "1b1d22",
    "iris": "2a7f86", "iris_amber": "b47a2c", "mask": "ece6d8", "boar": "6b4a35",
    "boar_dark": "3f2b20", "tusk": "efe6cf", "spirit": "8fe3d6", "seal": "d9473a",
}
EMISSIVE = {"lantern": 2.2, "spirit": 1.6, "seal": 1.4}


def srgb_to_linear(value):
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def color(name):
    hex_value = PALETTE[name]
    return tuple(srgb_to_linear(int(hex_value[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    prefs = bpy.context.preferences.filepaths
    prefs.save_version = 0
    preview = prefs.bl_rna.properties.get("file_preview_type")
    if preview and "NONE" in {item.identifier for item in preview.enum_items}:
        prefs.file_preview_type = "NONE"
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.fps = 30


def material(name):
    key = "VK_" + name
    existing = bpy.data.materials.get(key)
    if existing:
        return existing
    mat = bpy.data.materials.new(key)
    rgb = color(name)
    mat.diffuse_color = (*rgb, 1.0)
    mat.use_nodes = True
    shader = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*rgb, 1.0)
    shader.inputs["Roughness"].default_value = 0.9
    if name.startswith("metal") or name == "bronze":
        shader.inputs["Metallic"].default_value = 0.6
        shader.inputs["Roughness"].default_value = 0.45
    if name in EMISSIVE:
        shader.inputs["Emission Color"].default_value = (*rgb, 1.0)
        shader.inputs["Emission Strength"].default_value = EMISSIVE[name]
    return mat


class MeshBuilder:
    """Accumulates primitives into one bmesh with material slots and skin weights."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.deform = self.bm.verts.layers.deform.verify()
        self.uv = self.bm.loops.layers.uv.verify()
        self.materials = []
        self.groups = []

    def _index(self, items, value):
        if value not in items:
            items.append(value)
        return items.index(value)

    def _finish(self, verts, mat, bone, matrix, smooth, sharp_angle):
        bmesh.ops.transform(self.bm, matrix=matrix, verts=verts)
        faces = {face for vert in verts for face in vert.link_faces}
        mat_index = self._index(self.materials, mat)
        for face in faces:
            face.material_index = mat_index
            face.smooth = smooth
        if smooth and sharp_angle is not None:
            edges = {edge for face in faces for edge in face.edges}
            for edge in edges:
                if len(edge.link_faces) == 2 and edge.calc_face_angle(0.0) > math.radians(sharp_angle):
                    edge.smooth = False
        if bone:
            self.weight(verts, bone)
        return verts

    def box(self, size, loc=(0, 0, 0), rot=(0, 0, 0), mat="stone", bone=None, bevel=0.0, taper=None, smooth=False, segments=1, scale=(1, 1, 1)):
        before = set(self.bm.verts)
        result = bmesh.ops.create_cube(self.bm, size=1.0)
        for vert in result["verts"]:
            vert.co = Vector((vert.co.x * size[0], vert.co.y * size[1], vert.co.z * size[2]))
            if taper is not None and vert.co.z > 0:
                vert.co.x *= taper[0]
                vert.co.y *= taper[1]
        if bevel > 0:
            edges = list({edge for vert in result["verts"] for edge in vert.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=segments, affect="EDGES", profile=0.5, clamp_overlap=True)
        verts = [vert for vert in self.bm.verts if vert not in before]
        return self._finish(verts, mat, bone, _matrix(loc, rot, scale), smooth or bevel > 0, 35 if bevel > 0 else None)

    def cylinder(self, radius, depth, loc=(0, 0, 0), rot=(0, 0, 0), mat="wood", bone=None, top=None, segments=10, smooth=True, cap=True, scale=(1, 1, 1), sharp=50):
        result = bmesh.ops.create_cone(self.bm, cap_ends=cap, cap_tris=False, segments=segments,
                                       radius1=radius, radius2=radius if top is None else top, depth=depth)
        return self._finish(result["verts"], mat, bone, _matrix(loc, rot, scale), smooth, sharp)

    def cone(self, radius, depth, loc=(0, 0, 0), rot=(0, 0, 0), mat="wood", bone=None, segments=8, smooth=True, scale=(1, 1, 1)):
        return self.cylinder(radius, depth, loc, rot, mat, bone, top=0.0, segments=segments, smooth=smooth, scale=scale)

    def sphere(self, radius, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), mat="stone", bone=None, segments=12, rings=8, smooth=True, shape=None):
        result = bmesh.ops.create_uvsphere(self.bm, u_segments=segments, v_segments=rings, radius=radius)
        verts = result["verts"]
        for vert in verts:
            vert.co = Vector((vert.co.x * scale[0], vert.co.y * scale[1], vert.co.z * scale[2]))
            if shape:
                vert.co = shape(vert.co)
        return self._finish(verts, mat, bone, _matrix(loc, rot), smooth, 70)

    def segment(self, start, end, radius, end_radius=None, mat="wood", bone=None, segments=10, smooth=True, cap=True, flat=1.0):
        """Cylinder (or cone) spanning two points; `flat` squashes the cross-section."""
        start, end = Vector(start), Vector(end)
        axis = end - start
        rotation = axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
        matrix = Matrix.Translation((start + end) * 0.5) @ rotation @ Matrix.Diagonal(Vector((1.0, flat, 1.0, 1.0)))
        result = bmesh.ops.create_cone(self.bm, cap_ends=cap, cap_tris=False, segments=segments, radius1=radius,
                                       radius2=radius if end_radius is None else end_radius, depth=axis.length)
        return self._finish(result["verts"], mat, bone, matrix, smooth, 50)

    def torus(self, major, minor, loc=(0, 0, 0), rot=(0, 0, 0), mat="gold", bone=None, segments=16, ring=6):
        verts = []
        rings = []
        for i in range(segments):
            angle = math.tau * i / segments
            ring_verts = []
            for j in range(ring):
                tube = math.tau * j / ring
                radius = major + minor * math.cos(tube)
                ring_verts.append(self.bm.verts.new((radius * math.cos(angle), radius * math.sin(angle), minor * math.sin(tube))))
            rings.append(ring_verts)
            verts.extend(ring_verts)
        for i in range(segments):
            a, b = rings[i], rings[(i + 1) % segments]
            for j in range(ring):
                self.bm.faces.new((a[j], b[j], b[(j + 1) % ring], a[(j + 1) % ring]))
        return self._finish(verts, mat, bone, _matrix(loc, rot), True, 70)

    def loft(self, sections, mat="cloth_dark", bone=None, loc=(0, 0, 0), rot=(0, 0, 0), cap_bottom=True, cap_top=True, smooth=True, sharp_angle=55):
        """sections: list of point rings (same count) from bottom to top, CCW seen from above."""
        rings = [[self.bm.verts.new(point) for point in ring] for ring in sections]
        count = len(sections[0])
        for lower, upper in zip(rings, rings[1:]):
            for i in range(count):
                self.bm.faces.new((lower[i], lower[(i + 1) % count], upper[(i + 1) % count], upper[i]))
        if cap_bottom:
            self.bm.faces.new(list(reversed(rings[0])))
        if cap_top:
            self.bm.faces.new(rings[-1])
        verts = [vert for ring in rings for vert in ring]
        if isinstance(bone, list):
            result = self._finish(verts, mat, None, _matrix(loc, rot), smooth, sharp_angle)
            for ring, ring_bone in zip(rings, bone):
                self.weight(ring, ring_bone)
            return result
        return self._finish(verts, mat, bone, _matrix(loc, rot), smooth, sharp_angle)

    def weight(self, verts, bone):
        weights = bone if isinstance(bone, dict) else {bone: 1.0}
        for group, value in weights.items():
            group_index = self._index(self.groups, group)
            for vert in verts:
                vert[self.deform][group_index] = value

    def strip(self, points, width, normal=(0, -1, 0), mat="cloth_dark", bone=None, thickness=0.01):
        """Ribbon along points with a little thickness so both sides render."""
        normal = Vector(normal).normalized()
        top, bottom = [], []
        for i, point in enumerate(points):
            point = Vector(point)
            ahead = Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])
            side = ahead.cross(normal).normalized() * (width[i] if isinstance(width, (list, tuple)) else width) * 0.5
            top.append((point + side + normal * thickness, point - side + normal * thickness))
            bottom.append((point + side - normal * thickness, point - side - normal * thickness))
        sections = []
        for (a, b), (c, d) in zip(top, bottom):
            sections.append([a, b, d, c])
        verts_rings = [[self.bm.verts.new(p) for p in ring] for ring in sections]
        for lower, upper in zip(verts_rings, verts_rings[1:]):
            for i in range(4):
                self.bm.faces.new((lower[i], lower[(i + 1) % 4], upper[(i + 1) % 4], upper[i]))
        self.bm.faces.new(verts_rings[0])
        self.bm.faces.new(list(reversed(verts_rings[-1])))
        verts = [vert for ring in verts_rings for vert in ring]
        return self._finish(verts, mat, bone, Matrix.Identity(4), True, 60)

    def build(self, collection=None):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.00001)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        _box_project_uv(self.bm, self.uv)
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for name in self.materials:
            mesh.materials.append(material(name))
        obj = bpy.data.objects.new(self.name, mesh)
        (collection or bpy.context.scene.collection).objects.link(obj)
        for group in self.groups:
            obj.vertex_groups.new(name=group)
        return obj


def _matrix(loc, rot, scale=(1, 1, 1)):
    scale_matrix = Matrix.Diagonal(Vector((*scale, 1.0)))
    return Matrix.Translation(Vector(loc)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4() @ scale_matrix


def _box_project_uv(bm, uv_layer, scale=1.0):
    for face in bm.faces:
        normal = face.normal
        axis = max(range(3), key=lambda i: abs(normal[i]))
        for loop in face.loops:
            co = loop.vert.co
            if axis == 0:
                loop[uv_layer].uv = (co.y * scale, co.z * scale)
            elif axis == 1:
                loop[uv_layer].uv = (co.x * scale, co.z * scale)
            else:
                loop[uv_layer].uv = (co.x * scale, co.y * scale)


def collider_box(name, size, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Godot import turns `-convcolonly` meshes into convex StaticBody3D shapes."""
    builder = MeshBuilder(name + "-convcolonly")
    builder.box(size, loc, rot, mat="stone")
    obj = builder.build()
    obj.data.materials.clear()
    return obj


def collider_cylinder(name, radius, depth, loc=(0, 0, 0), segments=8):
    builder = MeshBuilder(name + "-convcolonly")
    builder.cylinder(radius, depth, loc, mat="stone", segments=segments, smooth=False)
    obj = builder.build()
    obj.data.materials.clear()
    return obj


def triangle_count(objects=None):
    total = 0
    for obj in objects or bpy.context.scene.objects:
        if obj.type == "MESH" and "colonly" not in obj.name:
            obj.data.calc_loop_triangles()
            total += len(obj.data.loop_triangles)
    return total


def save_and_export(name, animations=False, extra=None):
    ART.mkdir(parents=True, exist_ok=True)
    MODELS.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ART / f"{name}.blend"), compress=True)
    options = dict(
        filepath=str(MODELS / f"{name}.glb"), export_format="GLB", use_selection=False,
        export_yup=True, export_apply=False, export_cameras=False, export_lights=False,
        export_animations=animations, export_skins=True, export_morph=False,
    )
    if animations:
        options.update(export_animation_mode="ACTIONS", export_force_sampling=True,
                       export_optimize_animation_size=False, export_reset_pose_bones=True,
                       export_def_bones=False, export_leaf_bone=False)
    bpy.ops.export_scene.gltf(**options)
    info = {"name": name, "bytes": (MODELS / f"{name}.glb").stat().st_size, "triangles": triangle_count()}
    if extra:
        info.update(extra)
    print("ASSET_OK " + json.dumps(info, ensure_ascii=False))
    return info


def write_manifest_entry(info, manifest_name):
    """Collect per-asset stats so docs/asset-manifest can be regenerated."""
    path = ROOT / ".cache" / "asset_stats" / f"{manifest_name}.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    existing = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    existing[info["name"]] = info
    path.write_text(json.dumps(existing, indent=1, ensure_ascii=False), encoding="utf-8")


def render_preview(name, views, size=(640, 640), target=None, frame=None):
    """Workbench turntable shots for quick visual review of a generated asset."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_object_outline = True
    shading.object_outline_color = (0.05, 0.06, 0.07)
    shading.show_cavity = False
    scene.render.film_transparent = False
    scene.world = scene.world or bpy.data.worlds.new("Preview")
    scene.render.resolution_x, scene.render.resolution_y = size
    if frame is not None:
        scene.frame_set(frame)
    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera_data.type = "ORTHO"
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    target = Vector(target or (0, 0, 0.9))
    for obj in scene.objects:
        if "colonly" in obj.name:
            obj.hide_render = True
    PREVIEW.mkdir(parents=True, exist_ok=True)
    paths = []
    for label, (yaw, pitch, ortho) in views.items():
        camera_data.ortho_scale = ortho
        direction = Euler((math.radians(-pitch), 0, math.radians(yaw)), "XYZ").to_matrix() @ Vector((0, -1, 0))
        camera.location = target + direction * 10
        camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
        path = PREVIEW / f"{name}_{label}.png"
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        paths.append(str(path))
    bpy.data.objects.remove(camera)
    return paths
