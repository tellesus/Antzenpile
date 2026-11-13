"""Blender-authored projection/occlusion masks for the painted sculpt finish.

blender -b tools/art/colony_material/colony_material.blend --python tools/art/finish_colony_material.py
Run after generate_colony_material.py. Source images are packed in the finished
editable .blend; originals remain separate. Explicitly combines original sculpt
geometry with imagegen surface finishing, not a claim of all-procedural pixels.
No pixel editing via Pillow, paid dependencies, or baked game occupants.
"""
from pathlib import Path
import bpy
import sys

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'tools/art/colony_material'
VERIFY='--' in sys.argv and 'verify' in sys.argv[sys.argv.index('--')+1:]
OUT=ROOT/('.godot/card095_source_reexport' if VERIFY else 'assets/graphics/colony/material')
OUT.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=8
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.view_settings.exposure=0;scene.view_settings.gamma=1
scene.render.resolution_percentage=100
for c in list(scene.collection.children):
    if c.name.startswith('FINISH EXPORT'):
        for obj in list(c.all_objects):bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.collections.remove(c)
    else:c.hide_render=True
export=bpy.data.collections.new('FINISH EXPORT / camera + editable painted planes')
scene.collection.children.link(export)
bpy.ops.object.camera_add(location=(0,0,10))
camera=bpy.context.object
for c in list(camera.users_collection):c.objects.unlink(camera)
export.objects.link(camera);camera.name='Finish orthographic projection';camera.data.type='ORTHO'
scene.camera=camera

def material(name,image):
    m=bpy.data.materials.new(name+' / imagegen surface finish');m.use_nodes=True
    nt=m.node_tree;nt.nodes.clear()
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=image;tex.interpolation='Linear'
    emission=nt.nodes.new('ShaderNodeEmission');nt.links.new(tex.outputs['Color'],emission.inputs['Color'])
    transparent=nt.nodes.new('ShaderNodeBsdfTransparent');mix=nt.nodes.new('ShaderNodeMixShader')
    nt.links.new(tex.outputs['Alpha'],mix.inputs[0]);nt.links.new(transparent.outputs[0],mix.inputs[1]);nt.links.new(emission.outputs[0],mix.inputs[2])
    out=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(mix.outputs[0],out.inputs['Surface'])
    return m

def plane(name,poly,mat,width,height,coll):
    data=bpy.data.meshes.new(name)
    data.from_pydata([((u-.5)*width,(.5-v)*height,0) for u,v in poly],[],[tuple(range(len(poly)))])
    uv=data.uv_layers.new(name='Full-image projection')
    for loop in data.loops:u,v=poly[loop.vertex_index];uv.data[loop.index].uv=(u,1-(.18+.64*v) if name.startswith('bridge') else 1-v)
    obj=bpy.data.objects.new(name,data);coll.objects.link(obj);data.materials.append(mat)
    return obj

# The hand-adjustable cut follows the inner front lip, preserving the cavity.
# Body and lip are rendered by the SAME flat camera/image UVs, without drift.
cuts={
 'queen':[(0,.48),(.10,.56),(.22,.65),(.36,.69),(.51,.70),(.64,.67),(.77,.60),(.88,.51),(1,.46),(1,1),(0,1)],
 'nursery_primitive':[(0,.45),(.10,.55),(.23,.64),(.38,.69),(.52,.70),(.67,.67),(.79,.59),(.9,.49),(1,.43),(1,1),(0,1)],
 'nursery_developed':[(0,.46),(.10,.55),(.23,.64),(.38,.68),(.52,.69),(.67,.66),(.79,.59),(.9,.50),(1,.45),(1,1),(0,1)],
 'entrance':[(0,.49),(.12,.59),(.25,.66),(.40,.69),(.55,.69),(.69,.65),(.8,.59),(.91,.52),(1,.48),(1,1),(0,1)]}
all_items=[]
for name in ['queen','nursery_primitive','nursery_developed','entrance','bridge','substrate']:
    source_name='queen' if name=='auxiliary' else name
    path=SOURCE/(source_name+'_finish.png')
    if not path.exists() and not bpy.data.images.get(source_name+'_finish.png'): raise FileNotFoundError(path)
    image=bpy.data.images.get(source_name+'_finish.png') if VERIFY or not path.exists() else bpy.data.images.load(str(path),check_existing=True)
    if not image: raise FileNotFoundError(path)
    image.pack()
    coll=bpy.data.collections.new(name+' / EDITABLE FINISH');export.children.link(coll)
    mat=material(name,image)
    height=2; width=height*(5 if name=='bridge' else 5/3 if name=='substrate' else 1.2)
    body=plane(name+' painted body',[(0,0),(1,0),(1,1),(0,1)],mat,width,height,coll)
    front=None
    if name not in ['bridge','substrate']:
        front=plane(name+' front lip / editable occlusion boundary',cuts.get(name,cuts['queen']),mat,width,height,coll)
    for obj in coll.objects:obj.hide_render=True
    all_items.append((name,body,front,width,height))
scene['finish_notes']='Original sculpt collections retained. Four imagegen surface finishes plus bridge/substrate finish, packed. Editable planar body/front lip masks preserve per-function runtime layering; no baked contents. Front polygon boundary can be moved in edit mode. Queen finish is reused for generic known organs.'
if not VERIFY:bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'colony_material_finished.blend'),compress=True)
for name,body,front,width,height in all_items:
    camera.data.ortho_scale=width
    scene.render.resolution_x=1280 if name in ['bridge','substrate'] else 768
    scene.render.resolution_y=256 if name=='bridge' else 768 if name=='substrate' else 640
    body.hide_render=False
    scene.render.filepath=str(OUT/(name+'.png' if name in ['bridge','substrate'] else name+'_body.png'))
    bpy.ops.render.render(write_still=True);body.hide_render=True
    if front:
        front.hide_render=False;scene.render.filepath=str(OUT/(name+'_front.png'))
        bpy.ops.render.render(write_still=True);front.hide_render=True
print('PAINTED SCULPT FINISH EXPORTED', [item[0] for item in all_items])
