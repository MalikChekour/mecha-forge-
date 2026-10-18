# -*- coding: utf-8 -*-
"""Pipeline de génération d'images (Cloudflare FLUX-1 Schnell + rembg)
et d'intégration complète dans Mecha-Forge pour les niveaux 2 à 9.
"""
import os
import sys
import json
import base64
import urllib.request
import urllib.error
from PIL import Image

CF_ACCOUNT_ID = os.environ.get("CF_ACCOUNT_ID")
CF_API_TOKEN = os.environ.get("CF_API_TOKEN")
DECOR_DIR = r"C:\Users\Administrator\mecha-forge\game\assets\decor"
os.makedirs(DECOR_DIR, exist_ok=True)

STYLE_SUFFIX = (
    "Stylized isometric 3/4 top-down view (camera elevation about 40 degrees), "
    "one single game-asset prop centered in the frame, clean hand-painted digital illustration "
    "with bold dark outlines and crisp cel-shaded highlights, hard-surface sci-fi design with rivets, "
    "panel lines and subtle wear, soft rim light, glowing emissive accents, high detail, "
    "matching a robot-war survivor game. Isolated on a solid flat pure white background, "
    "no ground plane, no cast shadow, square 1024x1024."
)

LEVELS_CONFIG = {
    # NIVEAU 2 : ETHER (complétion des 3 derniers items)
    "ether": {
        "ground": None, # Déjà généré
        "props": [
            ("ether_inter_champignon_rebond.png",
             "A giant elastic bouncy alien mushroom cap trap: thick rubbery domed fungal cap in vibrant bioluminescent magenta and cyan stripes, rooted on a coiled pneumatic robotic spring base, glowing impact pads on the bouncy cap surface. " + STYLE_SUFFIX),
            ("ether_terrain_fongus_arbre.png",
             "A monumental bioluminescent alien shelf mushroom tree trunk: thick fibrous fungal stem with layered glowing cyan and purple bracket mushrooms sprouting outward, dripping luminous spore droplets. " + STYLE_SUFFIX),
            ("ether_bordure_mycelium.png",
             "A massive impenetrable organic alien chitin and mycelium wall barrier: reinforced fibrous purple fungal wall with glowing cyan spore pods and pulsing tendrils forming a boundary fence. " + STYLE_SUFFIX),
        ]
    },
    # NIVEAU 3 : TITANS (Nécropole des Titans / Cimetière d'Acier)
    "titans": {
        "ground": ("ground_titans.png",
                   "Seamless tileable top-down game ground texture, giant mecha graveyard battlefield, rusty sepia iron dust, dark weathered rusted steel armor plating shards embedded in dry reddish-brown dirt, giant 2-meter steel bolts and rivets, colossal tread track marks, pristine orthogonal flat top-down perspective, perfectly flat surface with no relief obstacles, high detail, stylized video game environment texture, square 1024x1024"),
        "props": [
            ("titans_tourelle_artillerie.png",
             "A salvaged heavy battleship turret cannon: twin massive 400mm rifled rusted steel gun barrels on a heavily reinforced armored swivel turret bunker, scratched optical rangefinder lens, faded military serial numbers, sepia rust weathering and dark gunmetal iron. " + STYLE_SUFFIX),
            ("titans_emetteur_fuite_huile.png",
             "A ruptured hydraulic pressure conduit emitter from a fallen colossus: cracked giant steel pipe burst open, spewing viscous black tar oil puddle and steaming toxic fumes, pressure gauge dial spinning wildly, warning hazard stripes. " + STYLE_SUFFIX),
            ("titans_butin_coffre_blindage.png",
             "A heavy armored black-box data flight recorder container salvaged from a titan mech: ultra-dense hexagonal steel chest with glowing orange electronic lock seals, heavy lifting eyelets, charred ceramic heat-shield tiles, sepia rust. " + STYLE_SUFFIX),
            ("titans_inter_electroaimant_epave.png",
             "An industrial scrap salvage electromagnet crane hoist: circular copper induction coil magnet disc with high-voltage spark nodes, heavy steel support chains, pulsing electromagnetic field aura in warm orange and amber light. " + STYLE_SUFFIX),
            ("titans_inter_mine_antichar.png",
             "A massive anti-titan landmine: thick circular cast-iron explosive pressure disc with central plunger detonator, red arming LED, yellow hazard chevrons, weathered rust and mud encrustation. " + STYLE_SUFFIX),
            ("titans_terrain_main_colosse.png",
             "A monumental fallen mechanical titan hand obstacle: giant robotic steel fist and articulated fingers partially sunken into the earth, exposed rusted hydraulic cables and ceramic finger joints. " + STYLE_SUFFIX),
            ("titans_bordure_squelette.png",
             "A colossal fallen warship ribcage bulkhead wall section: giant curved rusted steel hull ribs forming an impassable boundary barrier, reinforced structural girders, sepia weathering. " + STYLE_SUFFIX),
        ]
    },
    # NIVEAU 4 : ORBIT (Champ de Débris Orbital / Apesanteur)
    "orbit": {
        "ground": ("ground_orbit.png",
                   "Seamless tileable top-down game ground texture, space station outer hull deck, dark carbon-fiber composite panels, quilted gold thermal mylar insulation foil patches, micrometeorite crater scorches, high-tech magnetic grid lines, pristine orthogonal flat top-down perspective, perfectly flat surface with no relief obstacles, high detail, stylized video game environment texture, square 1024x1024"),
        "props": [
            ("orbit_tourelle_laser_impulsion.png",
             "A zero-gravity orbital point-defense laser turret: sleek gunmetal spherical turret pod with twin high-frequency UV laser pulse barrels, accordion thermal radiator cooling fins, glowing cyan optical sensors and RCS thruster nozzles. " + STYLE_SUFFIX),
            ("orbit_emetteur_propulseur_rcs.png",
             "A malfunctioning orbital station RCS thruster quad emitter: four-way rocket nozzle assembly venting bursts of cold-gas and blue hypergolic propellant plasma fire, telemetry antenna, hazard markings. " + STYLE_SUFFIX),
            ("orbit_butin_capsule_cargo.png",
             "An orbital pressurized cargo drop capsule: rounded hexagonal space freight pod with gold thermal foil blankets, carbon-fiber latches, glowing cyan beacon strobe, docking port ring. " + STYLE_SUFFIX),
            ("orbit_inter_borne_antigravite.png",
             "An orbital zero-gravity inertia dampener beacon: floating circular gyro-stabilizer dais with spinning magnetic reaction wheels, emitting a soft cyan vertical antigravity particle field. " + STYLE_SUFFIX),
            ("orbit_inter_piege_emp.png",
             "An orbital tethered EMP proximity drone mine: floating satellite mine with solar paddle wings and central capacitor discharge sphere pulsing with bright violet electrical arcs. " + STYLE_SUFFIX),
            ("orbit_terrain_panneau_solaire_brise.png",
             "A shattered orbital photovoltaic solar array wing: large segmented blue-glass solar panel structure with twisted titanium struts and floating wire harnesses. " + STYLE_SUFFIX),
            ("orbit_bordure_paroi_station.png",
             "A heavy orbital station exterior bulkhead wall section: white micrometeorite-shielded modular space armor with yellow emergency docking handrails and flashing red strobe warning lights. " + STYLE_SUFFIX),
        ]
    },
    # NIVEAU 5 : QUANTUM (Archives Quantiques / Monolithe de Données)
    "quantum": {
        "ground": ("ground_quantum.png",
                   "Seamless tileable top-down game ground texture, quantum supercomputer sanctuary floor, polished obsidian black mirror tiles inlaid with glowing amber and golden circuit traces, delicate mathematical lattice bus lines, pristine orthogonal flat top-down perspective, perfectly flat surface with no relief obstacles, high detail, stylized video game environment texture, square 1024x1024"),
        "props": [
            ("quantum_tourelle_faisceau_vecteur.png",
             "A sacred geometric quantum laser turret: floating obsidian black monolith spindle with rotating concentric gold ring calipers, firing an ultra-clean razor-sharp golden vector laser beam, zero smoke. " + STYLE_SUFFIX),
            ("quantum_emetteur_grille_code.png",
             "A quantum prism data emitter scanner: hovering crystal pyramid projecting sharp golden laser scanline grids along the ground, floating binary data glyphs in glowing amber. " + STYLE_SUFFIX),
            ("quantum_butin_cube_memoire.png",
             "A quantum memory hypercube container: translucent borosilicate glass tesseract cube housing a glowing golden qubit core inside, precision gold laser-etched circuits on outer facets. " + STYLE_SUFFIX),
            ("quantum_inter_dalle_transfert.png",
             "A quantum data packet teleportation pad: circular obsidian floor platform with golden geometric concentric rings and pulsing amber light column, transferring matter instantaneously. " + STYLE_SUFFIX),
            ("quantum_inter_cube_glitch.png",
             "An unstable quantum flux voxel trap: cubical matrix of glowing amber and gold data blocks fragmenting and glitching in mid-air, emitting destabilizing digital shockwaves. " + STYLE_SUFFIX),
            ("quantum_terrain_monolithe_flottant.png",
             "A towering quantum server monolith pillar: colossal vertical black obsidian pillar floating inches above the ground, etched with radiant gold circuit pathways. " + STYLE_SUFFIX),
            ("quantum_bordure_paroi_matrice.png",
             "An architectural quantum matrix perimeter wall: monumental black obsidian wall panel with geometric golden inlays and amber light conduits sealing the data core. " + STYLE_SUFFIX),
        ]
    },
    # NIVEAU 6 : OZONE (Faille d’Ozone / Tempêtes Ioniques)
    "ozone": {
        "ground": ("ground_ozone.png",
                   "Seamless tileable top-down game ground texture, ozone lightning desert floor, fulgurite-vitrified dark violet and magenta glass silica sand, glowing ultraviolet electric discharge channels branching across the ground, pristine orthogonal flat top-down perspective, perfectly flat surface with no relief obstacles, high detail, stylized video game environment texture, square 1024x1024"),
        "props": [
            ("ozone_tourelle_arc_eclair.png",
             "An atmospheric lightning coil turret: heavy cast-alloy pylon topped with a giant copper toroid ring capacitor crackling with violent ultraviolet electrical arcs, ceramic high-voltage insulators, purple status LEDs. " + STYLE_SUFFIX),
            ("ozone_emetteur_parafoudre.png",
             "An ion storm lightning rod tower emitter: tall needle spire attracting atmospheric static electricity, discharging concentric electrical shockwave rings across the ground. " + STYLE_SUFFIX),
            ("ozone_butin_accumulateur.png",
             "A high-capacity ionic capacitor battery bank: heavy Faraday-shielded steel chest with glowing violet electrolyte glass tubes, ceramic terminal posts, gold-plated contacts. " + STYLE_SUFFIX),
            ("ozone_inter_condensateur_surcharge.png",
             "An ionic overdrive discharge floor pylon: circular copper grounding plate surrounded by glowing purple Leyden jars, stepping into it charges the mech with crackling kinetic electricity. " + STYLE_SUFFIX),
            ("ozone_inter_cristal_piezo.png",
             "A cluster of unstable piezoelectric quartz crystals: jagged translucent violet crystals that detonate in a chaining electric lightning burst when touched. " + STYLE_SUFFIX),
            ("ozone_terrain_fleche_fulgurite.png",
             "A natural fulgurite lightning spire: tall jagged pillar of melted hollow glass and fused violet silica formed by lightning strikes, crackling with residual static electricity. " + STYLE_SUFFIX),
            ("ozone_bordure_mur_ionique.png",
             "A high-voltage ionic barrier fence: reinforced ceramic insulator pylons sustaining a continuous humming ultraviolet electric fence grid. " + STYLE_SUFFIX),
        ]
    },
    # NIVEAU 7 : PRISM (Abîme Prismatique / Géode de Silice)
    "prism": {
        "ground": ("ground_prism.png",
                   "Seamless tileable top-down game ground texture, giant crystal geode cavern floor, translucent white quartz and calcite crystal facets reflecting rainbow light, iridescent mineral dust, crystalline cleavage planes, pristine orthogonal flat top-down perspective, perfectly flat surface with no relief obstacles, high detail, stylized video game environment texture, square 1024x1024"),
        "props": [
            ("prism_tourelle_refracteur.png",
             "An optical crystal prism refractor turret: heavy marble and brass mounting base holding a massive rotating optical diamond prism lens that focuses blinding multi-color laser beams. " + STYLE_SUFFIX),
            ("prism_emetteur_faisceau_laser.png",
             "A crystalline refraction light emitter: natural rock geode outcropping with a pure crystal lens channeling sweeping beams of prismatic rainbow laser light. " + STYLE_SUFFIX),
            ("prism_butin_geode_cristal.png",
             "A hollow crystalline geode loot cache: split geode rock with shimmering iridescent cyan and amethyst crystals lining the interior, glowing with valuable salvage loot. " + STYLE_SUFFIX),
            ("prism_inter_miroir_deflexion.png",
             "A crystal optical deflection mirror: mobile brass pedestal holding an angled flawless diamond mirror plate that refracts and bends incoming projectile trajectories. " + STYLE_SUFFIX),
            ("prism_inter_stalagmite_fragile.png",
             "A cluster of razor-sharp brittle glass stalagmites: slender crystalline spires that shatter violently into a spray of damaging glass shards upon impact. " + STYLE_SUFFIX),
            ("prism_terrain_grappe_cristaux.png",
             "A colossal cluster of prismatic quartz crystal pillars: 5-meter tall hexagonal quartz columns towering together with sharp facets and prismatic color dispersion. " + STYLE_SUFFIX),
            ("prism_bordure_paroi_silice.png",
             "A solid crystalline geode perimeter wall: dark basalt rock encrusted with a thick wall of sparkling white and rainbow crystal facets forming an impassable arena border. " + STYLE_SUFFIX),
        ]
    },
    # NIVEAU 8 : STEAMPUNK (Bastion Rétro-Futuriste / Vapeur & Laiton)
    "steampunk": {
        "ground": ("ground_steampunk.png",
                   "Seamless tileable top-down game ground texture, neo-Victorian industrial foundry floor, heavy riveted cast-iron plates and polished brass inlay seams, circular steam grates puffing white vapor, embedded clockwork cogs, pristine orthogonal flat top-down perspective, perfectly flat surface with no relief obstacles, high detail, stylized video game environment texture, square 1024x1024"),
        "props": [
            ("steampunk_tourelle_gatling_vapeur.png",
             "A steam-powered multi-barrel Gatling turret: heavy brass and cast-iron tripod turret with six rotating bronze barrels, pressure boilers with brass steam pipes, analog dial gauges and coal-stoked firebox. " + STYLE_SUFFIX),
            ("steampunk_emetteur_purge_vapeur.png",
             "An industrial high-pressure steam blowout valve: tall copper cylinder with counterweighted brass relief lever, violently erupting geysers of scalding white steam and water condensation. " + STYLE_SUFFIX),
            ("steampunk_butin_coffre_fort_laiton.png",
             "A Victorian heavy iron and brass safe: ornate bank vault chest with brass spoke combination dial, heavy exposed hinges, copper rivet trim, decorative filigree. " + STYLE_SUFFIX),
            ("steampunk_inter_vanne_surchauffe.png",
             "A steam pressure regulation console: heavy iron stand with a red wheel valve and three brass pressure gauges, turning it releases a protective smokescreen cloud. " + STYLE_SUFFIX),
            ("steampunk_inter_chaudiere_instable.png",
             "A bulging rivet-sealed steam boiler trap: glowing hot copper tank hissing with excessive pressure, ready to explode in a burst of shrapnel and hot steam when triggered. " + STYLE_SUFFIX),
            ("steampunk_terrain_engrenage_monumental.png",
             "A monumental clockwork cogwheel obstacle: colossal 5-meter toothed brass and iron gear partially embedded in the foundry floor, heavy grease and steel teeth. " + STYLE_SUFFIX),
            ("steampunk_bordure_mur_briques_fonte.png",
             "A heavy industrial foundry perimeter wall: dark weathered red brick masonry reinforced with heavy riveted cast-iron buttress beams and overhead steam pipes. " + STYLE_SUFFIX),
        ]
    },
    # NIVEAU 9 : COLOSSEUM (Colisée Virtuel / Arène de Test)
    "colosseum": {
        "ground": ("ground_colosseum.png",
                   "Seamless tileable top-down game ground texture, military combat testing arena floor, dark carbon-composite ballistic tiles, glowing white and cyan modular laser grid lines, target calibration marks, pristine orthogonal flat top-down perspective, perfectly flat surface with no relief obstacles, high detail, stylized video game environment texture, square 1024x1024"),
        "props": [
            ("colosseum_tourelle_simulation.png",
             "A modular combat simulation sentry turret: sleek matte-grey composite angular turret casing with twin rapid-fire kinetic training cannons, cyan digital targeting reticle projector, LED ammo counter. " + STYLE_SUFFIX),
            ("colosseum_emetteur_barre_exercice.png",
             "A tactical reflex training sweep emitter: motorized central pylon sweeping a low-altitude glowing cyan laser tripwire beam across the ground in a 360-degree rotation. " + STYLE_SUFFIX),
            ("colosseum_butin_module_test.png",
             "A military munitions ordnance evaluation crate: olive-drab and white heavy polymer weapons case with stenciled tactical markings, yellow tamper-proof seals, glowing green latches. " + STYLE_SUFFIX),
            ("colosseum_inter_pod_overdrive.png",
             "An overdrive test recharge station: circular floor dais with three vertical glowing cyan charging pylons, standing inside charges maximum Overdrive super-meter instantly. " + STYLE_SUFFIX),
            ("colosseum_inter_mine_exercice.png",
             "A kinetic concussion exercise mine: flat triangular training mine with flashing amber hazard LED, detonates with a non-lethal high-force kinetic blast wave. " + STYLE_SUFFIX),
            ("colosseum_terrain_pilier_holomur.png",
             "A tactical holographic projection pillar: hexagonal metallic pylon displaying flickering cyan holographic combat telemetry grids and wireframe combat readouts. " + STYLE_SUFFIX),
            ("colosseum_bordure_paroi_blindee.png",
             "A reinforced ballistic arena bunker wall: heavy matte-black armor plates with recessed stadium floodlights and reinforced observation glass viewing slit along the top. " + STYLE_SUFFIX),
        ]
    }
}

