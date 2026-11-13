"""Run with Blender 5.2: blender -b --factory-startup --python this_file.

Original pearlescent procedural worker; no third-party models. Twenty-four poses share an anatomy
and camera. Assets contain baked light, not gameplay or live 3D dependencies.
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/graphics/sensorium"
SCRATCH = ROOT / ".godot/art_worker_v3"
OUT.mkdir(parents=True, exist_ok=True)
SCRATCH.mkdir(parents=True, exist_ok=True)
CELL, FRAMES, COLS = 192, 24, 8
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = CELL
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.world.color = (0.12, 0.12, 0.12)
scene.view_settings.view_transform = "Standard"

def material(name, color, roughness):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    return mat

body = material("Pearlescent cuticle", (0.24, 0.28, 0.32), 0.26)
body_shader = body.node_tree.nodes.get("Principled BSDF")
body_shader.inputs["Metallic"].default_value = 0.28
body_shader.inputs["Coat Weight"].default_value = 0.34
noise = body.node_tree.nodes.new("ShaderNodeTexNoise")
noise.inputs["Scale"].default_value = 68
bump = body.node_tree.nodes.new("ShaderNodeBump")
bump.inputs["Strength"].default_value = 0.12
bump.inputs["Distance"].default_value = 0.025
body.node_tree.links.new(noise.outputs["Fac"], bump.inputs["Height"])
body.node_tree.links.new(bump.outputs["Normal"], body_shader.inputs["Normal"])
rim = material("Chemical cuticle seams", (0.58, 0.65, 0.70), 0.22)
rim.node_tree.nodes.get("Principled BSDF").inputs["Emission Color"].default_value=(0.16,0.18,0.20,1)
rim.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"].default_value=0.22
joint = material("Legs and antennae", (0.40, 0.46, 0.50), 0.32)
eye = material("Eyes", (0.006, 0.004, 0.002), 0.2)

def ellipsoid(name, at, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj

def rod(name, a, b, radius, mat):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, location=(a+b)/2)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (radius, radius, (b-a).length/2 + radius)
    obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj

# Head, three-part mesosoma, one petiole node, gaster. All legs join mesosoma.
ellipsoid("Gaster", (0,-1.85,0.68), (0.78,1.06,0.55), body)
ellipsoid("Petiole", (0,-0.48,0.67), (0.22,0.25,0.28), body)
ellipsoid("Mesosoma rear", (0,0.0,0.72), (0.36,0.43,0.32), body)
ellipsoid("Mesosoma middle", (0,0.5,0.75), (0.34,0.4,0.32), body)
ellipsoid("Mesosoma front", (0,0.92,0.78), (0.43,0.42,0.37), body)
ellipsoid("Head", (0,1.9,0.72), (0.62,0.7,0.42), body)
for y, width, z in [(-2.18,0.69,1.15),(-1.83,0.76,1.20),(-1.47,0.71,1.15)]:
    # A raised transverse seam, not a luminous filled-in body.
    rod("Gaster plate seam",(-width*0.72,y,z),(width*0.72,y,z),0.028,rim)
for sign in [-1,1]:
    rod("Thorax rim",(sign*0.30,0.02,0.94),(sign*0.31,1.02,1.06),0.038,rim)
    ellipsoid("Eye", (sign*0.5,2.02,0.95), (0.105,0.15,0.095), eye)
    rod("Mandible", (sign*0.26,2.42,0.61), (sign*0.13,2.72,0.59), 0.09, joint)


bpy.ops.object.camera_add(location=(0,-3,18))
camera = bpy.context.object
camera.rotation_euler = (Vector((0,0.35,0.5))-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 8.6
scene.camera = camera
for name, at, power, size in [("Soft key",(-4,3,8),850,5),("Rim",(4,-2,5),650,3)]:
    bpy.ops.object.light_add(type="AREA",location=at)
    light = bpy.context.object
    light.name = name
    light.data.energy = power
    light.data.shape = "DISK"
    light.data.size = size
    light.rotation_euler = (-light.location).to_track_quat("-Z","Y").to_euler()

images = []
for frame in range(FRAMES):
    phase = frame*2*math.pi/FRAMES
    for sign in [-1,1]:
        sweep=math.sin(phase+sign*1.2)*0.18
        elbow=(sign*(0.93+sweep),2.82,1.08)
        tip=(sign*(0.91+sweep*1.7),3.65,1.16)
        rod("Animated antenna scape",(sign*0.35,2.31,0.98),elbow,0.055,joint)
        rod("Animated antenna flagellum",elbow,tip,0.045,rim)
        ellipsoid("Animated antenna sensor",tip,(0.06,0.065,0.06),rim)
        for index in range(3):
            y = 0.05 + index*0.43
            stride = math.sin(phase + index*math.pi + (math.pi if sign < 0 else 0))
            lift = max(0,stride)*0.28
            a = (sign*0.26,y,0.67)
            b = (sign*(0.88+index*0.06), y+0.3*(index-1)+stride*0.16, 0.47+lift)
            c = (sign*(1.65+index*0.10), y+0.65*(index-1)+stride*0.52, 0.12+lift)
            rod("Animated femur",a,b,0.085,joint)
            rod("Animated tibia",b,c,0.065,joint)
            rod("Animated tarsus",c,(c[0]+sign*0.16,c[1]+0.25,c[2]-0.03),0.035,joint)
    scene.render.filepath = str(SCRATCH / f"worker_{frame:02d}.png")
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(scene.render.filepath)
    images.append(list(image.pixels[:]))
    bpy.data.images.remove(image)
    for obj in list(bpy.data.objects):
        if obj.name.startswith("Animated"):
            bpy.data.objects.remove(obj,do_unlink=True)

width, height = CELL*COLS, CELL*(FRAMES//COLS)
pixels = [0.0]*(width*height*4)
silhouette = [0.0]*(width*height*4)
for frame,data in enumerate(images):
    # Blender rows are bottom-up; atlas frame 0 is top-left in Godot.
    x, y = (frame%COLS)*CELL, (height//CELL-1-frame//COLS)*CELL
    for row in range(CELL):
        dst = ((y+row)*width+x)*4
        src = row*CELL*4
        pixels[dst:dst+CELL*4] = data[src:src+CELL*4]
        for col in range(CELL):
            a = data[src+col*4+3]
            silhouette[dst+col*4:dst+col*4+4] = [1,1,1,a]
for name,data in [("worker_walk_v3",pixels),("worker_scent_v3",silhouette)]:
    atlas = bpy.data.images.new(name,width=width,height=height,alpha=True)
    atlas.pixels[:] = data
    atlas.filepath_raw = str(OUT / f"{name}.png")
    atlas.file_format = "PNG"
    atlas.save()
print("ANTZENPILE_ATLAS_OK", width,height,FRAMES)
