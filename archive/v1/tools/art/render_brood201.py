"""Original luminous brood meshes; Blender5.2 offline, no external models.

blender -b --factory-startup --python tools/art/render_brood201.py
Only the three brood sprites are replaced; queen and colony materials stay put.
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

OUT=Path(__file__).resolve().parents[2]/'assets/graphics/colony'
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.samples=48; scene.cycles.use_denoising=True
scene.render.resolution_x=scene.render.resolution_y=512; scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='AgX'
scene.world.color=(.025,.035,.03)

def material(name,color,emission=0,translucent=False):
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=.29
    p.inputs['Subsurface Weight'].default_value=.28 if translucent else .08
    p.inputs['Transmission Weight'].default_value=.23 if translucent else 0
    p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emission
    return m

skin=material('Translucent jade ivory',(.43,.70,.48),.11,True)
rim=material('Mint sensory ridges',(.36,.93,.69),.7)
core=material('Warm living centre',(.92,.52,.13),.3)
seam=material('Soft jade folds',(.12,.31,.23),.15)
objects=[]

def oval(at,scale,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40,ring_count=24,location=at)
    obj=bpy.context.object; obj.scale=scale; obj.data.materials.append(mat)
    for polygon in obj.data.polygons: polygon.use_smooth=True
    objects.append(obj); return obj

def strand(points,radius,mat):
    curve=bpy.data.curves.new('Organic fold','CURVE'); curve.dimensions='3D'
    curve.bevel_depth=radius; curve.bevel_resolution=3
    spline=curve.splines.new('BEZIER'); spline.bezier_points.add(len(points)-1)
    for point,at in zip(spline.bezier_points,points):
        point.co=at; point.handle_left_type=point.handle_right_type='AUTO'
    obj=bpy.data.objects.new('Brood fold',curve); scene.collection.objects.link(obj)
    curve.materials.append(mat); objects.append(obj)

bpy.ops.object.camera_add(location=(0,-.4,8))
camera=bpy.context.object; camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'; camera.data.ortho_scale=2.5; scene.camera=camera
for at,power,color,scale in [((-3,-1,4),260,(.64,1,.80),3),((2,2,3),420,(.20,.85,1),2),((0,-3,2),110,(1,.64,.23),2)]:
    bpy.ops.object.light_add(type='AREA',location=at)
    light=bpy.context.object; light.data.energy=power; light.data.color=color; light.data.shape='DISK'; light.data.size=scale
    light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()

def save(stage):
    scene.render.filepath=str(OUT/f'brood_{stage}.png'); bpy.ops.render.render(write_still=True)
    for obj in objects: bpy.data.objects.remove(obj,do_unlink=True)
    objects.clear()

# An egg reads as a translucent living capsule instead of a flat white bead.
oval((0,0,0),(.49,.91,.38),skin)
oval((.035,-.1,.34),(.19,.43,.07),core)
strand([(-.30,-.62,.23),(-.43,-.1,.25),(-.30,.60,.22)],.018,rim)
strand([(.29,-.61,.24),(.43,.1,.24),(.26,.65,.22)],.011,rim)
save('egg')

# Soft continuous C-shaped larva with articulated folds and warm inner mass.
for i in range(10):
    angle=-1.5+i*.30; at=(math.cos(angle)*.67-.22,math.sin(angle)*.72,0)
    r=.18+math.sin(i/9*math.pi)*.13
    oval(at,(r,r*.94,r*.82),skin)
    if i in [2,4,6,8]:
        strand([(at[0]-.17,at[1]-.03,.14),(at[0],at[1]-.08,.24),(at[0]+.17,at[1]-.02,.15)],.014,rim)
oval((-.14,.72,.05),(.16,.18,.15),skin)
strand([(.01,-.53,.23),(.31,-.13,.27),(.27,.34,.25)],.038,core)
save('larva')

# Ant-shaped pupa: head, folded thorax/legs and segmented abdomen.
oval((0,.65,.02),(.29,.30,.24),skin)
oval((0,.19,0),(.25,.30,.23),skin)
oval((0,-.45,-.01),(.39,.59,.30),skin)
for i in range(4):
    y=-.80+i*.23
    strand([(-.28,y,.18),(0,y-.055,.29),(.28,y,.18)],.015,rim)
for side in [-1,1]:
    for i in range(3):
        strand([(side*.17,.40-i*.16,.17),(side*(.38+i*.04),.08-i*.14,.15),(side*.19,-.47-i*.08,.25)],.024,seam)
    strand([(side*.19,.80,.16),(side*.39,.59,.13),(side*.28,.27,.19)],.018,rim)
oval((0,.15,.24),(.09,.19,.035),core)
save('pupa')
print('BROOD201_ORIGINAL_SPRITES_OK')