def generate_cloudflare(prompt, out_path):
    url = f"https://api.cloudflare.com/client/v4/accounts/{CF_ACCOUNT_ID}/ai/run/@cf/black-forest-labs/flux-1-schnell"
    req = urllib.request.Request(
        url,
        data=json.dumps({"prompt": prompt, "steps": 4}).encode("utf-8"),
        headers={"Authorization": f"Bearer {CF_API_TOKEN}", "Content-Type": "application/json"},
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            d = json.loads(r.read().decode("utf-8"))
            if d.get("success") and "result" in d and "image" in d["result"]:
                with open(out_path, "wb") as f:
                    f.write(base64.b64decode(d["result"]["image"]))
                return True
            else:
                print("  [CF Error]", d.get("errors"))
    except Exception as e:
        print(f"  [CF Network Error]: {e}")
    return False

def process_prop_transparent(raw_jpg, final_png):
    from rembg import remove
    im = Image.open(raw_jpg)
    trans = remove(im)
    bbox = trans.getbbox()
    if bbox:
        w, h = trans.size
        x0, y0, x1, y1 = bbox
        pad = 12
        crop_box = (max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad), min(h, y1 + pad))
        trans = trans.crop(crop_box)
    trans.save(final_png, "PNG")

def process_ground(raw_jpg, final_png):
    im = Image.open(raw_jpg).convert("RGB")
    im.save(final_png, "PNG")

