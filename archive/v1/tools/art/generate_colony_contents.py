"""Original queen and brood meshes, baked to transparent sprites with Blender 5.2.

blender -b --factory-startup --python tools/art/generate_colony_contents.py
No third-party models, AI anatomy, runtime lighting or 3D scene dependencies.
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parents[2] / "assets/graphics/colony"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.world.color = (0.13, 0.13, 0.13)
scene.view_settings.view_transform = "AgX"

def mat(name, color, roughness):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    return result

shell = mat("Glossy chestnut cuticle", (0.11, 0.045, 0.016), 0.23)
legs = mat("Amber joints", (0.27, 0.12, 0.035), 0.35)
eye = mat("Compound eye", (0.003, 0.002, 0.001), 0.18)
pearl = mat("Ivory brood", (0.84, 0.72, 0.48), 0.24)

def oval(at, scale, material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=at)
    obj = bpy.context.object
    obj.scale = scale
    obj.data.materials.append(material)
    for face in obj.data.polygons: face.use_smooth = True
    return obj

def rod(a, b, radius, material):
    a, b = Vector(a), Vector(b)
    obj = oval((a+b)/2, (radius, radius, (b-a).length/2+radius), material)
    obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()

bpy.ops.object.camera_add(location=(0,-3,18))
camera = bpy.context.object
camera.rotation_euler = (Vector((0,0,0.5))-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 8.6
scene.camera = camera
for at, power, size in [((-4,4,8),1000,5),((3,-2,6),850,3)]:
    bpy.ops.object.light_add(type="AREA", location=at)
    lamp = bpy.context.object
    lamp.data.energy, lamp.data.size = power, size
    lamp.rotation_euler = (-lamp.location).to_track_quat("-Z","Y").to_euler()

def save(name):
    scene.render.filepath = str(OUT / (name+".png"))
    bpy.ops.render.render(write_still=True)
    for obj in list(bpy.data.objects):
        if obj.type == "MESH": bpy.data.objects.remove(obj, do_unlink=True)

# Wingless reproductive queen: enlarged gaster/mesosoma, six legs joined to torso.
oval((0,-1.6,0.7),(0.90,1.35,0.65),shell)
oval((0,-0.2,0.68),(0.24,0.24,0.3),shell)
oval((0,0.6,0.78),(0.54,0.78,0.42),shell)
oval((0,1.95,0.74),(0.65,0.64,0.44),shell)
for side in [-1,1]:
    oval((side*0.53,2.03,1.0),(0.10,0.15,0.10),eye)
    rod((side*0.28,2.41,0.7),(side*0.11,2.7,0.67),0.08,legs)
    rod((side*0.34,2.35,1.03),(side*1.02,2.8,1.10),0.06,legs)
    rod((side*1.02,2.8,1.10),(side*0.96,3.65,1.18),0.045,legs)
    for index in range(3):
        y = 0.1+index*0.45
        a, b = (side*0.4,y,0.7),(side*1.08,y+(index-1)*0.3,0.55)
        c = (side*1.85,y+(index-1)*0.65,0.12)
        rod(a,b,0.09,legs); rod(b,c,0.065,legs)
        rod(c,(c[0]+side*0.18,c[1]+0.2,c[2]),0.035,legs)
save("queen")

camera.data.ortho_scale = 3.2
oval((0,0,0.4),(0.60,0.90,0.53),pearl)
save("brood_egg")
# Curved segmented, legless larva, not a miniature adult ant.
for segment in range(9):
    angle = -1.4+segment*0.29
    at = (math.cos(angle)*0.62-0.2, math.sin(angle)*0.62, 0.4)
    radius = 0.22+math.sin(segment/8*math.pi)*0.13
    oval(at,(radius,radius*0.9,radius),pearl)
save("brood_larva")
oval((0,0,0.40),(0.55,1.04,0.47),pearl)
for segment in range(6):
    oval((0,-0.75+segment*0.3,0.45),(0.50,0.16,0.38),pearl)
save("brood_pupa")
print("ANTZENPILE_COLONY_CONTENTS_OK")

