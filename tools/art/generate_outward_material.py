"""Editable local Home substrate sculpt; no remote scenery or baked occupants.

Blender 5.2.2 LTS, offline only. Shares the card-095 grain/resin material language; this standalone scene
builds a rugged local lip without importing organs or gameplay objects.
blender -b --factory-startup --python tools/art/generate_outward_material.py
"""
from pathlib import Path
import math
import random
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'tools/art/colony_material'
OUT=ROOT/'.godot/outward_material_base.png'
random.seed(196)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.cycles.use_denoising=True;scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.render.resolution_x=1280;scene.render.resolution_y=512
scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
scene.world.color=(.025,.035,.045)

def material(name,color,roughness):
 m=bpy.data.materials.new(name);m.use_nodes=True;nt=m.node_tree
 p=nt.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
 p.inputs['Roughness'].default_value=roughness
 noise=nt.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=95;noise.inputs['Detail'].default_value=4
 bump=nt.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.55;bump.inputs['Distance'].default_value=.13
 nt.links.new(noise.outputs['Fac'],bump.inputs['Height']);nt.links.new(bump.outputs[0],p.inputs['Normal'])
 return m
earth=material('Local charcoal soil',(.023,.016,.011),.83)
resin=material('Shared amber resin',(.15,.057,.009),.30)
dark=material('Shadow mineral field',(.008,.009,.009),.91)
coll=bpy.data.collections.new('Immediate Home field / original sculpt');scene.collection.children.link(coll)
def mesh(name,verts,faces,mat):
 d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update()
 o=bpy.data.objects.new(name,d);coll.objects.link(o);d.materials.append(mat)
 for f in d.polygons:f.use_smooth=True
 return o

# Wide near-ground lip. Central negative space is local Home, not a surveyed map.
verts=[];faces=[]
for i in range(145):
 x=-8+i/144*16
 for j in range(19):
  y=-2+j/18*4
  ridge=.19+.43*math.exp(-x*x/12)*math.exp(-y*y/2)
  z=ridge*(1+.20*math.sin(x*3.1+y*4))+.07*math.sin(x*14+y*12)
  verts.append((x,y,z))
for i in range(144):
 for j in range(18):a=i*19+j;faces.append((a,a+19,a+20,a+1))
mesh('Irregular immediate ground',verts,faces,dark)
# Low rough protective mouth arch with a quiet recessed opening.
verts=[];faces=[]
for i in range(97):
 a=i/96*math.pi
 for j in range(9):
  r=1.02+j/8*.65
  verts.append((math.cos(a)*r, .15+j/8*.65, .25+math.sin(a)*r*(.85+.045*math.sin(a*13))))
for i in range(96):
 for j in range(8):n=i*9+j;faces.append((n,n+9,n+10,n+1))
arch=mesh('Rugged local mouth lip',verts,faces,earth);arch.data.materials.append(resin)
for f in arch.data.polygons:f.material_index=1 if f.index%13==0 else 0
for i in range(280):
 x=random.uniform(-7.9,7.9);y=random.uniform(-1.8,1.8)
 if abs(x)<1.1 and y>0:continue
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,y,.22))
 obj=bpy.context.object;obj.name='Local grain / editable';r=random.uniform(.025,.18)
 obj.scale=(r*1.6,r,r*.5);obj.data.materials.append(earth if i%8 else resin)
 for c in list(obj.users_collection):c.objects.unlink(obj)
 coll.objects.link(obj)
bpy.ops.object.camera_add(location=(0,-9,8));camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,.5))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=17;scene.camera=camera
for at,power,color in [((0,-1,2),340,(1,.47,.11)),((-6,2,5),90,(.1,.32,.46)),((6,-2,4),70,(.15,.35,.5))]:
 bpy.ops.object.light_add(type='AREA',location=at);lamp=bpy.context.object
 lamp.data.energy=power;lamp.data.size=3;lamp.data.color=color
 lamp.rotation_euler=(-lamp.location).to_track_quat('-Z','Y').to_euler()
scene['notes']='Original editable near-ground field and rugged Home mouth. No occupants or distant scenery. Imagegen finish is a separately packed painted environmental layer.'
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'outward_material.blend'),compress=True)
scene.render.filepath=str(OUT);bpy.ops.render.render(write_still=True)
