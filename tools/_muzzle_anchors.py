import bpy, math, mathutils, os
from bpy_extras.object_utils import world_to_camera_view
def R(d): return math.radians(d)
RES=256; EL=40.0
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath("meshy_in/vortex/rigged.glb"))
sc=bpy.context.scene; arm=[o for o in sc.objects if o.type=="ARMATURE"][0]; pb=arm.pose.bones
for b in pb: b.rotation_mode="XYZ"
def bbox(objs):
    dg=bpy.context.evaluated_depsgraph_get(); mn=mathutils.Vector((1e9,)*3); mx=-mn
    for o in objs:
        oe=o.evaluated_get(dg)
        for c in oe.bound_box:
            w=oe.matrix_world@mathutils.Vector(c)
            for i in range(3): mn[i]=min(mn[i],w[i]); mx[i]=max(mx[i],w[i])
    return mn,mx
# attack pose (frame ~2, arm forward)
def pose_attack():
    for b in pb: b.rotation_euler=(0,0,0); b.location=(0,0,0)
    d={"Spine":(R(-6),0,0),"RightArm":(R(-70),R(-6),R(4)),"RightForeArm":(R(-16),0,0),
       "LeftArm":(R(-30),R(14),R(-10)),"LeftForeArm":(R(-52),0,0)}
    for n,r in d.items():
        if n in pb: pb[n].rotation_euler=r
pose_attack(); bpy.context.view_layer.update()
mech=[o for o in sc.objects if o.type=="MESH"]
mmn,mmx=bbox(mech); mech_h=mmx.z-mmn.z; center0z=(mmn.z+mmx.z)*0.5
# import + prep cannon (join, bake barrel->+Y, breech origin, scale) -- reuse logic
before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=os.path.abspath("meshy_in/w_plasma_cannon/model.glb"))
g=[o for o in bpy.data.objects if o not in before and o.type=="MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in g: o.select_set(True)
bpy.context.view_layer.objects.active=g[0]
if len(g)>1: bpy.ops.object.join()
gun=bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
M=gun.matrix_world.copy()
for v in gun.data.vertices: v.co=M@v.co
gun.matrix_world=mathutils.Matrix.Identity(4)
def mb():
    vs=[v.co for v in gun.data.vertices]
    return (mathutils.Vector((min(v.x for v in vs),min(v.y for v in vs),min(v.z for v in vs))),
            mathutils.Vector((max(v.x for v in vs),max(v.y for v in vs),max(v.z for v in vs))),vs)
mn,mx,_=mb(); dim=mx-mn; ax=max(range(3),key=lambda i:dim[i])
if ax==0: gun.data.transform(mathutils.Matrix.Rotation(R(90),4,"Z"))
elif ax==2: gun.data.transform(mathutils.Matrix.Rotation(R(-90),4,"X"))
mn,mx,_=mb(); dim=mx-mn; gun.data.transform(mathutils.Matrix.Scale((0.34*mech_h)/max(dim.y,1e-3),4))
mn,mx,vs=mb(); midy=(mn.y+mx.y)/2
def thick(pos):
    s=[v for v in vs if (v.y>midy)==pos]
    return 0 if not s else (max(v.x for v in s)-min(v.x for v in s))+(max(v.z for v in s)-min(v.z for v in s))
if thick(True)>thick(False): gun.data.transform(mathutils.Matrix.Rotation(R(180),4,"Z"))
mn,mx,_=mb(); gun.data.transform(mathutils.Matrix.Translation((-(mn.x+mx.x)/2,-mn.y,-(mn.z+mx.z)/2)))
mn,mx,_=mb(); MUZZLE_Y=mx.y   # tip is at +Y max
def place():
    bmat=arm.matrix_world@pb["RightHand"].matrix
    loc,rot,_=bmat.decompose()
    gun.matrix_world=mathutils.Matrix.Translation(loc)@rot.to_matrix().to_4x4()@mathutils.Matrix.Translation((0,0.02,0))
# camera + project per facing
cam_d=bpy.data.cameras.new("c"); cam_d.type="ORTHO"
size=max((mmx-mmn).x,(mmx-mmn).y,(mmx-mmn).z); cam_d.ortho_scale=size*1.22
cam=bpy.data.objects.new("c",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=R(EL); dist=size*4
def aim(cen,az):
    a=R(az); cam.location=(cen.x+dist*math.cos(e)*math.sin(a),cen.y-dist*math.cos(e)*math.cos(a),cen.z+dist*math.sin(e))
    cam.rotation_euler=(cen-mathutils.Vector(cam.location)).to_track_quat("-Z","Y").to_euler()
print('const _GUN_ANCHORS vortex:')
for name,az in [("front",0),("back",180),("left",90),("right",-90)]:
    pose_attack(); bpy.context.view_layer.update(); place(); bpy.context.view_layer.update()
    mn2,mx2=bbox(mech); cen=(mn2+mx2)*0.5; cen.z=center0z
    aim(cen,az); bpy.context.view_layer.update()
    tip=gun.matrix_world@mathutils.Vector((0,MUZZLE_Y,0))
    co=world_to_camera_view(sc,cam,tip); px=co.x*RES; py=(1-co.y)*RES
    ax_=(px-RES/2)*(190.0/RES); ay=(py-RES/2)*(190.0/RES)
    print('  "%s": Vector2(%.1f, %.1f),'%(name,ax_,ay))
