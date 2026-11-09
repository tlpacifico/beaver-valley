"""Prepare an editable Meshy tree; run with Blender --background --python."""
from pathlib import Path
import bpy
from mathutils import Vector
root = Path(__file__).resolve().parents[3]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root/'art/environment/meshy-tree/originals/golden_tree.glb'))
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
obj=objects[0]
obj.name='GoldenTree'
bpy.context.view_layer.objects.active=obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
coords=[obj.matrix_world@v.co for v in obj.data.vertices]
lo=Vector(tuple(min(v[i] for v in coords) for i in range(3)))
hi=Vector(tuple(max(v[i] for v in coords) for i in range(3)))
scale=2.4/(hi.z-lo.z)
center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
for v in obj.data.vertices:
    v.co=(v.co-center)*scale
obj.location=(0,0,0)
# Weld export seams and recalculate shading instead of retaining baked split normals.
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=0.00001)
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.mesh.customdata_custom_splitnormals_clear()
for name,color in [('GoldenCanopy',(0.80,0.46,0.055,1)),('PaleTrunk',(0.66,0.48,0.28,1))]:
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=color
    mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=color
    shader.inputs['Roughness'].default_value=0.85
    obj.data.materials.append(mat)
# Initial material boundary; retain as an editable assignment for visual review.
for poly in obj.data.polygons:
    height=sum(obj.data.vertices[i].co.z for i in poly.vertices)/len(poly.vertices)
    poly.material_index=1 if height<0.72 else 0
    poly.use_smooth=True
bpy.ops.wm.save_as_mainfile(filepath=str(root/'art/environment/meshy-tree/golden_tree.blend'))
bpy.ops.export_scene.gltf(filepath=str(root/'game/assets/environment/meshy_tree/golden_tree.glb'),export_format='GLB',use_selection=True)
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=32
scene.world.color=(0.35,0.35,0.35)
bpy.ops.object.camera_add(location=(4,-6,3.5))
camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,1.2))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=3.6
scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=(1,-4,6))
bpy.context.object.data.energy=450
bpy.context.object.data.shape='DISK'
bpy.context.object.data.size=5
scene.render.resolution_x=800
scene.render.resolution_y=800
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(root/'builds/scenery-sample/meshy-tree-preview.png')
bpy.ops.render.render(write_still=True)
print('TREE_PREPARED triangles=%d height=2.4' % sum(len(p.vertices)-2 for p in obj.data.polygons))
