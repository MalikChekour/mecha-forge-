#!/usr/bin/env python3
"""Cuit les planches 2D des versions MK II/III/IV de VORTEX et BLUESTRIKE (16/10) sur le RIG ET LES ANIMATIONS DEJA EN PLACE
(poses de build_vortex_gun_anims.py), avec les pieces de mk_parts.py suivies sur les os. Sortie : game/assets/mecha/<base>mk<N>_<anim>_<dir>.png
Usage : python tools/build_mk_anims.py --base vortex|bluestrike --mk 2|3|4 [--test] [--diag] [--anims walk,idle]
  --test : une seule image d'attaque (face/cote) dans cine/_show/ pour juger les pieces avant le bake complet."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import build_vortex_gun_anims as bg
import mk_parts

def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default

BASE = arg("--base", "vortex")
MK = int(arg("--mk", "2"))
bg.GLB_IN = os.path.abspath({"vortex": "meshy_in/vortex/rigged.glb", "bluestrike": "meshy_in/nice_mech/rigged.glb"}[BASE])
bg.CHASSIS = "%smk%d" % (BASE, MK)
_parts = {}

def _import(sc, mech_h):
    arm = bg.get_armature()
    _parts["p"] = mk_parts.build(arm, BASE, MK)
    return _parts["p"]

def _place(arm, gun, mech_h):
    _parts["p"].update()

# 16/10 (patron : « son bras est contracte et non tendu quand il vise ») : bras de tir TENDU vers la cible
# (epaule a l'horizontale, coude droit) au lieu du bras plie des poses d'origine ; le bras gauche accompagne.
R = bg.R
def aim_arm(pb):
    if "RightArm" in pb: pb["RightArm"].rotation_euler = (R(-86), R(-2), R(2))
    if "RightForeArm" in pb: pb["RightForeArm"].rotation_euler = (0, 0, 0)
    if "Spine" in pb: pb["Spine"].rotation_euler.x = R(-6)
bg.aim_arm = aim_arm
_orig_attack = bg.pose_attack
def pose_attack(arm, f, n):
    _orig_attack(arm, f, n)
    pb = arm.pose.bones
    if "RightArm" in pb: pb["RightArm"].rotation_euler = (R(-86) + R(8) * max(0.0, __import__("math").sin(2 * __import__("math").pi * f / n)), R(-2), R(2))
    if "RightForeArm" in pb: pb["RightForeArm"].rotation_euler = (0, 0, 0)
    if "LeftArm" in pb: pb["LeftArm"].rotation_euler = (R(-38), R(18), R(-10))
bg.pose_attack = pose_attack
bg.POSERS["attack"] = pose_attack
bg.import_gun = _import
bg.place_gun = _place
bg.main()
