"""Original excavated geometry + ambientCG Ground054, rendered offline in Blender.

Run fetch_sources.py first; then Blender -b --factory-startup --python this_file.
The editable scene and cached source maps stay in .godot/card195; the generator
and source checksums reproduce the asset without a runtime 3D dependency.
"""
from pathlib import Path
import math
import random
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
CACHE = ROOT / '.godot/card195'
rng = random.Random(195)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 40
scene.cycles.use_denoising = True
scene.render.threads_mode = 'FIXED'
scene.render.threads = 8
scene.render.film_transparent = True
scene.render.resolution_x = 1600
scene.render.resolution_y = 560
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'AgX'
scene.world.color = (0.045, 0.05, 0.06)
bpy.context.preferences.filepaths.file_preview_type = 'NONE'

def material(name, color, rough=0.9, scan=False, fade=False):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; p = nt.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    texcoord = nt.nodes.new('ShaderNodeTexCoord')
    if scan:
        image = nt.nodes.new('ShaderNodeTexImage')
        image.image = bpy.data.images.load(str(CACHE/'sources/Ground054_1K-PNG_Color.png'), check_existing=True)
        image.projection = 'BOX'; image.projection_blend = 0.25
        scale = nt.nodes.new('ShaderNodeVectorMath'); scale.operation = 'SCALE'; scale.inputs[3].default_value = 0.8
        nt.links.new(texcoord.outputs['Object'], scale.inputs[0]); nt.links.new(scale.outputs[0], image.inputs['Vector'])
        tint = nt.nodes.new('ShaderNodeMixRGB'); tint.blend_type = 'MULTIPLY'; tint.inputs[0].default_value = 1; tint.inputs[2].default_value = (*color, 1)
        nt.links.new(image.outputs['Color'], tint.inputs[1]); nt.links.new(tint.outputs[0], p.inputs['Base Color'])
        height = nt.nodes.new('ShaderNodeTexImage')
        height.image = bpy.data.images.load(str(CACHE/'sources/Ground054_1K-PNG_Displacement.png'), check_existing=True)
        height.image.colorspace_settings.name = 'Non-Color'; height.projection = 'BOX'; height.projection_blend = 0.25
        nt.links.new(scale.outputs[0], height.inputs['Vector'])
        bump = nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = 0.65; bump.inputs['Distance'].default_value = 0.07
        nt.links.new(height.outputs['Color'], bump.inputs['Height']); nt.links.new(bump.outputs[0], p.inputs['Normal'])
    if fade:
        attr = nt.nodes.new('ShaderNodeAttribute'); attr.attribute_name = 'edge_alpha'
        transparent = nt.nodes.new('ShaderNodeBsdfTransparent'); mix = nt.nodes.new('ShaderNodeMixShader')
        nt.links.new(attr.outputs['Fac'], mix.inputs[0]); nt.links.new(transparent.outputs[0], mix.inputs[1]); nt.links.new(p.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], nt.nodes.get('Material Output').inputs['Surface'])
    return m

earth = material('CC0 Ground054 / warm excavated loam', (0.30,0.25,0.19), scan=True, fade=True)
clods = [material('Angular deposited earth %d'%i, (0.20+i*.06,0.105+i*.04,0.045+i*.022), scan=True) for i in range(4)]
fiber = material('Dry fine root fibre', (0.16,0.095,0.035))
leaf = material('Buried plant fragments', (0.10,0.115,0.042))
dark = material('Unlit recessed throat', (0.001,0.001,0.001))

def height(r, a):
    ridge = 1.0*math.exp(-((r-1.02)/0.77)**2)*(1+0.23*math.sin(a*3+0.4)+0.13*math.sin(a*7))
    shoulder = 0.13*math.exp(-((r-2.0)/1.5)**2)
    noise = 0.045*(math.sin(a*19+r*8)+0.5*math.sin(a*47-r*21))*min(1,r/1.0)*math.exp(-r/4)
    grooves = 0
    for direction in (-2.55,-1.68,-0.82,0.32,2.15):
        da = math.atan2(math.sin(a-direction),math.cos(a-direction))
        grooves += 0.23*math.exp(-(da/.105)**2)*math.exp(-((r-1.4)/1.0)**2)
    throat = -0.95*max(0,1-(r-0.48)/0.28)
    return ridge+shoulder+noise-grooves+throat

verts=[]; faces=[]; alphas=[]
segments=192; rings=68
for j in range(rings):
    r=.48+(j/(rings-1))**1.55*6.4
    for i in range(segments):
        a=i/segments*math.tau
        warp=1+0.035*math.sin(a*5)+0.025*math.sin(a*11)
        verts.append((math.cos(a)*r*1.32*warp,math.sin(a)*r*warp,height(r,a)))
        alphas.append(max(0,min(1,(6.75-r)/1.6))*(.04+.96*math.exp(-max(0,r-1.25)**2/5.5)))
for j in range(rings-1):
    for i in range(segments):
        n=j*segments+i; k=j*segments+(i+1)%segments
        faces.append((n,k,k+segments,n+segments))
