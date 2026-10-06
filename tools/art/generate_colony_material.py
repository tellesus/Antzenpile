"""Original editable colony sculpt / baked 2D material kit. Blender 5.2.2 LTS.

blender -b --factory-startup --python tools/art/generate_colony_material.py
Arguments after --: optional asset names (queen nursery_primitive ... bridge substrate).
The .blend retains every organ, collection, procedural material, light and camera.
No imported models, occupants, game state, AI raster art or runtime 3D.
"""
from pathlib import Path
import math
import random
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/graphics/colony/material'
SOURCE = ROOT / 'tools/art/colony_material/colony_material.blend'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.threads_mode = 'FIXED'
scene.render.threads = 12
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.image_settings.color_depth = '8'
scene.view_settings.view_transform = 'AgX'
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.085,.095,.12,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .16

def material(name, color, roughness=.5, glow=0, grain=True):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; p = nt.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color,1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Specular IOR Level'].default_value = .65
    p.inputs['Coat Weight'].default_value = .28 if roughness < .4 else .04
    if glow:
        p.inputs['Emission Color'].default_value = (*color,1)
        p.inputs['Emission Strength'].default_value = glow
    if grain:
        tex = nt.nodes.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value = 105
        tex.inputs['Detail'].default_value = 4
        ramp = nt.nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].position = .17
        ramp.color_ramp.elements[0].color = (*[x*.16 for x in color],1)
        ramp.color_ramp.elements[1].position = .83
        ramp.color_ramp.elements[1].color = (*[x*1.4 for x in color],1)
        nt.links.new(tex.outputs['Fac'],ramp.inputs[0]);nt.links.new(ramp.outputs[0],p.inputs['Base Color'])
        bump = nt.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value = .38
        bump.inputs['Distance'].default_value = .20
        nt.links.new(tex.outputs['Fac'],bump.inputs['Height']);nt.links.new(bump.outputs[0],p.inputs['Normal'])
    return m

EARTH = material('Charcoal earthen grain',(.037,.024,.017),.88)
FLOOR = material('Quiet cavity soil',(.065,.039,.018),.92)
ROOTMAT = material('Dark resin roots',(.054,.035,.019),.33)
RESIN = material('Honey amber membrane',(.34,.16,.038),.29)
CYANRESIN = material('Entrance wet mineral',(.075,.16,.17),.27)
THREAD = material('Unlit silk fibres',(.32,.20,.082),.44,0,False)
AMBER = material('Sparse amber filaments',(.96,.39,.038),.26,2.2,False)
IVORY = material('Sheltered nursery lining',(.49,.35,.17),.38,.09)
CYAN = material('Reflected cyan fibres',(.11,.63,.72),.28,1.5,False)
SHADOW = material('Rear growth disappears into darkness',(.009,.008,.006),.91)
VIOLET = material('Subtle repertoire membrane',(.19,.09,.21),.35,.3)

rig = bpy.data.collections.new('LIGHTS + CAMERA');scene.collection.children.link(rig)
def link(obj, coll):
    for old in list(obj.users_collection):old.objects.unlink(obj)
    coll.objects.link(obj)
    return obj

def mesh(name, vertices, faces, mat, coll):
    data = bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    obj = bpy.data.objects.new(name,data);coll.objects.link(obj);obj.data.materials.append(mat)
    for f in data.polygons:f.use_smooth = True
    return obj

def lines(name, paths, radius, mat, coll):
    data = bpy.data.curves.new(name,'CURVE');data.dimensions='3D'
    data.resolution_u = 1;data.bevel_resolution = 2;data.bevel_depth = radius
    for points in paths:
        spline=data.splines.new('POLY');spline.points.add(len(points)-1)
        for p,xyz in zip(spline.points,points):p.co=(*xyz,1)
    obj=bpy.data.objects.new(name,data);coll.objects.link(obj);data.materials.append(mat)
    return obj

def pebble(at, scale, mat, coll, name='Resin / soil aggregate'):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=at)
    obj=bpy.context.object;obj.name=name;obj.scale=scale
    obj.rotation_euler=(random.random(),random.random(),random.random()*6)
    obj.data.materials.append(mat)
    for f in obj.data.polygons:f.use_smooth=True
    return link(obj,coll)

