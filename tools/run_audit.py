"""Send the full MECHA-FORGE bundle to 3 external LLMs in parallel and save each verdict.

Providers: GLM-5.2 (z.ai Coding Plan), Gemini 2.5 Flash (Google), Nemotron 3 Ultra 550B
(OpenRouter free tier). Each gets the SAME prompt + the SAME source bundle, so their
disagreements are meaningful rather than an artifact of different inputs.

Keys are read from env/files with utf-8-sig (a BOM in a key file yields a misleading 401)
and are never printed.
"""
import os, json, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

SCRATCH = (r"C:\Users\ADMINI~1\AppData\Local\Temp\2\claude"
           r"\C--Users-Administrator\5ead40ad-f19f-4901-a883-ccc2b3edf7a6\scratchpad")
BUNDLE = os.path.join(SCRATCH, "audit_bundle.md")

PROMPT = """Tu es un consultant senior en game design et production de jeux mobiles free-to-play.
Realise un audit CRITIQUE et SANS COMPLAISANCE du projet dont le CODE SOURCE COMPLET et les
documents de conception sont fournis ci-dessous. Je prefere une verite qui fait mal a un
encouragement poli : cherche les raisons pour lesquelles ce jeu echouerait.

## GENRE ET POSITIONNEMENT
Survivor-like / bullet-heaven mobile (sous-genre de Vampire Survivors, porte sur mobile F2P
par SURVIVOR.IO et Archero). Tir automatique, esquive de vagues, montee de niveau en partie
avec draft de 3 ameliorations, run de 15 minutes, progression permanente entre les parties.
Cible : Android, portrait, sessions 5-15 min, F2P avec pubs recompensees.
Theme mecha/robots (differenciation revendiquee face au theme zombies de Survivor.io).

**REFERENCE ASSUMEE : SURVIVOR.IO.** La structure de run copie volontairement son chapitre 1
(boss a 5:00, boss a 10:00, boss final a 15:00, elites a 3:00 et 12:00). Compare-nous a lui
systematiquement.

## FAIBLESSES DEJA CONNUES (ne t'y limite pas)
- Aucun achat integre (IAP), aucun battle pass, aucune boutique payante
- Les pubs sont SIMULEES : aucune regie n'est branchee (la plomberie jeu est faite)
- Pas de systeme d'energie/vies, pas de chapitres, un seul "monde"
- Aucun social : pas de guilde, pas de classement en ligne, pas de coop
- Pas de tutoriel/FTUE reel
- Retention D1/D7 jamais mesuree, aucun joueur reel n'a teste
- Bloom 2D impossible en web (renderer gl_compatibility)
- Un seul developpeur assiste par IA, zero budget marketing

## CE QUE J'ATTENDS
Appuie chaque affirmation sur le CODE fourni (cite les constantes, les valeurs, les fichiers).
Hierarchise par impact. Reponds a :

1. ECART AVEC SURVIVOR.IO : qu'est-ce qui manque STRUCTURELLEMENT pour retenir un de ses
   joueurs ? Distingue l'indispensable du confort.
2. LA BOUCLE DE RETENTION TIENT-ELLE ? Quotidiennes + equipement + talents + mode sans fin :
   suffisant pour un J7 ? Ou sont les trous ?
3. L'ECONOMIE EST-ELLE SAINE ? 3 monnaies (ferraille/cristaux/noyaux) sans IAP, est-ce trop ?
   Verifie les taux REELS dans SaveManager.gd et GameState.gd : invocation a 30 cristaux,
   gain de 4 + score/2200 par partie, raretes x1 a x3.5, niveaux +15%. Le rythme est-il
   tenable ou frustrant ? Y a-t-il des exploits ou des impasses de progression ?
4. MONETISATION : dans quel ordre brancher les choses ? Quelle valeur realiste sans budget
   d'acquisition ?
5. LE THEME MECHA est-il un atout ou un handicap sur ce marche ?
6. SI TU NE GARDAIS QUE 3 CHANTIERS pour 30 jours, lesquels et pourquoi ?
7. CE JEU A-T-IL UNE CHANCE COMMERCIALE, OUI OU NON ? Reponds franchement. Si non, dis ce
   qu'il faudrait changer pour que la reponse devienne oui.

Termine par une note sur 10 avec justification.

## PROJET COMPLET
"""

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
               "max_tokens": 16000, "temperature": 0.3},
              {"Authorization": f"Bearer {key}"})
    return d["choices"][0]["message"].get("content") or "(contenu vide)"

def ask_gemini(text):
    key = os.environ["GOOGLE_API_KEY"]
    d = _post(f"https://generativelanguage.googleapis.com/v1beta/models/"
              f"gemini-2.5-flash:generateContent?key={key}",
              {"contents": [{"parts": [{"text": text}]}],
               "generationConfig": {"temperature": 0.3, "maxOutputTokens": 16000}}, {})
    return "".join(p.get("text", "") for p in d["candidates"][0]["content"]["parts"])

def ask_nemotron(text):
    key = os.environ["OPENROUTER_API_KEY"]
    d = _post("https://openrouter.ai/api/v1/chat/completions",
              {"model": "nvidia/nemotron-3-ultra-550b-a55b:free",
               "messages": [{"role": "user", "content": text}],
               "max_tokens": 16000, "temperature": 0.3},
              {"Authorization": f"Bearer {key}"})
    return d["choices"][0]["message"].get("content") or "(contenu vide)"

PROVIDERS = [("glm-5.2", ask_glm), ("gemini-2.5-flash", ask_gemini),
             ("nemotron-3-ultra-550b", ask_nemotron)]

def run(item, text):
    name, fn = item
    t0 = time.time()
    try:
        out = fn(text)
        path = os.path.join(SCRATCH, f"audit_{name}.md")
        with open(path, "w", encoding="utf-8") as f:
            f.write(out)
        print(f"OK      {name:<24} {len(out):>7,} car. en {time.time()-t0:>5.0f}s -> {path}",
              flush=True)
    except urllib.error.HTTPError as e:
        print(f"ECHEC   {name:<24} HTTP {e.code} {e.read().decode()[:160]}", flush=True)
    except Exception as e:
        print(f"ECHEC   {name:<24} {type(e).__name__}: {str(e)[:160]}", flush=True)

if __name__ == "__main__":
    with open(BUNDLE, encoding="utf-8") as f:
        bundle = f.read()
    full = PROMPT + bundle
    print(f"prompt total : {len(full):,} caracteres (~{len(full)//4//1000}k tokens)")
    print(f"envoi a {len(PROVIDERS)} modeles en parallele...\n", flush=True)
    with ThreadPoolExecutor(max_workers=3) as ex:
        list(ex.map(lambda p: run(p, full), PROVIDERS))
    print("\ntermine.")
