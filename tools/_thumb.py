import bpy, sys, os, math, mathutils
from PIL import Image
GLB=os.path.abspath(sys.argv[1]); OUT=os.path.abspath(sys.argv[2]); RES=int(sys.argv[3]) if len(sys.argv)>3 else 300
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)
ms=[o for o in bpy.context.scene.objects if o.type=='MESH']
mn=mathutils.Vector((1e9,)*3); mx=-mn
for o in ms:
    for c in o.bound_box:
        w=o.matrix_world@mathutils.Vector(c)
        for i in range(3): mn[i]=min(mn[i],w[i]); mx[i]=max(mx[i],w[i])
ctr=(mn+mx)*0.5; size=max((mx-mn).x,(mx-mn).y,(mx-mn).z,1e-3)
sc=bpy.context.scene; sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=12
sc.render.resolution_x=RES; sc.render.resolution_y=RES; sc.render.film_transparent=True
sc.render.image_settings.color_mode='RGBA'
w=bpy.data.worlds.new('w'); sc.world=w; w.use_nodes=True
w.node_tree.nodes.get('Background').inputs['Strength'].default_value=0.6
def sun(e,rot):
    d=bpy.data.lights.new('s',type='SUN'); d.energy=e; o=bpy.data.objects.new('s',d); sc.collection.objects.link(o); o.rotation_euler=tuple(math.radians(a) for a in rot)
sun(4.0,(55,10,-30)); sun(1.5,(60,-10,60))
cd=bpy.data.cameras.new('c'); cd.type='ORTHO'; cd.ortho_scale=size*1.25
cam=bpy.data.objects.new('c',cd); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(12); dist=size*4
cam.location=(ctr.x, ctr.y-dist*math.cos(e), ctr.z+dist*math.sin(e))
cam.rotation_euler=(ctr-mathutils.Vector(cam.location)).to_track_quat('-Z','Y').to_euler()
sc.render.filepath=OUT; bpy.ops.render.render(write_still=True)
print('THUMB', OUT, 'H=%.2f W=%.2f D=%.2f'%((mx-mn).z,(mx-mn).x,(mx-mn).y))
