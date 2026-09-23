import concurrent.futures as cf, sys
sys.path.insert(0, r"C:\Users\Administrator\mecha-forge\tools")
from replicate_gen import generate
TPOSE=("standing in a PERFECT symmetric T-POSE for 3D rigging: both arms raised straight out sideways at "
"shoulder height, arms FULLY HORIZONTAL parallel to the ground, spread wide like the letter T, a clear WIDE "
"gap between the arms and the torso, open flat hands palms down, legs straight and slightly apart, "
"strict front orthographic view, COMPACT SOLID armor tight to the body, smooth continuous plating, "
"absolutely NO cables NO wires NO tubes NO hanging parts NO loose blades NO weapons NO cape NO cloth NO spikes "
"NO antennas, nothing protruding beyond the arms, full body head to feet visible, centered, "
"plain flat light grey background, even soft studio lighting, octane render, hard-surface mechanical, "
"ultra detailed, game asset, premium sci-fi mech robot, T-pose reference sheet")
JOBS={
 "cm_juggernaut_t":"heavy juggernaut battle mech, very bulky thick layered armor, broad massive shoulders, short sturdy legs, gunmetal grey dark plates, tank-like, "+TPOSE,
 "cm_striker_t":"lean agile striker mech, sleek aerodynamic smooth armor, slim athletic frame, glowing cyan optic, silver and blue plating, "+TPOSE,
 "cm_bruiser_t":"aggressive bruiser mech, medium muscular armored build, angular sharp panels, glowing red visor, crimson and gunmetal, "+TPOSE,
 "cm_sentinel_t":"armored sentinel mech, rounded heavy shielded plating, solid blocky torso, steel blue and white, "+TPOSE,
}
def go(kv):
    k,p=kv; return k, generate(p, f"cine/pixel/{k}.png", "1:1")
with cf.ThreadPoolExecutor(max_workers=4) as ex:
    for k,ok in ex.map(go, JOBS.items()): print(k, ok)
print("done tpose")
