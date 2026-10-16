"""Concepts MK2/MK3/MK4 de VORTEX et BLUESTRIKE (16/10) - FLUX schnell (Cloudflare) : fal.ai est a court de credit et Pollinations ignorait le prompt.
Text-to-image : l'identite visuelle est DECRITE (pas copiee du sprite) -> planches de concept a valider/annuler.
Aucun effet sur le jeu."""
import os, sys, time
sys.path.insert(0, r"C:\Users\Administrator\workspace\pod")
from flux_gen import flux   # Cloudflare FLUX schnell (CF_ACCOUNT_ID / CF_API_TOKEN)
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "refs", "mk_concepts")
os.makedirs(OUT, exist_ok=True)
BASE = ("full body front view of a heavy sci-fi battle mecha standing in a neutral pose, centered, isolated on a plain flat dark slate "
        "background, no text, no logo, game concept art, ultra detailed hard-surface design, 3D render, studio lighting. ")
SPEC = {
 "vortex": ("VORTEX prototype: sleek matte black armor, glowing cyan neon lines, orange glowing chest core, narrow angular helmet "
            "with two antennas, slim athletic proportions. NO sword, NO blade, NO handheld weapon: every weapon is built into the arms and hands. ", 4242,
  {"mk2": "MARK II upgrade: extra armor plates, brighter cyan circuitry, a large energy cannon integrated into the right forearm, a glowing palm emitter built into the left hand.",
   "mk3": "MARK III upgrade: heavier armor, back thrusters with cyan flame, shoulder shield emitters, twin energy cannons integrated into both forearms, palm emitters in both hands.",
   "mk4": "MARK IV ultimate flagship: black armor with chrome and gold trim, floating shoulder plates with cyan halo rings, a big rotating beam cannon integrated into the right arm, a glowing palm cannon in the left hand."}),
 "bluestrike": ("BLUESTRIKE scout: grey gunmetal and bright orange armor, huge round shoulder pods, cyan and magenta glowing head visor, "
                "light and fast agile build. NO sword, NO handheld weapon: every weapon is built into the arms and hands. ", 777,
  {"mk2": "MARK II upgrade: extra orange armor plating, vented shoulder pods, short-range scatter blasters integrated into both forearms, fists with built-in blast emitters.",
   "mk3": "MARK III upgrade: assault configuration, twin shotgun-style cannons integrated into the forearms, back thrusters with orange flame, glowing energy conduits, palm emitters.",
   "mk4": "MARK IV ultimate prototype: orange and gunmetal armor with white and gold trim, a rotary gatling cannon integrated into the right arm, a palm blast cannon in the left hand, translucent cyan light wings, glowing visor halo."})}
if __name__ == "__main__":
    only = sys.argv[1:]
    for name, (ident, seed, mks) in SPEC.items():
        for mk, desc in mks.items():
            tag = "%s_%s" % (name, mk)
            dst = os.path.join(OUT, tag + "_flux.png")
            if (only and tag not in only) or os.path.exists(dst):
                continue
            ok = flux(BASE + ident + desc + " Weapons built into the arm and the hand, no sword.", dst, steps=8)
            print(tag, "OK" if ok else "ECHEC")
