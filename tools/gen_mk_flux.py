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
            "with two antennas, a long energy blade held at the side, slim athletic proportions. ", 4242,
  {"mk2": "MARK II upgrade: extra layered armor plates on shoulders and forearms, sharper helmet crest, brighter cyan circuitry, reinforced knees, longer energy blade with cyan edge glow.",
   "mk3": "MARK III upgrade: heavier armored silhouette, small back thrusters with cyan flame, shoulder energy-shield emitters, intricate neon circuitry, orange core inside a reinforced chest frame, blade with plasma aura.",
   "mk4": "MARK IV ultimate flagship version: black armor with polished chrome and gold trim, floating detached shoulder plates with cyan halo rings, wing-like fins on the back, intense orange-white core, a double-edged radiant energy blade."}),
 "bluestrike": ("BLUESTRIKE scout: grey gunmetal and bright orange armor, huge round shoulder pods, cyan and magenta glowing head visor, "
                "light and fast agile build, orange fists and knees. ", 777,
  {"mk2": "MARK II upgrade: extra orange armor plating, shoulder pods with vent slits, sharper head crest, brighter cyan magenta visor, reinforced fists and knees, panel lines.",
   "mk3": "MARK III upgrade: assault configuration, shoulder pods turned into twin blaster cannons, small back thrusters with orange flame, armor skirt, glowing energy conduits on arms and legs.",
   "mk4": "MARK IV ultimate prototype: orange and gunmetal armor with white and gold trim, floating weapon drones behind the shoulders, glowing visor halo, translucent cyan light wings, intense core glow."})}
if __name__ == "__main__":
    only = sys.argv[1:]
    for name, (ident, seed, mks) in SPEC.items():
        for mk, desc in mks.items():
            tag = "%s_%s" % (name, mk)
            dst = os.path.join(OUT, tag + "_flux.png")
            if (only and tag not in only) or os.path.exists(dst):
                continue
            ok = flux(BASE + ident + desc, dst, steps=8)
            print(tag, "OK" if ok else "ECHEC")