bpy.ops.object.camera_add(location=(0,-10,20))
camera=link(bpy.context.object,rig);camera.name='Aligned organ export camera'
camera.rotation_euler=(Vector((0,0,.55))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=8.65;scene.camera=camera
for name,at,power,color,size in [('Soft warm key',(-4,1,7),580,(1,.68,.36),5),('Cool reflected fill',(3,-1,5),155,(.33,.62,1),4),('Amber rim',(-1,4,3),245,(1,.39,.09),3)]:
    bpy.ops.object.light_add(type='AREA',location=at)
    obj=link(bpy.context.object,rig);obj.name=name;obj.data.energy=power;obj.data.color=color;obj.data.size=size
    obj.rotation_euler=(Vector((0,0,0))-obj.location).to_track_quat('-Z','Y').to_euler()

sets={}
def collections(name):
    root=bpy.data.collections.new(name);scene.collection.children.link(root)
    body=bpy.data.collections.new(name+' / BODY + FLOOR');root.children.link(body)
    front=bpy.data.collections.new(name+' / FRONT LIP');root.children.link(front)
    rear=bpy.data.collections.new(name+' / REAR SHADOW');root.children.link(rear)
    sets[name]=(root,body,front,rear)
    return body,front,rear

def organ(name, seed, developed=1, entrance=False, queen=False):
    random.seed(seed);body,front,rear=collections(name)
    phase=random.random()*6
    def surface(q,a):
        irregular=1+.055*math.sin(3*a+phase)+.028*math.sin(7*a-phase)+.016*math.cos(13*a)
        r=3.32*q*irregular
        ridge=max(0,math.sin(a))
        z=.04+.065*math.sin(a*11+q*8)*q+.03*math.sin(a*39+q*46)*q
        if q>.43:z+=math.sin(min(1,(q-.43)/.57)*math.pi)**.8*(.95+.42*developed)
        if queen:z+=ridge**3*q*.64
        if entrance:z*=.62
        return (r*1.04, r*.77, z)
    # Radial cavity, raised rear ridge and asymmetric outer ground skirt.
    verts=[];faces=[];count=144;bands=36
    for ring in range(bands+1):
        q=.012+ring/bands*1.04
        for i in range(count):
            a=i/count*math.tau;r,y,z=surface(q,a);verts.append((r*math.cos(a),y*math.sin(a),z))
    for ring in range(bands):
        for i in range(count):faces.append((ring*count+i,ring*count+(i+1)%count,(ring+1)*count+(i+1)%count,(ring+1)*count+i))
    # Earth is the mass; selected patches carry resin rather than a bright halo.
    sculpt=mesh(name+' sculpted earthen bowl',verts,faces,EARTH,body)
    sculpt.data.materials.append(FLOOR);sculpt.data.materials.append(CYANRESIN if entrance else RESIN)
    for f in sculpt.data.polygons:
        ring=f.index//count;a=(f.index%count)/count*math.tau
        f.material_index=1 if ring<16 else 2 if ring<27 and (math.sin(a*3+phase)>.25 or entrance) else 0
    lip_faces=[f for f in faces if sum(verts[i][1] for i in f)/4<-.85 and sum(verts[i][2] for i in f)/4>.35]
    # Duplicate exact front geometry in a separately exportable collection.
    lip=mesh(name+' front occlusion lip',verts,lip_faces,EARTH,front)
    lip.data.materials.append(CYANRESIN if entrance else RESIN)
    for f in lip.data.polygons:f.material_index=1 if sum(verts[i][2] for i in f.vertices)/4>.7 else 0
    # Grain scales and resin nodules keep a mineral/membrane material, not pearls.
    for i in range(145):
        a=random.random()*math.tau;q=random.uniform(.68,1.04);r,y,z=surface(q,a)
        at=(r*math.cos(a),y*math.sin(a),z+.015)
        rr=random.uniform(.035,.14)
        mat=RESIN if i%9==0 else EARTH
        coll=front if at[1]<-.85 and at[2]>.35 else body
        pebble(at,(rr*1.3,rr,rr*.68),mat,coll)
    paths={};front_paths={}
    # Uneven interwoven fibres, mostly unlit. Open arcs, no uniform neon ring.
    for i in range(170 if developed else 95):
        a=random.random()*math.tau;span=random.uniform(.14,.8);q=random.uniform(.50,.94)
        points=[]
        for j in range(21):
            t=j/20;angle=a+span*t;rad=q+.026*math.sin(t*math.pi*2+i)
            r,y,z=surface(rad,angle);points.append((r*math.cos(angle),y*math.sin(angle),z+.035))
        glow=i%11==0 and math.sin(a*3+phase)>.0
        mat=(CYAN if entrance else AMBER) if glow else IVORY if name.startswith('nursery') and developed and i%4==0 else THREAD
        target=front_paths if sum(p[1] for p in points)/len(points)<-.85 and sum(p[2] for p in points)/len(points)>.35 else paths
        target.setdefault(mat,[]).append(points)
    # Cross-fibres tie neighbouring strata together, avoiding empty-ring art.
    for i in range(58):
        a=random.random()*math.tau;q=random.uniform(.6,.88);b=a+random.uniform(-.34,.34)
        points=[]
        for j in range(16):
            t=j/15;r,y,z=surface(q*(1-t)+.48*t,a*(1-t)+b*t)
            points.append((r*math.cos(a*(1-t)+b*t),y*math.sin(a*(1-t)+b*t),z+.04))
        target=front_paths if sum(p[1] for p in points)/16<-.85 and sum(p[2] for p in points)/16>.35 else paths
        target.setdefault(THREAD,[]).append(points)
    for target,coll in [(paths,body),(front_paths,front)]:
        for mat,items in target.items():lines(name+' '+mat.name,items,.008 if mat==THREAD else .012,mat,coll)
    # A lined Nursery gains protective folded tissue along its rear, not eggs.
    if name.startswith('nursery') and developed:
        for i in range(18):
            a=.15+i/17*2.8;q=.59;r,y,z=surface(q,a)
            pebble((r*math.cos(a),y*math.sin(a),z+.06),(.12,.17,.15),IVORY,body,'Protective lining fold')
    # Loose surrounding roots and dark gravel make the silhouette porous.
    roots=[]
    for i in range(30):
        a=i/30*math.tau;q=random.uniform(1.0,1.15)
        points=[]
        for j in range(20):
            t=j/19;rr=2.8+t*1.2;angle=a+math.sin(t*5+i)*.055
            points.append((rr*math.cos(angle),rr*.77*math.sin(angle),.1+math.sin(t*math.pi)*.2))
        roots.append(points)
    lines(name+' outer shadow roots',roots,.022,ROOTMAT,rear)
    for i in range(45):
        a=random.random()*math.tau;r=random.uniform(3.1,3.95)
        rr=random.uniform(.1,.31)
        pebble((r*math.cos(a),r*.72*math.sin(a),-.06),(rr*1.4,rr,.10),SHADOW,rear)

organ('queen',72,queen=True)
organ('nursery_primitive',91,0)
organ('nursery_developed',91,1)
organ('entrance',101,1,entrance=True)
organ('auxiliary',125,1)

def bridge():
    random.seed(43);body,front,rear=collections('bridge')
    vertices=[];faces=[]
    for ix in range(81):
        x=-6+ix/80*12;envelope=.75+.21*math.sin(x*1.4)+.15*math.cos(x*2.7)
        for iy in range(17):
            y=(iy/16*2-1)*envelope
            vertices.append((x,y,.12+.32*math.sin(iy/16*math.pi)+.07*math.sin(x*4+iy)))
    for ix in range(80):
        for iy in range(16):a=ix*17+iy;faces.append((a,a+17,a+18,a+1))
    mesh('Variable-width connecting mass',vertices,faces,EARTH,body)
    for mat,count,radius in [(ROOTMAT,22,.052),(THREAD,36,.012),(AMBER,5,.009)]:
        paths=[]
        for i in range(count):
            offset=random.uniform(-.65,.65);phase=random.random()*6
            paths.append([(-6+j/80*12,offset*(.8+.15*math.sin(j/80*13))+.15*math.sin(j/80*17+phase),.49+.12*math.sin(j/80*12+phase)) for j in range(81)])
        lines('Structural '+mat.name,paths,radius,mat,body)
    for i in range(78):
        x=random.uniform(-6,6);y=random.uniform(-.75,.75);r=random.uniform(.045,.13)
        pebble((x,y,.25),(r*1.7,r,r),RESIN if i%7==0 else EARTH,body)
bridge()

def substrate():
    random.seed(312);body,front,rear=collections('substrate')
    # A shallow sculpt, with no cavities or hidden functional locations.
    verts=[];faces=[];nx=100;ny=65
    for i in range(nx+1):
        x=-8+i/nx*16
        for j in range(ny+1):
            y=-4.5+j/ny*9
            z=.12+(.16*math.sin(x*1.8+y)+.1*math.cos(y*2.8-x))*math.sin(i/nx*math.pi)*math.sin(j/ny*math.pi)
            verts.append((x,y,z))
    for i in range(nx):
        for j in range(ny):a=i*(ny+1)+j;faces.append((a,a+ny+1,a+ny+2,a+1))
    mesh('Continuous shadow substrate',verts,faces,SHADOW,body)
    roots=[]
    for i in range(100):
        x=random.uniform(-7.5,7.5);y=random.uniform(-3.8,3.8);angle=random.uniform(0,6)
        roots.append([(x+math.cos(angle)*t*2,y+math.sin(angle)*t*2+.1*math.sin(t*14+i),.28+.06*math.sin(t*8+i)) for t in [j/30 for j in range(31)]])
    lines('Substrate branching roots',roots,.035,ROOTMAT,body)
    for i in range(330):
        x=random.uniform(-7.7,7.7);y=random.uniform(-4.2,4.2);r=random.uniform(.05,.28)
        pebble((x,y,.18),(r*1.8,r,.15),SHADOW if i%5 else EARTH,body)
substrate()
# World-position feather is authored in each backdrop material, not runtime fog.
for obj in sets['substrate'][0].all_objects:
    for slot in obj.material_slots:
        old=slot.material
        m=bpy.data.materials.get(old.name+' / FIELD FEATHER')
        if not m:
            m=old.copy();m.name=old.name+' / FIELD FEATHER'
            nt=m.node_tree;out=nt.nodes.get('Material Output');surface=out.inputs['Surface'].links[0].from_socket
            geom=nt.nodes.new('ShaderNodeNewGeometry')
            scale=nt.nodes.new('ShaderNodeVectorMath');scale.operation='MULTIPLY';scale.inputs[1].default_value=(1/8,1/4.5,0)
            nt.links.new(geom.outputs['Position'],scale.inputs[0])
            length=nt.nodes.new('ShaderNodeVectorMath');length.operation='LENGTH';nt.links.new(scale.outputs[0],length.inputs[0])
            ramp=nt.nodes.new('ShaderNodeMapRange');ramp.inputs['From Min'].default_value=.35;ramp.inputs['From Max'].default_value=1.05
            ramp.inputs['To Min'].default_value=.55;ramp.inputs['To Max'].default_value=0
            nt.links.new(length.outputs['Value'],ramp.inputs['Value'])
            clear=nt.nodes.new('ShaderNodeBsdfTransparent');mix=nt.nodes.new('ShaderNodeMixShader')
            nt.links.new(ramp.outputs[0],mix.inputs[0]);nt.links.new(clear.outputs[0],mix.inputs[1]);nt.links.new(surface,mix.inputs[2]);nt.links.new(mix.outputs[0],out.inputs['Surface'])
        slot.material=m

# All assets exist in one source, each independently switchable collection.
scene['production_notes']='Original parametric sculpt. BODY contains soil/lining, FRONT LIP occludes live contents, REAR contains root shadows. No baked ants/brood/resources. Render layer exports share camera, origin and dimensions.'
scene['asset_names']=' '.join(sets)
for root,*_ in sets.values():root.hide_render=True
scene.render.resolution_x=768;scene.render.resolution_y=640
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE),compress=True)
requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [name for name in sets if name!='auxiliary']
for name in requested:
    root,body,front,rear=sets[name];root.hide_render=False
    if name in ['bridge','substrate']:
        camera.location=(0,0,20);camera.rotation_euler=(0,0,0)
        camera.data.ortho_scale=13 if name=='bridge' else 17
        scene.render.resolution_x=1280;scene.render.resolution_y=256 if name=='bridge' else 768
        scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
    else:
        camera.location=(0,-10,20);camera.rotation_euler=(Vector((0,0,.55))-camera.location).to_track_quat('-Z','Y').to_euler()
        camera.data.ortho_scale=8.65
        scene.render.resolution_x=768;scene.render.resolution_y=640
        # Body already includes the lip, so empty cavities never have a gap.
        rear.hide_render=True;scene.render.filepath=str(OUT/(name+'_body.png'));bpy.ops.render.render(write_still=True)
        body.hide_render=True;scene.render.filepath=str(OUT/(name+'_front.png'));bpy.ops.render.render(write_still=True)
        front.hide_render=True;rear.hide_render=False;scene.render.filepath=str(OUT/(name+'_rear.png'));bpy.ops.render.render(write_still=True)
        body.hide_render=front.hide_render=rear.hide_render=False
    root.hide_render=True
print('COLONY MATERIAL KIT EXPORTED:',requested)
