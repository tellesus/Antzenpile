"""Packed editable Home/smoke planes exported in Blender, with no live contents.

blender -b tools/art/colony_material/outward_material.blend --python tools/art/finish_outward_material.py
Subsequent exports can load outward_material_finished.blend and use -- verify
to require packed inputs and write a comparison under ignored .godot/.
"""
from pathlib import Path
import sys
import bpy

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'tools/art/colony_material'
VERIFY='--' in sys.argv and 'verify' in sys.argv[sys.argv.index('--')+1:]
OUT=ROOT/('.godot/card096_source_reexport' if VERIFY else 'assets/graphics/colony/material')
OUT.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene
for coll in list(scene.collection.children):
 if coll.name.startswith('OUTWARD FINISH'):
  for obj in list(coll.all_objects):bpy.data.objects.remove(obj,do_unlink=True)
  bpy.data.collections.remove(coll)
 else:coll.hide_render=True
export=bpy.data.collections.new('OUTWARD FINISH / editable packed surface planes')
scene.collection.children.link(export)
scene.render.engine='CYCLES';scene.cycles.samples=8
scene.render.film_transparent=True;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.view_settings.exposure=0;scene.view_settings.gamma=1
bpy.ops.object.camera_add(location=(0,0,10));camera=bpy.context.object
for coll in list(camera.users_collection):coll.objects.unlink(camera)
export.objects.link(camera);camera.data.type='ORTHO';scene.camera=camera
items=[]
for name,source_name,w,h in [('local_home','home',1280,512),('scent_smoke','smoke',768,768)]:
 path=SOURCE/(source_name+'_finish.png')
 image=bpy.data.images.get(path.name) if VERIFY or not path.exists() else bpy.data.images.load(str(path),check_existing=True)
 if not image:raise FileNotFoundError(path)
 image.pack()
 mat=bpy.data.materials.new(name+' packed paint finish');mat.use_nodes=True
 nt=mat.node_tree;nt.nodes.clear()
 tex=nt.nodes.new('ShaderNodeTexImage');tex.image=image
 emit=nt.nodes.new('ShaderNodeEmission');nt.links.new(tex.outputs['Color'],emit.inputs['Color'])
 clear=nt.nodes.new('ShaderNodeBsdfTransparent');mix=nt.nodes.new('ShaderNodeMixShader')
 nt.links.new(tex.outputs['Alpha'],mix.inputs[0]);nt.links.new(clear.outputs[0],mix.inputs[1]);nt.links.new(emit.outputs[0],mix.inputs[2])
 out=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(mix.outputs[0],out.inputs['Surface'])
 width=w/h*2
 data=bpy.data.meshes.new(name+' editable projection')
 data.from_pydata([(-width/2,-1,0),(width/2,-1,0),(width/2,1,0),(-width/2,1,0)],[],[(0,1,2,3)])
 uv=data.uv_layers.new(name='Paint projection')
 for i,point in enumerate([(0,0),(1,0),(1,1),(0,1)]):uv.data[i].uv=point
 obj=bpy.data.objects.new(name,data);export.objects.link(obj);data.materials.append(mat)
 obj.hide_render=True;items.append((name,obj,w,h,width))
scene['finish_notes']='Original local Home sculpt retained. Packed imagegen macro surface finish and neutral smoke density texture; editable projection planes, true alpha, no baked ants/brood/resources/UI or remote scenery. Smoke has no object identity and is tinted only from delivered sensory summaries.'
if not VERIFY:bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'outward_material_finished.blend'),compress=True)
for name,obj,w,h,width in items:
 camera.data.ortho_scale=width;scene.render.resolution_x=w;scene.render.resolution_y=h
 obj.hide_render=False;scene.render.filepath=str(OUT/(name+'.png'))
 bpy.ops.render.render(write_still=True);obj.hide_render=True
print('OUTWARD MATERIAL EXPORTED', [i[0] for i in items])
