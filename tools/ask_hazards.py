"""Ask 3 external LLMs for arena-hazard design ideas for MECHA-FORGE.

Focused prompt, not the whole 80k bundle: this is a design question, and a previous audit wasted
half its output recommending features that already existed. So the prompt states exactly what is
already implemented and asks them not to re-propose it.
"""
import os, json, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

SCRATCH = (r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude"
           r"\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad")

PROMPT = """Tu es game designer senior sur les survivor-like / bullet-heaven mobile (Survivor.io,
Vampire Survivors, Brotato, Archero). Je veux des idees CONCRETES et IMPLEMENTABLES, pas de la
theorie.

## LE JEU
MECHA-FORGE : survivor-like mecha, Godot 4.5, 2D vue de dessus, Android portrait.
Tir automatique, esquive de vagues, run de 15 min, arene INFINIE en streaming par chunks
(pas de bords, pas de murs). 8 biomes qui defilent quand on tue un boss.

## LE PROBLEME EXACT (rapporte par le proprietaire, et confirme par un audit de code)
> "Le mecha peut indefiniment fuir en arriere sans avoir rien a craindre. Ce n'est pas normal.
>  Le jeu est trop facile et ennuyeux."

Mesure: le joueur monte a 512 px/s avec ses ameliorations, les ennemis non-boss plafonnent a
224 px/s. Le kiting en ligne droite est donc GRATUIT et PERMANENT. J'ai deja fait scaler la
vitesse ennemie (+40% max) mais ca ne traite pas le fond : **l'arene est vide, donc reculer ne
coute jamais rien**. Il n'y a aucune decision spatiale.

Son idee de depart : des canons/tourelles qui tirent des rayons traversants, qui touchent AUSSI
BIEN le mecha que les ennemis — un danger neutre qui appartient au terrain.

## CE QUI EXISTE DEJA (ne le repropose PAS)
- Props destructibles avec HP, qui bloquent les tirs et servent de couverture (les ennemis les
  contournent) : caisses, containers, generateurs, antennes, epaves, immeubles, vaisseaux...
- **Baril de carburant + voiture** : explosent quand on les detruit, degats de zone qui touchent
  ennemis ET joueur (BOOM_DMG 68, rayon defini)
- **Tourelle hostile** (prop "tourelle", flag "shoot") : tire sur le joueur
- **Carcasse de robot** : reveille un gardien endormi quand on s'en approche (rayon 230)
- **Eruptions de lave telegraphes** (anneau rouge qui grandit puis explose) — mais UNIQUEMENT
  sur le biome volcanique
- Modificateurs par biome deja en place : vitesse joueur/ennemis, densite de spawn
  (spaceship = tout plus rapide, marais = tout englue, glace = ennemis ralentis, jungle = +35%
  de spawn, desert = ennemis enrages)
- Caisses dorees qui donnent une amelioration
- Boss a 5:00 / 10:00 / 15:00, elites a 3:00 et 12:00

## CE QUE JE TE DEMANDE
1. **Comment rendre la fuite en arriere COUTEUSE**, sans mettre de murs (l'arene est infinie et
   streamee) et sans simplement accelerer les ennemis ? Donne 3 a 5 mecaniques distinctes.
2. **Developpe l'idee des rayons traversants** : cadence, telegraphie, degats aux deux camps,
   comment le joueur apprend a s'en servir contre les ennemis plutot que de seulement les subir.
3. **Des pieges/obstacles facon Super Mario** adaptes a une vue de dessus et a une arene infinie.
   Pour chacun : le tell visuel, le temps de reaction laisse au joueur, et pourquoi ca reste
   lisible quand 200 ennemis sont a l'ecran.
4. **Comment eviter le piege classique** : un danger de terrain qui devient juste frustrant ou
   injuste dans un jeu ou l'on regarde surtout la horde. Quelles regles d'or ?
5. **Lesquelles de tes idees punissent specifiquement le kiting passif** tout en recompensant le
   joueur agressif ? C'est le coeur du probleme.

Contraintes : 2D vue de dessus, telephone en portrait (peu de place verticale), jusqu'a 220
ennemis simultanes, pas de bords d'arene. Priorite a ce qui est simple a coder et lisible.

Classe tes propositions par (impact sur le probleme) / (cout d'implementation). Sois concret :
valeurs chiffrees, rayons, delais de telegraphie."""


def _key_file(path):
    try:
        with open(path, encoding="utf-8-sig") as f:
            return f.read().strip()
    except OSError:
        return None


def _post(url, payload, headers, timeout=900):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", **headers})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def ask_glm(text):
    key = _key_file(r"C:\Users\Administrator\.zai_key") or os.environ.get("GLM_API_KEY")
    d = _post("https://api.z.ai/api/coding/paas/v4/chat/completions",
              {"model": "glm-5.2", "messages": [{"role": "user", "content": text}],
               "max_tokens": 16000, "temperature": 0.7},
              {"Authorization": f"Bearer {key}"})
    return d["choices"][0]["message"].get("content") or "(vide)"


def ask_gemini(text):
    key = os.environ["GOOGLE_API_KEY"]
    d = _post("https://generativelanguage.googleapis.com/v1beta/models/"
              f"gemini-2.5-flash:generateContent?key={key}",
              {"contents": [{"parts": [{"text": text}]}],
               "generationConfig": {"temperature": 0.7, "maxOutputTokens": 16000}}, {})
    return "".join(p.get("text", "") for p in d["candidates"][0]["content"]["parts"])


def ask_nemotron(text):
    key = os.environ["OPENROUTER_API_KEY"]
    d = _post("https://openrouter.ai/api/v1/chat/completions",
              {"model": "nvidia/nemotron-3-ultra-550b-a55b:free",
               "messages": [{"role": "user", "content": text}],
               "max_tokens": 16000, "temperature": 0.7},
              {"Authorization": f"Bearer {key}"})
    return d["choices"][0]["message"].get("content") or "(vide)"


PROVIDERS = [("glm-5.2", ask_glm), ("gemini-2.5-flash", ask_gemini),
             ("nemotron-3-ultra", ask_nemotron)]


def run(item):
    name, fn = item
    t0 = time.time()
    try:
        out = fn(PROMPT)
        path = os.path.join(SCRATCH, f"hazards_{name}.md")
        with open(path, "w", encoding="utf-8") as f:
            f.write(out)
        print(f"OK      {name:<20} {len(out):>7,} car. en {time.time()-t0:>4.0f}s", flush=True)
    except urllib.error.HTTPError as e:
        print(f"ECHEC   {name:<20} HTTP {e.code} {e.read().decode()[:140]}", flush=True)
    except Exception as e:
        print(f"ECHEC   {name:<20} {type(e).__name__}: {str(e)[:140]}", flush=True)


if __name__ == "__main__":
    print(f"question envoyee a {len(PROVIDERS)} modeles...\n", flush=True)
    with ThreadPoolExecutor(max_workers=3) as ex:
        list(ex.map(run, PROVIDERS))
    print("\ntermine.")
