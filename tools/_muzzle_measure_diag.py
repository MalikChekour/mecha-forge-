import bpy, os, math, mathutils, importlib.util
from PIL import Image
spec=importlib.util.spec_from_file_location("bg","tools/build_vortex_gun_anims.py")
# load module WITHOUT running main(): read source, strip trailing main() call
src=open("tools/build_vortex_gun_anims.py").read().replace("\nmain()\n","\n")
g={"__name__":"bg"}; exec(compile(src,"bvg","exec"),g)
RES=g["RES"]; FRAMES=g["FRAMES"]
sc=g["setup_scene"](); arm=g["get_armature"]()
sc.cycles.samples=4; sc.cycles.use_denoising=False
mech=[o for o in sc.objects if o.type=="MESH"]
g["pose_idle"](arm,0,FRAMES); bpy.context.view_layer.update()
mmn,mmx=g["bbox"](mech); mech_h=mmx.z-mmn.z
gun=g["import_gun"](sc,mech_h)
center0=(mmn+mmx)*0.5; size=max((mmx-mmn).x,(mmx-mmn).y,(mmx-mmn).z,1e-3)
cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.22
cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(g["EL"]); dist=size*4.0
def aim(c,az):
    a=math.radians(az)
    cam.location=(c.x+dist*math.cos(e)*math.sin(a),c.y-dist*math.cos(e)*math.cos(a),c.z+dist*math.sin(e))
    cam.rotation_euler=(c-mathutils.Vector(cam.location)).to_track_quat("-Z","Y").to_euler()
tmp=os.path.abspath("cine/_show/_gun_only.png")
# extreme-pixel selector per facing (barrel points that way on screen)
DIAG={"front_right":(1,1,-45),"front_left":(-1,1,45),"back_right":(1,-1,-135),"back_left":(-1,-1,135)}
g["pose_attack"](arm,0,FRAMES); bpy.context.view_layer.update()
g["place_gun"](arm,gun,mech_h); bpy.context.view_layer.update()
mn,mx=g["bbox"](mech); cen=(mn+mx)*0.5; cen.z=center0.z
print("VORTEX muzzle anchors DIAGONALES (measured):")
for dname,(dx,dy,az) in DIAG.items():
    aim(cen,az)
    for o in mech: o.hide_render=True
    gun.hide_render=False
    sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
    im=Image.open(tmp).convert("RGBA"); px=im.load(); W,H=im.size
    pts=[(x,y) for y in range(H) for x in range(W) if px[x,y][3]>40]
    best=max(p[0]*dx+p[1]*dy for p in pts)
    cand=[p for p in pts if best-(p[0]*dx+p[1]*dy)<=3]
    tx=sum(p[0] for p in cand)/len(cand); ty=sum(p[1] for p in cand)/len(cand)
    for o in mech: o.hide_render=False
    anx=(tx-RES/2)*(190.0/RES); any_=(ty-RES/2)*(190.0/RES)
    print('  "%s": Vector2(%.1f, %.1f),   # tip px=(%.0f,%.0f)'%(dname,anx,any_,tx,ty))