mesh=bpy.data.meshes.new('Excavated banks, inner throat and five worn ramps');mesh.from_pydata(verts,[],faces);mesh.update()
obj=bpy.data.objects.new('Local nest soil only',mesh);scene.collection.objects.link(obj);mesh.materials.append(earth);mesh.materials.append(dark)
attr=mesh.attributes.new('edge_alpha','FLOAT','POINT')
for i,v in enumerate(alphas):attr.data[i].value=v
for f in mesh.polygons:
    f.use_smooth=True
    if f.index//segments<9:f.material_index=1

# Dark bottom is occluded by the actual throat, not a painted ring.
bpy.ops.mesh.primitive_circle_add(vertices=64,radius=.78,fill_type='NGON',location=(0,0,-.78))
bpy.context.object.data.materials.append(dark)

# One combined mesh of asymmetric chips; no thousands of runtime objects.
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1)
base=bpy.context.object
base_v=[v.co.copy() for v in base.data.vertices];base_f=[tuple(f.vertices) for f in base.data.polygons]
bpy.data.objects.remove(base,do_unlink=True)
cv=[]; cf=[]; mat_ids=[]
for i in range(2400):
    a=rng.uniform(0,math.tau);r=.8+rng.random()**1.5*2.6
    if any(abs(math.atan2(math.sin(a-d),math.cos(a-d)))<.10 for d in (-2.55,-1.68,-.82,.32,2.15)) and r<3:continue
    s=rng.uniform(.018,.095)*(1.1 if r<2 else .7)
    x=math.cos(a)*r*1.32;y=math.sin(a)*r;z=height(r,a)
    angle=rng.random()*math.tau;start=len(cv)
    for v in base_v:
        dx=v.x*s*rng.uniform(.75,1.35);dy=v.y*s*rng.uniform(.65,1.25)
        cv.append((x+dx*math.cos(angle)-dy*math.sin(angle),y+dx*math.sin(angle)+dy*math.cos(angle),z+v.z*s*.7+s*.3))
    cf.extend(tuple(start+n for n in f) for f in base_f);mat_ids.extend([rng.randrange(4)]*len(base_f))
mesh=bpy.data.meshes.new('Deposited irregular grains');mesh.from_pydata(cv,[],cf);mesh.update()
obj=bpy.data.objects.new('Grain scatter / worn ramps kept open',mesh);scene.collection.objects.link(obj)
for m in clods:mesh.materials.append(m)
for f,mi in zip(mesh.polygons,mat_ids):f.material_index=mi

for i in range(13):
    a=rng.uniform(0,math.tau);r=rng.uniform(1.8,3.2);x=math.cos(a)*r*1.32;y=math.sin(a)*r
    curve=bpy.data.curves.new('Broken root fibre','CURVE');curve.dimensions='3D';curve.bevel_depth=rng.uniform(.009,.021);curve.bevel_resolution=2
    spline=curve.splines.new('POLY');spline.points.add(11)
    for j,p in enumerate(spline.points):
        xx=x+(j/11-.5)*rng.uniform(.8,1.3);yy=y+math.sin(j*.4+i)*.13
        rr=math.hypot(xx/1.32,yy);aa=math.atan2(yy,xx/1.32)
        p.co=(xx,yy,height(rr,aa)+.035,1)
    obj=bpy.data.objects.new('Dry root fragment',curve);scene.collection.objects.link(obj);curve.materials.append(fiber)
for i in range(7):
    a=rng.uniform(0,math.tau);r=rng.uniform(2,3.2);x=math.cos(a)*r*1.32;y=math.sin(a)*r;z=height(r,a)+.025
    v=[(x-.32,y,z),(x-.08,y-.09,z+.03),(x+.3,y+.06,z+.08),(x+.05,y+.13,z+.04)]
    mesh=bpy.data.meshes.new('Torn buried leaf');mesh.from_pydata(v,[],[(0,1,2,3)]);mesh.materials.append(leaf)
    obj=bpy.data.objects.new('Plant fragment',mesh);scene.collection.objects.link(obj)

for obj in scene.objects:
    obj.scale.y *= 0.65
    obj.location.y *= 0.65
bpy.ops.object.camera_add(location=(0,-13,10))
camera=bpy.context.object;camera.rotation_euler=(Vector((0,0,.2))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=19;scene.camera=camera
for at,power,color,size in [((-3,-4,7),950,(.94,.86,.72),5),((5,2,4),420,(.22,.55,.68),4),((0,5,6),450,(.9,.72,.5),4)]:
    bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object;light.data.energy=power;light.data.color=color;light.data.shape='DISK';light.data.size=size
    light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
scene['provenance']='Original Antzenpile geometry, seed195. CC0 ambientCG Ground054 color and displacement. No remote terrain, occupants or hidden state.'
bpy.ops.wm.save_as_mainfile(filepath=str(CACHE/'entrance.blend'),compress=True)
scene.render.filepath=str(ROOT/'assets/graphics/colony/material/excavated_home.png')
bpy.ops.render.render(write_still=True)
