"""Generate the intro cinematic panels via cine_gen (FLUX free fallback), matching the hero look."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from cine_gen import generate

OUT = r"C:\Users\Administrator\mecha-forge\cine"
STYLE = ("teal and orange cinematic color grade, painterly stylized-realistic game art, "
         "dark sci-fi mecha survivor, dramatic lighting, ultra detailed, no text")

PANELS = {
    "p1": f"Cinematic wide shot. An endless army of hostile war machines and robots marching "
          f"across a devastated wasteland toward the horizon, smoke-choked orange sky, distant "
          f"explosions, silhouetted enemy mechs stretching to the horizon, ominous epic scale, {STYLE}",
    "p2": f"Cinematic shot, interior of a ruined mecha forge, abandoned and silent, a single "
          f"dormant humanoid mech chassis slumped under dust, debris and hanging broken cables, "
          f"faint cold light through a collapsed ceiling, dead furnace embers, melancholic, {STYLE}",
    "p3": f"Cinematic shot, a lone human pilot in a worn flight suit standing small before a "
          f"towering dormant humanoid mech in a ruined forge, reaching a hand toward the dark "
          f"cockpit, dramatic backlight, dust motes in shafts of light, hopeful determined, {STYLE}",
    "p4": f"Cinematic close shot, a humanoid mech's chest reactor core reigniting with intense "
          f"cyan energy, light flooding outward through the seams of its armor, orange sparks and "
          f"embers erupting, power surging through glowing conduits, dramatic bloom, {STYLE}",
    "p6": f"Cinematic low-angle shot, a battle-worn humanoid mech charging forward into battle, "
          f"cyan core and thrusters blazing, orange muzzle flashes, a massive horde of enemy "
          f"machines ahead in silhouette, motion and energy, dust and embers, epic heroic, {STYLE}",
}

for name, prompt in PANELS.items():
    print(f"--- {name} ---")
    generate(prompt, os.path.join(OUT, f"{name}.png"), "16:9")
