import bpy, sys, mathutils
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=sys.argv[-1])
ms=[o for o in bpy.context.scene.objects if o.type=='MESH']
bpy.context.view_layer.objects.active=ms[0]
for o in ms: o.select_set(True)
if len(ms)>1: bpy.ops.object.join()
m=bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
vs=[m.matrix_world@v.co for v in m.data.vertices]
xs=[v.x for v in vs]; zs=[v.z for v in vs]
mnx,mxx=min(xs),max(xs); mnz,mxz=min(zs),max(zs)
H=mxz-mnz; W=mxx-mnx; cx=(mnx+mxx)/2
print("VERTS",len(vs),"H=%.3f W=%.3f cx=%.3f zrange[%.3f,%.3f]"%(H,W,cx,mnz,mxz))
def slab(zlo,zhi,label):
    sel=[v for v in vs if mnz+zlo*H<=v.z<=mnz+zhi*H]
    if not sel: print(label,"empty"); return
    l=[v.x for v in sel if v.x<cx]; r=[v.x for v in sel if v.x>=cx]
    lc=sum(l)/len(l) if l else cx; rc=sum(r)/len(r) if r else cx
    print("%s z[%.2f-%.2f] n=%d  Lx=%+.2fW Rx=%+.2fW  span[%+.2f,%+.2f]W"%(
        label,zlo,zhi,len(sel),(lc-cx)/W,(rc-cx)/W,(min(v.x for v in sel)-cx)/W,(max(v.x for v in sel)-cx)/W))
for a,b,n in [(0,.10,"FEET "),(.10,.30,"SHIN "),(.30,.50,"THIGH"),(.45,.60,"HIP  "),
              (.60,.80,"CHEST"),(.75,.90,"SHLDR"),(.85,1.0,"HEAD ")]:
    slab(a,b,n)
