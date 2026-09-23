import concurrent.futures as cf, sys
sys.path.insert(0, r"C:\Users\Administrator\mecha-forge\tools")
from replicate_gen import generate
BASE=("standing in a clean symmetric T-pose, both arms extended straight out horizontal to the sides, "
"legs straight and slightly apart, strict front view, COMPACT SOLID armor tight to the body, "
"smooth continuous armor plating, simple closed fists, clean flat feet, exactly two arms two legs one head, "
"absolutely NO cables NO wires NO tubes NO hoses NO hanging parts NO loose blades NO weapons NO cape NO cloth "
"NO spikes NO antennas, nothing protruding beyond the silhouette, "
"full body head to feet visible, centered, plain flat light grey background, even soft studio lighting, "
"octane render, hard-surface mechanical, ultra detailed, game asset, premium sci-fi mech robot")
JOBS={
 "cm_juggernaut":"heavy juggernaut battle mech, very bulky thick layered armor, broad massive shoulders, short sturdy legs, gunmetal grey with dark plates, intimidating tank-like, "+BASE,
 "cm_striker":"lean agile striker mech, sleek aerodynamic smooth armor, slim athletic frame, glowing cyan optic, light and fast look, silver and blue plating, "+BASE,
 "cm_bruiser":"aggressive bruiser mech, medium muscular armored build, angular sharp armor panels, glowing red visor, crimson and gunmetal, "+BASE,
 "cm_sentinel":"armored sentinel mech, rounded heavy shielded plating, solid blocky torso, defensive stance, steel blue and white, "+BASE,
}
def go(kv):
    k,p=kv; return k, generate(p, f"cine/pixel/{k}.png", "1:1")
with cf.ThreadPoolExecutor(max_workers=4) as ex:
    for k,ok in ex.map(go, JOBS.items()): print(k, ok)
print("done clean mechs")
