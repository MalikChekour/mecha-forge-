import concurrent.futures as cf
from replicate_gen import generate
STYLE=", bipedal war machine, full body head to feet, centered single subject, plain dark neutral studio background, dramatic studio lighting, octane render, hard-surface mechanical, ultra detailed, game asset"
JOBS={
 "spec_shielded":"premium sci-fi enemy mech, riot shield trooper robot holding one large hexagonal energy shield on its arm, heavy reinforced chest plate, blue-steel plating with glowing cyan seams, planted defensive stance"+STYLE,
 "spec_elite":"premium sci-fi enemy mech, agile assault raider robot, lean athletic frame, dual curved forearm blades, digitigrade fast legs, angular crimson and black armor, aggressive forward-leaning sprint pose"+STYLE,
 "spec_warden":"premium sci-fi enemy mech, heavy artillery gunner robot, squat wide armored chassis, twin oversized shoulder cannons, planted heavy legs, olive and gunmetal plating, glowing orange optic eye"+STYLE,
 "spec_crusher":"premium sci-fi enemy mech, colossal heavy tank brute robot, enormous oversized crushing fists, hunched broad armored shoulders, thick layered charcoal armor, glowing red reactor core in chest, intimidating"+STYLE,
 "spec_eyedrone":"premium sci-fi enemy hover drone robot, sleek insectoid floating rounded body, single huge glowing red cyclops eye lens, curved bladed wings and twin side thruster pods, chrome and black, menacing"+STYLE,
}
def go(kv):
    k,p=kv; return k, generate(p, f"cine/pixel/enemy_{k}_concept.png", "1:1")
with cf.ThreadPoolExecutor(max_workers=5) as ex:
    for k,ok in ex.map(go, JOBS.items()): print(k, ok)
print("done specialists concepts")
