"""Catalog: mount each weapon as an ARM-CANNON on VORTEX's forearm (the arm IS the gun) and render
front+right per weapon into one contact sheet, for the patron to pick BEFORE we bake all 28 sheets."""
import bpy, os, math, mathutils
from PIL import Image, ImageDraw
src=open("tools/build_vortex_gun_anims.py").read().replace("\nmain()\n","\n")
g={"__name__":"bg"}; exec(compile(src,"bvg","exec"),g)
g["GUN_SCALE_FRAC"]=0.46   # chunkier -> reads as an integrated arm-cannon, not a slim held gun
RES=g["RES"]; FRAMES=g["FRAMES"]
sc=g["setup_scene"](); arm=g["get_armature"]()
sc.cycles.samples=24
mech=[o for o in sc.objects if o.type=="MESH"]
g["pose_idle"](arm,0,FRAMES); bpy.context.view_layer.update()
mmn,mmx=g["bbox"](mech); mech_h=mmx.z-mmn.z; center0=(mmn+mmx)*0.5
size=max((mmx-mmn).x,(mmx-mmn).y,(mmx-mmn).z,1e-3)
cam_d=bpy.data.cameras.new("cam"); cam_d.type="ORTHO"; cam_d.ortho_scale=size*1.25
cam=bpy.data.objects.new("cam",cam_d); sc.collection.objects.link(cam); sc.camera=cam
e=math.radians(g["EL"]); dist=size*4.0
def aim(c,az):
    a=math.radians(az)
    cam.location=(c.x+dist*math.cos(e)*math.sin(a),c.y-dist*math.cos(e)*math.cos(a),c.z+dist*math.sin(e))
    cam.rotation_euler=(c-mathutils.Vector(cam.location)).to_track_quat("-Z","Y").to_euler()
def place_forearm(gun):
    # attach along the FOREARM (elbow->wrist), so the cannon body sheathes the forearm and the barrel
    # extends past where the hand was -> an arm-cannon, not a hand-held gun.
    pb=arm.pose.bones
    bmat=arm.matrix_world @ pb["RightForeArm"].matrix
    loc,rot,_=bmat.decompose()
    off=mathutils.Matrix.Translation((0.0,-0.10*mech_h,0.0))  # pull breech back toward the elbow
    gun.matrix_world=mathutils.Matrix.Translation(loc) @ rot.to_matrix().to_4x4() @ off
WEAPONS=[("plasma_cannon","PLASMA"),("energy_rifle","ENERGY"),("laser_blaster","BLASTER"),("gauss_rifle","GAUSS")]
tmp=os.path.abspath("cine/_show/_cat_tmp.png"); cells=[]
for wid,label in WEAPONS:
    g["GUN_GLB"]=os.path.abspath("meshy_in/w_%s/model.glb"%wid)
    gun=g["import_gun"](sc,mech_h)
    row=[]
    for az in [0,-90]:
        g["pose_attack"](arm,0,FRAMES); bpy.context.view_layer.update()
        place_forearm(gun); bpy.context.view_layer.update()
        mn,mx=g["bbox"](mech); cen=(mn+mx)*0.5; cen.z=center0.z
        aim(cen,az); sc.render.filepath=tmp; bpy.ops.render.render(write_still=True)
        row.append(Image.open(tmp).convert("RGBA").copy())
    cells.append((label,row))
    bpy.data.objects.remove(gun,do_unlink=True)
# assemble: 4 weapons x (front,right)
pad=10; W=RES*2+pad*3; H=RES+34
sheet=Image.new("RGB",(W, H*len(cells)),(24,26,33)); dr=ImageDraw.Draw(sheet)
for i,(label,row) in enumerate(cells):
    y=H*i; dr.text((pad,y+8),"%d) %s"%(i+1,label),fill=(255,220,150))
    for j,im in enumerate(row):
        bg=Image.new("RGB",(RES,RES),(30,33,42)); bg.paste(im,(0,0),im)
        sheet.paste(bg,(pad+(RES+pad)*j, y+26))
sheet.save(os.path.abspath("cine/_show/armcannon_catalog.png")); print("CATALOG done")
