# tools/_test_render_single.py
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import build_vortex_gun_anims as bg
import mk_parts

base = sys.argv[1] if len(sys.argv) > 1 else "bluestrike"
mk = int(sys.argv[2]) if len(sys.argv) > 2 else 2

bg.GLB_IN = os.path.abspath({"vortex": "meshy_in/vortex/rigged.glb", "bluestrike": "meshy_in/nice_mech/rigged.glb"}[base])
bg.CHASSIS = "%smk%d" % (base, mk)
_parts = {}

def _import(sc, mech_h):
    arm = bg.get_armature()
    _parts["p"] = mk_parts.build(arm, base, mk)
    return _parts["p"]

def _place(arm, gun, mech_h):
    _parts["p"].update()

bg.import_gun = _import
bg.place_gun = _place
bg.TEST = True
sys.argv.append("--test")

bg.main()
