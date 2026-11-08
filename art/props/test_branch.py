"""Castor test branch: create, alter and export it from Blender.

Technical asset for milestone 1, not final art. The editable source is test_branch.blend;
the file used by the game is game/assets/props/test_branch.glb (generated).

Usage, from the repository root (see docs/castor/how-to-run.md):
  blender --background --factory-startup --python art/props/test_branch.py -- create
  blender --background --factory-startup art/props/test_branch.blend --python art/props/test_branch.py -- alter
  blender --background --factory-startup art/props/test_branch.blend --python art/props/test_branch.py -- export

Conventions: 1 Blender unit = 1 meter; length along +X; origin at the center of the
branch, at ground level (the bark rests on Z=0); Z up in Blender, converted to Y up
by the glTF exporter.
"""

import math
import os
import sys

import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND_PATH = os.path.join(ROOT, "art", "props", "test_branch.blend")
GLB_PATH = os.path.join(ROOT, "game", "assets", "props", "test_branch.glb")
LENGTH = 1.2
RADIUS = 0.06


def material(name, color):
    result = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = 0.85
    return result


def cylinder(name, radius, depth, location, rotation, mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=radius, depth=depth,
                                        location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    bpy.ops.object.shade_flat()
    return obj


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.active_object
    result.name = name
    result.data.name = name
    # Apply rotation/scale so the exported object has no hidden transforms.
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # Origin at the center and on the ground, regardless of added geometry.
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return result


def create():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bark = material("Bark", (0.13, 0.06, 0.02))
    tip = material("CutTip", (0.93, 0.78, 0.50))
    trunk = cylinder("Trunk", RADIUS, LENGTH, (0, 0, RADIUS), (0, math.radians(90), 0), bark)
    twig = cylinder("Twig", RADIUS * 0.45, 0.42, (0.18, 0.13, RADIUS * 0.45),
                    (0, math.radians(90), math.radians(35)), bark)
    # Light cap on one end to read the orientation (+X) in the engine.
    cap = cylinder("Cap", RADIUS * 0.85, 0.01, (LENGTH / 2 + 0.002, 0, RADIUS),
                   (0, math.radians(90), 0), tip)
    join([trunk, twig, cap], "Branch")
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    print("BRANCH_CREATED", BLEND_PATH)


def alter():
    """Visible test change: two green leaves on the twig."""
    branch = bpy.data.objects["Branch"]
    if any(m and m.name == "Leaf" for m in branch.data.materials):
        print("BRANCH_ALREADY_ALTERED")
        return
    leaf = material("Leaf", (0.30, 0.68, 0.22))
    leaves = []
    for index, (x, y) in enumerate([(0.33, 0.26), (0.36, 0.20)]):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=0.07,
                                             location=(x, y, 0.05 + index * 0.02))
        obj = bpy.context.active_object
        obj.scale = (1.6, 0.8, 0.35)
        obj.data.materials.append(leaf)
        bpy.ops.object.transform_apply(scale=True)
        bpy.ops.object.shade_flat()
        leaves.append(obj)
    join([branch] + leaves, "Branch")
    bpy.ops.wm.save_mainfile()
    print("BRANCH_ALTERED", BLEND_PATH)


def export():
    os.makedirs(os.path.dirname(GLB_PATH), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=GLB_PATH, export_format="GLB", export_yup=True,
                              export_apply=True, use_selection=False)
    print("BRANCH_EXPORTED", GLB_PATH)


if __name__ == "__main__":
    action = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else ""
    {"create": create, "alter": alter, "export": export}[action]()
