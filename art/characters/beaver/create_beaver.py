"""Build Castor's original low-poly beaver and export its rigged glTF asset.

Run with Blender 5.2.3: blender --background --factory-startup --python create_beaver.py
"""
import bpy
import math
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(__file__).resolve().parent
EXPORT = ROOT / "game" / "assets" / "characters" / "beaver" / "Beaver.glb"
LENGTH_SCALE = 0.72

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.armatures, bpy.data.actions):
    for block in list(datablocks):
        if block.users == 0:
            datablocks.remove(block)

def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1.0)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.82
    return mat

fur = material("Warm chestnut fur", (0.32, 0.115, 0.045))
fur_light = material("Muzzle and belly", (0.66, 0.39, 0.20))
tail_mat = material("Dark paddle tail", (0.16, 0.105, 0.075))
tooth_mat = material("Ivory incisors", (0.92, 0.79, 0.56))
eye_mat = material("Dark eyes", (0.025, 0.018, 0.012))
nose_mat = material("Nose", (0.08, 0.045, 0.035))

# Build a simple, named armature in Blender's Z-up coordinates; -Y is forward.
arm_data = bpy.data.armatures.new("BeaverRig")
arm = bpy.data.objects.new("BeaverRig", arm_data)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bones = {
    "Root": ((0, 0, 0.42), (0, 0, 0.72), None),
    "Body": ((0, 0.0, 0.48), (0, -0.15, 0.88), "Root"),
    "Head": ((0, -0.43, 0.82), (0, -0.78, 0.87), "Body"),
    "Tail": ((0, 0.40, 0.48), (0, 0.95, 0.18), "Root"),
    "LegFront.L": ((-0.21, -0.20, 0.40), (-0.21, -0.20, 0.12), "Body"),
    "LegFront.R": ((0.21, -0.20, 0.40), (0.21, -0.20, 0.12), "Body"),
    "LegBack.L": ((-0.22, 0.32, 0.37), (-0.22, 0.32, 0.10), "Body"),
    "LegBack.R": ((0.22, 0.32, 0.37), (0.22, 0.32, 0.10), "Body"),
}
for name, (head, tail, parent) in bones.items():
    bone = arm_data.edit_bones.new(name)
    bone.head, bone.tail = (head[0], head[1] * LENGTH_SCALE, head[2]), (tail[0], tail[1] * LENGTH_SCALE, tail[2])
    if parent:
        bone.parent = arm_data.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")
arm.select_set(False)

def ellipsoid(name, loc, scale, mat, bone, segments=12, rings=8):
    loc = (loc[0], loc[1] * LENGTH_SCALE, loc[2])
    scale = (scale[0], scale[1] * LENGTH_SCALE, scale[2])
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    mod = obj.modifiers.new("BeaverRig", "ARMATURE")
    mod.object = arm
    obj.parent = arm
    return obj

# Compact silhouette: low body, unmistakable broad paddle, blunt muzzle and incisors.
ellipsoid("BodyMesh", (0, 0.03, 0.55), (0.34, 0.57, 0.36), fur, "Body", 16, 10)
ellipsoid("BellyMesh", (0, -0.02, 0.39), (0.27, 0.40, 0.16), fur_light, "Body")
ellipsoid("HeadMesh", (0, -0.48, 0.83), (0.30, 0.32, 0.29), fur, "Head", 16, 10)
ellipsoid("MuzzleMesh", (0, -0.75, 0.70), (0.23, 0.22, 0.15), fur_light, "Head")
ellipsoid("NoseMesh", (0, -0.94, 0.76), (0.10, 0.065, 0.065), nose_mat, "Head")
ellipsoid("TailMesh", (0, 0.68, 0.26), (0.30, 0.48, 0.075), tail_mat, "Tail", 16, 8)
for side, suffix in [(-1, "L"), (1, "R")]:
    ellipsoid("Ear" + suffix, (side * 0.25, -0.43, 1.06), (0.085, 0.07, 0.10), fur_light, "Head")
    ellipsoid("Eye" + suffix, (side * 0.22, -0.68, 0.90), (0.045, 0.04, 0.05), eye_mat, "Head")
    ellipsoid("Incisor" + suffix, (side * 0.055, -0.91, 0.59), (0.045, 0.075, 0.07), tooth_mat, "Head", 8, 6)
    ellipsoid("FrontPaw" + suffix, (side * 0.21, -0.20, 0.13), (0.10, 0.13, 0.09), fur_light, "LegFront." + suffix)
    ellipsoid("HindPaw" + suffix, (side * 0.22, 0.32, 0.11), (0.12, 0.15, 0.09), fur_light, "LegBack." + suffix)

def animate(name, frame_keys):
    action = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = action
    for bone_name, keys in frame_keys.items():
        pose = arm.pose.bones[bone_name]
        for frame, rotation in keys:
            pose.rotation_mode = "XYZ"
            pose.rotation_euler = rotation
            pose.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)
    action.use_fake_user = True
    return action

idle = animate("Idle", {"Body": [(1,(0,0,0)),(16,(0,0.025,0)),(32,(0,0,0))], "Tail": [(1,(0,0,0)),(16,(0.04,0,0)),(32,(0,0,0))]})
walk = animate("Walk", {
    "LegFront.L": [(1,(0,0,0.28)),(7,(0,0,-0.28)),(13,(0,0,0.28))],
    "LegFront.R": [(1,(0,0,-0.28)),(7,(0,0,0.28)),(13,(0,0,-0.28))],
    "LegBack.L": [(1,(0,0,-0.24)),(7,(0,0,0.24)),(13,(0,0,-0.24))],
    "LegBack.R": [(1,(0,0,0.24)),(7,(0,0,-0.24)),(13,(0,0,0.24))],
    "Body": [(1,(0,0,0)),(4,(0,0,0.045)),(7,(0,0,0)),(10,(0,0,-0.045)),(13,(0,0,0))],
    "Tail": [(1,(0.05,0,0)),(7,(-0.05,0,0)),(13,(0.05,0,0))],
})
for action, end in [(idle,32),(walk,13)]:
    action.use_fake_user = True
    action.frame_range = (1, end)

# Store each action as its own NLA track so the glTF contains both named clips.
arm.animation_data.action = None
for action in (idle, walk):
    track = arm.animation_data.nla_tracks.new()
    track.name = action.name
    strip = track.strips.new(action.name, 1, action)
    strip.action_frame_start = action.frame_range[0]
    strip.action_frame_end = action.frame_range[1]
    strip.frame_end = action.frame_range[1]

# Export meshes, armature, and both actions in a game-ready, forward-facing GLB.
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
for obj in bpy.context.scene.objects:
    if obj.type == "MESH":
        obj.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "Beaver.blend"))
EXPORT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format="GLB", export_yup=True,
                          export_apply=True, export_animations=True, export_force_sampling=True,
                          export_nla_strips=True)
print(f"Exported {EXPORT}")