def main():
    print("=== DEBUT GENERATION DES 8 NIVEAUX RESTANTS (FLUX-1 SCHNELL + REMBG) ===")
    raw_dir = r"C:\Users\Administrator\mecha-forge\tools\bible_raw_gen"
    os.makedirs(raw_dir, exist_ok=True)

    for biome, conf in LEVELS_CONFIG.items():
        print(f"\n>>> BIOME: {biome.upper()} <<<")
        # 1. Ground
        if conf["ground"]:
            g_filename, g_prompt = conf["ground"]
            g_final = os.path.join(DECOR_DIR, g_filename)
            g_raw = os.path.join(raw_dir, f"raw_{g_filename}.jpg")
            if not os.path.exists(g_final):
                print(f"  Génération sol {g_filename}...")
                if generate_cloudflare(g_prompt, g_raw):
                    process_ground(g_raw, g_final)
                    print(f"  -> OK sol généré: {g_filename}")
                else:
                    print(f"  -> ECHEC sol: {g_filename}")
            else:
                print(f"  -> Sol déjà présent: {g_filename}")

        # 2. Props
        for p_filename, p_prompt in conf["props"]:
            p_final = os.path.join(DECOR_DIR, p_filename)
            p_raw = os.path.join(raw_dir, f"raw_{p_filename}.jpg")
            if not os.path.exists(p_final):
                print(f"  Génération prop {p_filename}...")
                if generate_cloudflare(p_prompt, p_raw):
                    process_prop_transparent(p_raw, p_final)
                    print(f"  -> OK prop détouré: {p_filename}")
                else:
                    print(f"  -> ECHEC prop: {p_filename}")
            else:
                print(f"  -> Prop déjà présent: {p_filename}")

    print("\n=== TOUTES LES IMAGES ONT ÉTÉ GÉNÉRÉES ET DÉTOURÉES AVEC SUCCÈS ===")

if __name__ == "__main__":
    main()
